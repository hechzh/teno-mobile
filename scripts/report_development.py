#!/usr/bin/env python3
"""Send only reviewed build summaries/assets to the private Teno development API.

Credentials are read from an environment variable or a protected file, never an
argument. The durable outbox contains no credentials. Re-run with --retry to
resume the exact same report, including its original source timestamp.
"""
import argparse
import hashlib
import http.client
import json
import os
import re
import ssl
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit, urlencode

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_URL = 'https://54-214-180-183.sslip.io'


def words(zh, en): return {'zh': zh, 'en': en}
def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''): h.update(block)
    return h.hexdigest()


def configuration(credential=None):
    config = json.loads(Path(credential).read_text(encoding='utf-8')) if credential else {}
    token = os.environ.get('TENO_DEVELOPMENT_TOKEN') or config.get('token')
    base = os.environ.get('TENO_DEVELOPMENT_URL') or config.get('base_url', DEFAULT_URL)
    url = urlsplit(base)
    if url.scheme != 'https' or url.hostname != '54-214-180-183.sslip.io' or url.port not in (None, 443) or url.username or url.password or url.query:
        raise ValueError('Reporting destination must be the configured Teno HTTPS host')
    if not token or not token.startswith('tenodev_'): raise ValueError('Dedicated reporting credential unavailable')
    return base.rstrip('/'), token


def request(config, method, path, body=None, file=None):
    base, token = config
    parsed = urlsplit(base)
    for attempt in range(3):
        connection = http.client.HTTPSConnection(parsed.hostname, timeout=180, context=ssl.create_default_context())
        try:
            data = json.dumps(body, ensure_ascii=False).encode() if body is not None else b''
            length = Path(file).stat().st_size if file else len(data)
            connection.putrequest(method, path)
            connection.putheader('Authorization', 'Bearer ' + token)
            connection.putheader('Content-Type', 'application/octet-stream' if file else 'application/json')
            connection.putheader('Content-Length', str(length)); connection.endheaders()
            if file:
                with Path(file).open('rb') as f:
                    for block in iter(lambda: f.read(1024 * 1024), b''): connection.send(block)
            elif data: connection.send(data)
            response = connection.getresponse(); result = response.read(1024 * 1024)
            if response.status >= 400:
                if response.status in (429, 502, 503, 504) and attempt < 2:
                    time.sleep(2 ** attempt); continue
                # Do not echo response bodies; they may contain uploaded data.
                raise ValueError('Development API returned HTTP ' + str(response.status))
            return json.loads(result)
        except (OSError, http.client.HTTPException):
            if attempt == 2: raise RuntimeError('Development API connection failed') from None
            time.sleep(2 ** attempt)
        finally: connection.close()


def send(envelope, config, outbox):
    outbox = Path(outbox); outbox.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(envelope, ensure_ascii=False, sort_keys=True)
    receipt = outbox / (hashlib.sha256(encoded.encode()).hexdigest()[:24] + '.json')
    if receipt.exists():
        previous = json.loads(receipt.read_text(encoding='utf-8'))
        if previous.get('status') == 'published': return previous['result']
    state = {'status': 'pending', 'envelope': envelope}
    receipt.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding='utf-8')
    try:
        report = dict(envelope['report']); report['assets'] = list(report.get('assets', []))
        for asset in envelope.get('files', []):
            path = Path(asset['path']); actual = sha(path)
            if actual != asset['sha256']: raise ValueError('Local artifact hash changed')
            if path.stat().st_size > 250 * 1024 * 1024: raise ValueError('Artifact exceeds 250 MiB')
            uploaded = request(config, 'PUT', '/api/v1/development-reporting/assets/' + actual + '?' + urlencode({'kind': asset['kind'], 'filename': asset.get('filename', path.name)}), file=path)
            report['assets'].append({'id': uploaded['id'], 'label': asset['label']})
        result = request(config, 'POST', '/api/v1/development-reporting/results', report)
        state.update(status='published', result=result, completed_at=datetime.now(timezone.utc).isoformat())
        receipt.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding='utf-8')
        return result
    except Exception:
        state['status'] = 'retryable'; state['last_attempt_at'] = datetime.now(timezone.utc).isoformat()
        receipt.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding='utf-8')
        try: request(config, 'POST', '/api/v1/development-reporting/failure', {})
        except Exception: pass
        raise


def ci_envelope(platform, status, outbox):
    run = os.environ['GITHUB_RUN_ID']; attempt = os.environ.get('GITHUB_RUN_ATTEMPT', '1')
    number = f'gh-{run}-{attempt}-{platform}'
    cached = Path(outbox) / (number + '-prepared.json')
    if cached.exists(): return json.loads(cached.read_text(encoding='utf-8'))
    commit = os.environ['GITHUB_SHA']
    version = re.search(r"versionName\s+['\"]([^'\"]+)", (ROOT / 'app/build.gradle').read_text())[1]
    ref = f'https://github.com/hechzh/teno-mobile/actions/runs/{run}'
    states = json.loads(os.environ.get('TENO_DEVELOPMENT_STEPS', '{}'))
    definitions = {'shared': ('Flutter 分析与自动测试', 'Flutter analysis and tests', 'unit'),
                   'android': ('Android 构建与 Lint', 'Android build and lint', 'static'),
                   'simulator': ('iOS 模拟器 XCTest', 'iOS simulator XCTest', 'simulator'),
                   'device': ('iOS 未签名设备编译', 'iOS unsigned device compilation', 'static')}
    tests = []
    for key, value in states.items():
        if key in definitions:
            zh, en, environment = definitions[key]
            tests.append({'name': words(zh, en), 'status': {'success': 'passed', 'failure': 'failed', 'cancelled': 'skipped', 'skipped': 'skipped'}.get(value, 'pending'), 'environment': environment, 'source': ref})
    report = {'platform': platform, 'version': version, 'commit': commit, 'build_number': number,
              'occurred_at': datetime.now(timezone.utc).isoformat(), 'outcome': {'success': 'passed', 'failure': 'failed', 'cancelled': 'cancelled'}.get(status, 'unknown'),
              'implementation': 'unknown', 'physical': 'pending', 'distribution': 'evidence',
              'title': words('GitHub CI 构建结果（不替换内测基线）', 'GitHub CI result (does not replace the baseline)'),
              'tests': tests, 'sources': [{'label': 'GitHub Actions', 'reference': ref}],
              'pending': [words('真实设备与 JWD 联调须单独验收。', 'Physical device and JWD validation requires separate acceptance.')], 'assets': []}
    files = []
    # CI debug APKs are not promoted into the installation area. The run link is
    # retained as build evidence. Only successful, audited unsigned IPA is sent.
    ipa = ROOT / f'ios/build/Teno-{version}-unsigned.ipa'
    if platform == 'ios' and status == 'success' and ipa.exists():
        report['distribution'] = 'unsigned'
        report['installation'] = words('未签名 IPA，需使用自己的 Apple 账号通过 AltStore 等工具重签；不能直接点开安装。实际 iPhone 安装尚待验收。保持原账号与安装标识，覆盖更新，不要先卸载。', 'Unsigned IPA: sign locally with your own Apple account using AltStore or equivalent. It cannot be installed directly. Physical iPhone installation is still pending. Preserve the same account and app identity; update without uninstalling.')
        files.append({'path': str(ipa), 'sha256': sha(ipa), 'kind': 'ipa', 'label': words('iOS 未签名设备构建', 'Unsigned iOS device build')})
    screenshot = ROOT / 'ios/build/screenshots/01-login.png'
    if platform == 'ios' and states.get('simulator') == 'success' and screenshot.exists():
        files.append({'path': str(screenshot), 'sha256': sha(screenshot), 'kind': 'screenshot', 'label': words('iOS 模拟器登录页', 'iOS simulator login screen')})
    result = {'report': report, 'files': files}; cached.parent.mkdir(parents=True, exist_ok=True)
    cached.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    return result


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--credential', type=Path)
    p.add_argument('--report', type=Path)
    p.add_argument('--retry', action='store_true')
    p.add_argument('--ci', choices=['android', 'ios']); p.add_argument('--status', default='unknown')
    p.add_argument('--outbox', type=Path, default=Path.home()/'.teno/development-outbox')
    args = p.parse_args(); config = configuration(args.credential)
    if args.retry:
        pending = [json.loads(f.read_text(encoding='utf-8')) for f in args.outbox.glob('*.json') if not f.name.endswith('-prepared.json')]
        for item in pending:
            if item.get('status') != 'published': send(item['envelope'], config, args.outbox)
        print('Pending development reports retried.'); return
    envelope = ci_envelope(args.ci, args.status, args.outbox) if args.ci else json.loads(args.report.read_text(encoding='utf-8'))
    result = send(envelope, config, args.outbox)
    print('Development result published:', result['id'], '(duplicate)' if result.get('duplicate') else '')


if __name__ == '__main__':
    try: main()
    except Exception as e:
        print('Development reporting failed; the previous server snapshot is preserved. Retry the saved outbox.', file=sys.stderr)
        if isinstance(e, (ValueError, RuntimeError)): print(str(e), file=sys.stderr)
        sys.exit(1)

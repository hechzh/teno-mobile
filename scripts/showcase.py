#!/usr/bin/env python3
"""Publish a full Android UI gallery (showcase) for a reported build.

The development page's "Latest version UI" is backed by
`/api/v1/development-reporting/showcase`, not by the build's individual
screenshot assets. This module makes that step part of the release publisher.

A version-specific gallery is preferred (`design-baseline/v<version>/pages.json`).
When it does not exist yet, the newest available gallery is used and the
acceptance record is marked partial, so the page never silently presents an old
gallery as fully current.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import re
import ssl
import urllib.request
from pathlib import Path
from urllib.parse import urlencode

from report_development import ROOT, configuration, request, sha, words

CORE_PAGES = {
    '01-home', '04-library', '06-search', '14-recording-notes',
    '17-templates', '27-share', '53-template-picker',
}
VARIANTS = {'light', 'dark', 'large'}


def version_tuple(name: str):
    match = re.fullmatch(r'v?(\d+(?:\.\d+)*)', name)
    return tuple(int(part) for part in match.group(1).split('.')) if match else ()


def english_title(page_id: str) -> str:
    name = '-'.join(page_id.split('-')[1:]).strip()
    return name.replace('jwd', 'JWD').replace('mcp', 'MCP').capitalize() or page_id


def module_for(page_id: str) -> str:
    if any(token in page_id for token in (
        'jwd', 'device', 'recording', 'paused', 'audio', 'transcript',
        'speaker', 'trim', 'find-replace', 'processing-failed',
    )):
        return 'summary' if any(token in page_id for token in (
            'transcript', 'speaker', 'find-replace', 'processing-failed',
        )) else 'recording'
    if any(token in page_id for token in ('home', 'navigation', 'create-menu', 'calendar')):
        return 'home'
    if 'chat' in page_id:
        return 'ask'
    if any(token in page_id for token in (
        'settings', 'preferences', 'storage', 'account', 'login', 'theme',
        'notifications',
    )):
        return 'settings'
    if any(token in page_id for token in ('note', 'template', 'export', 'share', 'links')):
        return 'summary'
    return 'library'


def find_gallery(version: str, explicit: str | None = None):
    if explicit:
        root = Path(explicit).resolve()
        if not (root / 'pages.json').is_file():
            raise ValueError(f'Gallery pages.json not found: {root}')
        return root, version, False
    exact = ROOT / 'design-baseline' / f'v{version}'
    if (exact / 'pages.json').is_file():
        return exact, version, False
    available = []
    for path in (ROOT / 'design-baseline').glob('v*/pages.json'):
        key = version_tuple(path.parent.name)
        if key:
            available.append((key, path.parent))
    if not available:
        raise ValueError('No design-baseline/v*/pages.json gallery is available')
    _, root = max(available, key=lambda item: item[0])
    gallery_version = root.name[1:]
    return root, gallery_version, True


def load_pages(root: Path):
    raw = json.loads((root / 'pages.json').read_text(encoding='utf-8'))
    if isinstance(raw, dict):
        raw = raw.get('pages')
    if not isinstance(raw, list) or not raw:
        raise ValueError('Gallery pages.json must contain a non-empty pages array')
    pages = []
    for page in raw:
        page_id = str(page.get('id', '')).strip()
        if not re.fullmatch(r'[a-z0-9-]{1,80}', page_id):
            raise ValueError(f'Invalid gallery page id: {page_id!r}')
        variants = page.get('variants') or []
        if not 1 <= len(variants) <= 3:
            raise ValueError(f'Gallery page {page_id} must have 1-3 variants')
        prepared = []
        for variant in variants:
            name = str(variant.get('name', '')).strip()
            if name not in VARIANTS:
                # A few responsive-only pages use 360/390/1100 widths. Keep the
                # phone-width capture as the light variant instead of dropping
                # the whole page.
                if name in ('360', '390', '1100') and not any(v['name'] == 'light' for v in prepared):
                    name = 'light'
                else:
                    continue
            if any(v['name'] == name for v in prepared):
                continue
            relative = str(variant.get('screenshot', '')).strip()
            path = (root / relative).resolve()
            if root.resolve() not in path.parents or not path.is_file():
                raise ValueError(f'Gallery screenshot missing: {relative}')
            digest = str(variant.get('sha256', '')).strip()
            if digest and sha(path) != digest:
                raise ValueError(f'Gallery screenshot hash changed: {relative}')
            prepared.append({
                'name': name,
                'path': path,
                'sha256': sha(path),
                'filename': f'{page_id}-{name}.png',
            })
        if not prepared:
            continue
        title_zh = str(page.get('title', '')).strip() or page_id
        evidence = str(page.get('evidence', '')).strip()
        pages.append({
            'id': page_id,
            'title': words(title_zh[:2000], english_title(page_id)[:2000]),
            'module': module_for(page_id),
            'source': 'widget',
            'description': words(
                'Flutter 合成资料界面渲染；真实设备仍待验收。',
                (evidence or 'Synthetic-data Flutter render. Physical devices remain unverified.')[:2000],
            ),
            'featured': page_id in CORE_PAGES,
            'variants': prepared,
        })
    return pages


WEB_PREVIEW_RELEASE = 'https://54-214-180-183.sslip.io/app-preview/release.json'


def public_web_release(*, preview_only=False):
    urls = (WEB_PREVIEW_RELEASE,) if preview_only else (
        WEB_PREVIEW_RELEASE, 'https://54-214-180-183.sslip.io/app/release.json',
    )
    for url in urls:
        try:
            context = ssl.create_default_context()
            with urllib.request.urlopen(url, timeout=8, context=context) as response:
                value = json.loads(response.read(1 << 20).decode('utf-8'))
            version = str(value.get('version', ''))
            base = str(value.get('app_ui_base', ''))
            commit = str(value.get('source_commit', ''))
            if re.fullmatch(r'\d+\.\d+\.\d+', version) and re.fullmatch(r'\d+\.\d+\.\d+', base):
                return {'version': version, 'app_ui_base': base, 'source_commit': commit,
                        'app_ui_build': value.get('app_ui_build')}
        except Exception:
            continue
    return None


def acceptance(report: dict, gallery_version: str, stale: bool, pages: list, web, root: Path):
    version = report['version']
    web = web or {}
    app_ui_base = version
    source_commit = web.get('source_commit') or report['commit']
    if not re.fullmatch(r'[a-f0-9]{40}', source_commit or ''):
        source_commit = report['commit']
    if not re.fullmatch(r'[a-f0-9]{40}', source_commit or ''):
        raise ValueError('A 40-character source commit is required for the showcase')
    notes = ROOT / f'RELEASE-{version}.txt'
    manifest = ROOT / 'dist' / f'Teno-{version}-manifest.json'
    sources = []
    if manifest.is_file():
        sources.append({'label': f'Teno {version} manifest', 'reference': f'dist/{manifest.name}', 'sha256': sha(manifest)})
    if notes.is_file():
        sources.append({'label': f'Teno {version} release notes', 'reference': notes.name, 'sha256': sha(notes)})
    sources.append({
        'label': f'UI gallery source v{gallery_version}',
        'reference': (root / 'pages.json').relative_to(ROOT).as_posix(),
        'sha256': sha(root / 'pages.json'),
    })
    checks = [
        {
            'name': words('Android 构建已上报', 'Android build reported'),
            'status': 'passed',
            'detail': words(
                f'Android {version} 构建成功并已上报到 Team 开发页。',
                f'Android {version} built successfully and was reported to the Team development page.',
            ),
        },
        {
            'name': words('UI 截图基线', 'UI screenshot base'),
            'status': 'partial' if stale else 'passed',
            'detail': words(
                f'使用 {gallery_version} 的完整 UI 基线{f"；{version} 变更页面待重拍" if stale else "，与本版本一致"}。',
                f'Using the complete {gallery_version} UI baseline{f"; changed {version} pages await recapture" if stale else ", matching this version"}.',
            ),
        },
        {
            'name': words('真实设备验收', 'Physical device acceptance'),
            'status': 'pending',
            'detail': words(
                'Magic4 Pro、真实 JWD 与签名 iPhone 安装仍待实机验收。',
                'Magic4 Pro, real JWD and signed iPhone installation remain pending physical acceptance.',
            ),
        },
    ]
    return {
        'version': web.get('version') or version,
        'app_ui_base': app_ui_base,
        'source_commit': source_commit,
        'description': words(
            f'{len(pages)} 个页面状态的 Flutter 合成资料截图；验收结论仅适用于列出的版本。',
            f'Flutter synthetic-data screenshots for {len(pages)} page states; acceptance applies only to the listed versions.',
        ),
        'checks': checks,
        'sources': sources,
        'evidence_ids': [],
    }


def prepare(version: str, commit: str, gallery: str | None = None):
    root, gallery_version, stale = find_gallery(version, gallery)
    pages = load_pages(root)
    web = public_web_release()
    report = {'version': version, 'commit': commit}
    acceptance_value = acceptance(report, gallery_version, stale, pages, web, root)
    return root, gallery_version, stale, pages, acceptance_value


def publish(build_id: str, version: str, commit: str, config, output: Path,
            gallery: str | None = None):
    root, gallery_version, stale, pages, acceptance_value = prepare(version, commit, gallery)
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    screenshots = {}
    for page in pages:
        for variant in page['variants']:
            screenshots.setdefault(variant['sha256'], variant)
    uploaded = {}
    def upload(item):
        digest, variant = item
        result = request(
            config, 'PUT',
            '/api/v1/development-reporting/assets/' + digest + '?' + urlencode({
                'kind': 'screenshot',
                'filename': variant['filename'],
            }),
            file=variant['path'],
        )
        return digest, result['id']
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for digest, asset_id in pool.map(upload, screenshots.items()):
            uploaded[digest] = asset_id
    evidence_path = output / f'showcase-acceptance-{version}.txt'
    evidence_path.write_text(json.dumps({
        'version': version,
        'gallery_version': gallery_version,
        'stale_gallery': stale,
        'pages': len(pages),
        'screenshots': sum(len(page['variants']) for page in pages),
    }, ensure_ascii=False, indent=2), encoding='utf-8')
    evidence = request(
        config, 'PUT',
        '/api/v1/development-reporting/assets/' + sha(evidence_path) + '?' + urlencode({
            'kind': 'evidence',
            'filename': evidence_path.name,
        }),
        file=evidence_path,
    )
    for page in pages:
        for variant in page['variants']:
            variant['asset_id'] = uploaded[variant['sha256']]
            variant.pop('path', None)
            variant.pop('sha256', None)
            variant.pop('filename', None)
    acceptance_value['evidence_ids'] = [evidence['id']]
    payload = {
        'build_id': build_id,
        'pages': pages,
        'acceptance': acceptance_value,
    }
    (output / f'showcase-{version}.json').write_text(
        json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8'
    )
    try:
        result = request(config, 'POST', '/api/v1/development-reporting/showcase', payload)
    except ValueError as error:
        if 'HTTP 409' in str(error):
            print('Showcase already published for this build; keeping the existing gallery.')
            return {'duplicate': True, 'pages': len(pages)}
        raise
    result = {**result, 'pages': len(pages), 'screenshots': len(screenshots), 'stale': stale,
              'gallery_version': gallery_version}
    print(json.dumps(result, ensure_ascii=False))
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--build-id', required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--gallery')
    parser.add_argument('--credential', type=Path, default=Path.home() / '.ssh/teno-development-local.json')
    parser.add_argument('--output', type=Path, default=Path.home() / '.teno/development-releases/manual')
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    root, gallery_version, stale, pages, acceptance_value = prepare(args.version, args.commit, args.gallery)
    print(json.dumps({
        'gallery': str(root),
        'gallery_version': gallery_version,
        'stale': stale,
        'pages': len(pages),
        'screenshots': sum(len(page['variants']) for page in pages),
        'acceptance': acceptance_value,
    }, ensure_ascii=False, indent=2))
    if not args.prepare_only:
        publish(args.build_id, args.version, args.commit,
                configuration(args.credential), args.output, args.gallery)


if __name__ == '__main__':
    main()

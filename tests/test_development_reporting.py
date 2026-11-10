"""Producer retry and credential boundaries; no network or paid provider calls."""
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import report_development as report


class ReportingTests(unittest.TestCase):
    def test_missing_and_wrong_destination_credentials_are_rejected(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(ValueError): report.configuration()
        with patch.dict(os.environ, {'TENO_DEVELOPMENT_TOKEN':'tenodev_test','TENO_DEVELOPMENT_URL':'https://other.example'},clear=True):
            with self.assertRaises(ValueError): report.configuration()

    def test_metadata_waits_for_all_assets(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'evidence.txt';path.write_text('Reviewed evidence')
            envelope={'report':{'build_number':'one','occurred_at':'2026-11-07T00:00:00Z'},'files':[{'path':str(path),'sha256':report.sha(path),'kind':'evidence','label':report.words('证据','Evidence')}]}
            calls=[]
            def request(config, method, url, body=None, file=None):
                calls.append((method,url,body))
                if method=='PUT':raise RuntimeError('offline')
                return {'ok':True}
            with patch.object(report,'request',request):
                with self.assertRaises(RuntimeError):report.send(envelope,('url','credential'),Path(tmp)/'outbox')
            self.assertFalse(any(url.endswith('/results') for _,url,_ in calls))
            receipt=json.loads(next((Path(tmp)/'outbox').glob('*.json')).read_text(encoding='utf-8'))
            self.assertEqual(receipt['status'],'retryable')
            self.assertNotIn('credential',json.dumps(receipt))
            self.assertEqual(receipt['envelope']['report']['occurred_at'],'2026-11-07T00:00:00Z')

    def test_retry_preserves_identity_and_success_skips_network(self):
        with tempfile.TemporaryDirectory() as tmp:
            envelope={'report':{'build_number':'stable-build','occurred_at':'2026-11-07T00:00:00Z'},'files':[]}
            attempts=[]
            def request(config, method, url, body=None, file=None):
                attempts.append(body)
                return {'id':'record-id','duplicate':False}
            with patch.object(report,'request',request):
                first=report.send(envelope,('url','secret'),tmp)
                second=report.send(envelope,('url','secret'),tmp)
            self.assertEqual(first,second);self.assertEqual(len(attempts),1)

    def test_changed_local_asset_is_not_sent(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'evidence.txt';path.write_text('Changed')
            envelope={'report':{},'files':[{'path':str(path),'sha256':'0'*64,'kind':'evidence','label':report.words('证据','Evidence')}]}
            with patch.object(report,'request',return_value={}) as request:
                with self.assertRaises(ValueError):report.send(envelope,('url','secret'),Path(tmp)/'outbox')
            self.assertFalse(any(call.args[1]=='PUT' for call in request.call_args_list))

    def test_failed_ci_keeps_failure_and_no_installable_artifact(self):
        env={'GITHUB_RUN_ID':'123456','GITHUB_RUN_ATTEMPT':'2','GITHUB_SHA':'a'*40,'TENO_DEVELOPMENT_STEPS':'{"shared":"success","android":"failure"}'}
        with tempfile.TemporaryDirectory() as tmp,patch.dict(os.environ,env,clear=True):
            envelope=report.ci_envelope('android','failure',tmp)
            self.assertEqual(envelope['report']['outcome'],'failed')
            self.assertEqual(envelope['report']['physical'],'pending')
            self.assertNotIn('promote_baseline',envelope['report'])
            self.assertEqual(envelope['files'],[])
            self.assertEqual(report.ci_envelope('android','failure',tmp),envelope)

    def test_ios_identity_is_independent_and_exact_in_evidence(self):
        env={'GITHUB_RUN_ID':'123457','GITHUB_SHA':'b'*40,'TENO_DEVELOPMENT_STEPS':'{"device":"success"}'}
        with tempfile.TemporaryDirectory() as tmp,patch.dict(os.environ,env,clear=True):
            envelope=report.ci_envelope('ios','success',tmp)
            self.assertEqual(envelope['report']['version'],'1.0.0')
            self.assertIn('1.0 / Build 11',envelope['report']['title']['en'])
            self.assertIn('com.jwd.ZhiYan',envelope['report']['changes'][0]['en'])
            self.assertEqual(envelope['report']['distribution'],'evidence')
            self.assertEqual(envelope['files'],[])
            android=report.ci_envelope('android','success',tmp)
            self.assertEqual(android['report']['version'],'0.7.1')


if __name__=='__main__':unittest.main()

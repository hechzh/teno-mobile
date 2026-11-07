#!/usr/bin/env python3
"""Run a local build/test command, then report its result, including failures.

Only the chosen check name and exit status are uploaded, never command output.
Dirty workspaces deliberately do not claim an exact source commit.
"""
import argparse
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from report_development import ROOT, words, configuration, send, sha


def main():
    p=argparse.ArgumentParser();p.add_argument('--platform',choices=['android','ios'],required=True)
    p.add_argument('--name',required=True);p.add_argument('--environment',choices=['unit','emulator','simulator','static'],required=True)
    p.add_argument('--credential',type=Path,default=Path.home()/'.ssh/teno-development-local.json')
    p.add_argument('--outbox',type=Path,default=Path.home()/'.teno/development-outbox');p.add_argument('command',nargs=argparse.REMAINDER);args=p.parse_args()
    command=args.command[1:] if args.command and args.command[0]=='--' else args.command
    if not command:raise SystemExit('A build/test command is required')
    before=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT))
    result=subprocess.run(command,cwd=ROOT)
    after=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    dirty=dirty or before!=after or bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT))
    stamp=datetime.now(timezone.utc);number='local-'+stamp.strftime('%Y%m%dT%H%M%S%f')
    version=re.search(r"versionName\s+['\"]([^'\"]+)",(ROOT/'app/build.gradle').read_text())[1]
    args.outbox.mkdir(parents=True,exist_ok=True);evidence=args.outbox/(number+'.txt')
    evidence.write_text(json.dumps({'name':args.name,'exit_code':result.returncode,'environment':args.environment,'source_commit':None if dirty else before,'workspace_dirty':dirty,'time':stamp.isoformat()},ensure_ascii=False,indent=2),encoding='utf-8')
    report={'platform':args.platform,'version':version,'commit':None if dirty else before,'build_number':number,'occurred_at':stamp.isoformat(),'outcome':'passed' if result.returncode==0 else 'failed','implementation':'unknown','distribution':'evidence','physical':'pending','title':words(args.name,args.name),'tests':[{'name':words(args.name,args.name),'status':'passed' if result.returncode==0 else 'failed','environment':args.environment,'source':evidence.name}],'sources':[{'label':'Local check summary','reference':evidence.name,'sha256':sha(evidence)}],'pending':[words('工作区含未提交修改，未绑定提交。','Workspace changes prevent binding an exact commit.')] if dirty else []}
    envelope={'report':report,'files':[{'path':str(evidence),'kind':'evidence','sha256':sha(evidence),'label':words('本机检查摘要','Local check summary')}]}
    try:send(envelope,configuration(args.credential),args.outbox)
    except Exception:
        print('Development sync failed. The result is retained in the local outbox; retry with report_development.py --retry.')
        return result.returncode or 2
    return result.returncode


if __name__=='__main__':raise SystemExit(main())

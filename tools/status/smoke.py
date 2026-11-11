"""Bounded installed-CLI test: fail if migration enters the Nix/store boundary."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main(cli):
    cli = str(Path(cli).resolve())
    with tempfile.TemporaryDirectory(prefix='tvp-status-smoke-') as tmp:
        root=Path(tmp); marker=root/'called'; sentinels=root/'bin';sentinels.mkdir()
        for name in ('nix', 'nix-store', 'mktemp'):
            path=sentinels/name
            path.write_text('#!/bin/sh\nprintf "%s\\n" "$0 $*" >> "$TVP_SENTINEL"\nexit 93\n')
            path.chmod(0o755)
        env={**os.environ,'PATH':str(sentinels)+':'+os.environ.get('PATH',''), 'TVP_SENTINEL':str(marker)}
        def run(args, expected=0):
            result=subprocess.run([cli,*args],env=env,capture_output=True,text=True,timeout=10)
            assert result.returncode==expected,(args,result.returncode,result.stdout,result.stderr)
            return result
        run(['--migration'])
        result=json.loads(run(['--migration','--json']).stdout)
        assert result['schema']=='tvp.migration-status/v1'
        assert result['workflow'] is None
        assert json.loads(run(['--json','--migration']).stdout)==result
        family=next(iter(result['repository']['families']))
        selected=json.loads(run(['--migration','--family',family,'--json']).stdout)
        assert set(selected['repository']['families'])=={family}
        run(['--help']);run(['--migration','--help'])
        run(['--migration','--unknown'],2);run(['--migration','--family','does-not-exist'],2)
        run(['--workflow','/missing'],2)
        run(['--migration=bad'],2)
        workflow=root/'progress.json'
        workflow.write_text(json.dumps({'schema':1,'status':'paused','pausedByUser':True}))
        w=json.loads(run(['--migration','--workflow',str(workflow),'--json']).stdout)['workflow']
        assert w['status']=='paused' and w['binding']['state']=='unbound'
        assert not marker.exists(),marker.read_text() if marker.exists() else ''
        # Legacy compatibility at an explicit mock boundary, never the catalogue scan:
        # replace host nix-store with an empty closure fixture, record exactly its calls.
        (sentinels/'nix-store').write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$TVP_SENTINEL"\nexit 0\n')
        # owned shell runtime supplies real mktemp ahead of caller PATH.
        legacy=json.loads(run(['--json']).stdout)
        assert set(legacy)=={'versions','bases','buildSurface'}
        assert legacy['buildSurface'] is None
        assert len(marker.read_text().splitlines())==2
        assert all(line=='-qR --include-outputs --stdin' for line in marker.read_text().splitlines())
        marker.unlink()
        text=run([]).stdout
        assert 'canonical versions' in text and 'BUILD SURFACE' in text
        assert len(marker.read_text().splitlines())==2
    print('PASS: installed migration/help/errors bypass Nix/store; legacy JSON/text use only mocked closure boundary.')


if __name__=='__main__':main(sys.argv[1])

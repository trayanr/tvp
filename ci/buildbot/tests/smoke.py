"""Real Git admission gate + exact-head Nix smoke test, without GitHub requests.

Run in the CI shell with --runner pointing to a realised trusted tvp-test executable.
The fixture uses the existing locked Nixpkgs revision and keeps evidence under /tmp.
"""
import argparse
import importlib.util,json,os,shutil,subprocess,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--runner', required=True, type=Path)
parser.add_argument('--evidence', type=Path)
args=parser.parse_args()
spec=importlib.util.spec_from_file_location('job',root/'ci/buildbot/job.py');job=importlib.util.module_from_spec(spec);spec.loader.exec_module(job)
area=(args.evidence or Path(tempfile.mkdtemp(prefix='tvp-ci-smoke-'))).resolve();area.mkdir(parents=True,exist_ok=True)
repository=area/'remote';repository.mkdir()
realnix=shutil.which('nix');bash=str(Path(shutil.which('bash')).resolve());git=shutil.which('git')
def g(*argv): return subprocess.check_output([git,'-C',str(repository),*argv],text=True).strip()
g('init','--quiet','--initial-branch=master');g('config','user.name','Offline CI fixture');g('config','user.email','fixture@invalid');g('config','commit.gpgSign','false')
revision=json.load(open(root/'flake.lock'))['nodes']['nixpkgs']['locked']['rev']
flake='''{ inputs.nixpkgs.url = "github:NixOS/nixpkgs/NIXPKGS_REV"; outputs = { self, nixpkgs }: let
  pkgs = import nixpkgs { inherit system; };
  system = "x86_64-linux";
  discard = builtins.unsafeDiscardStringContext;
  script = builtins.path { name = "fixture-builder";
    path = builtins.toFile "tvp-ci-generated-SMOKE_ID" "printf passed > $out\\n"; };
  result = builtins.derivation { name = "tvp-ci-smoke-result"; inherit system; builder = BASH; args = [ script ]; };
  compatibility = import ./compatibility-tests.nix { inherit (pkgs) lib; };
  batches = pkgs.lib.genAttrs [ "first" "fixture" "last" "middle" "other" ] (name:
    compatibility.mkBatch { inherit pkgs; name = "smoke-" + name; suite.run = result; });
  common = { inherit pkgs batches; source = self.outPath; revision = self.rev or null; };
  plan = compatibility.mkPlan (common // { checks = {}; canonical = {}; smoke = true; });
in { smokeTestPlans.${system} = plan; smokeTestPlanParts.${system} = PLAN_EXPORT; checks.${system}.fixture = result;
 legacyPackages.${system}.graph = { schema = 1; entries.fixture = { drv = discard result.drvPath; out = discard result.outPath; };
 entries.retired = { drv = discard result.drvPath; out = discard result.outPath; }; }; }; }
'''.replace('NIXPKGS_REV',revision).replace('BASH', '"${pkgs.bash}/bin/bash"').replace('SMOKE_ID',area.name)
shutil.copyfile(root/'lib/compatibility-tests.nix', repository/'compatibility-tests.nix')
(repository/'flake.nix').write_text(flake.replace('PLAN_EXPORT', '{}'))
g('add','flake.nix','compatibility-tests.nix');subprocess.run([realnix,'flake','lock',str(repository)],check=True);g('add','flake.lock');g('commit','--quiet','-m','base');base=g('rev-parse','HEAD');original_base=base
g('checkout','--quiet','-b','expansion')
(repository/'expansion').write_text('new package version\n')
# Keep the test's result identical, but change its producer and remove a graph
# entry. The PR must still build without a controller-owned graph allowance.
parallel_plan = '''{
  planPart = args: compatibility.smokePlanPart (args // { inherit batches; });
  joinPlan = args: compatibility.joinSmokePlan (common // args);
}'''
(repository/'flake.nix').write_text(flake.replace('PLAN_EXPORT', parallel_plan)
    .replace('printf passed > $out', "printf '%s' passed > $out")
    .replace(' entries.retired = { drv = discard result.drvPath; out = discard result.outPath; };', ''))
g('add','expansion','flake.nix');g('commit','--quiet','-m','expand');head=g('rev-parse','HEAD')
# Advance the actual target independently, leaving the PR's payload base stale.
g('checkout','--quiet','master');(repository/'other-pr').write_text('another merged expansion\n');g('add','other-pr');g('commit','--quiet','-m','other expansion');base=g('rev-parse','HEAD')
runner=args.runner.resolve()
if not runner.is_file(): raise ValueError('Build the trusted test runner first')
wrappers=area/'bin';wrappers.mkdir();nix=wrappers/'nix';nix.write_text(f'''#!{bash}
echo "$@" >> '{area}/nix-calls'
if [[ "$1" == run ]]; then
    shift
    if [[ "$1" == --show-trace ]]; then shift; fi
    shift 2
    exec '{runner}' "$@"
fi
exec '{realnix}' "$@"
''');nix.chmod(0o755)
config=area/'gitconfig';config.write_text(f'[url "{repository}"]\n\tinsteadOf = https://github.com/fixture/tvp.git\n')
os.environ['GIT_CONFIG_GLOBAL']=str(config);os.environ['PATH']=str(wrappers)+os.pathsep+os.environ['PATH']
from types import SimpleNamespace
# Both stale admission and current-but-divergent heads fail before invoking Nix.
for name, queued_base, message in [('outdated', original_base, 'advanced'), ('diverged', base, 'must contain')]:
    rejected=area/name;rejected.mkdir();os.chdir(rejected)
    try:
        job.validate(SimpleNamespace(repository='fixture/tvp',head=head,base=queued_base,target_branch='master',tools_ref='offline-fixture',compare=str(root/'tools/graph/compare.py')))
        raise AssertionError('Outdated/divergent PR unexpectedly passed')
    except ValueError as error:
        assert message in str(error), str(error)
        (rejected/'rejection.txt').write_text(str(error)+'\n')
    assert not (rejected/'evidence/identity.json').exists()
    assert not (area/'nix-calls').exists()
print('Outdated and divergent PRs rejected before Nix.',flush=True)
# Master must work before any writable evaluation has registered its generated
# script. Running only the PR case would hide this fresh-store failure.
master_work=area/'master-work';master_work.mkdir();os.chdir(master_work)
master_result,master_code=job.validate(SimpleNamespace(repository='fixture/tvp',head=base,base='',tools_ref='offline-fixture',compare=str(root/'tools/graph/compare.py')))
assert master_code==0 and master_result['phase']=='passed'
assert (master_work/'evidence/candidate-graph.json').is_file()
# Only the author changes the branch; CI must build this exact updated head.
g('checkout','--quiet','expansion');g('merge','--no-edit','master');head=g('rev-parse','HEAD')
work=area/'work';work.mkdir();os.chdir(work)
result,code=job.validate(SimpleNamespace(repository='fixture/tvp',head=head,base=base,target_branch='master',tools_ref='offline-fixture',compare=str(root/'tools/graph/compare.py')))
print(json.dumps({'fixture':str(area),'code':code,'phase':result['phase'],'counts':result['counts'],'identity':result['ciIdentity']},indent=2))
assert code==0 and result['phase']=='passed'
assert result['ciIdentity']['merge']==head
assert subprocess.check_output([git,'-C',str(work/'candidate'),'rev-parse','HEAD'],text=True).strip()==head
assert (work/'candidate/expansion').is_file() and (work/'candidate/other-pr').is_file()
difference=json.loads((work/'evidence/graph-diff.json').read_text())
assert list(difference['changed'])==['fixture']
assert difference['removed']==['retired']
assert difference['ciIdentity']==result['ciIdentity']
for directory in (master_work, work):
    snapshot = directory/'ci-snapshot'
    assert snapshot.is_symlink()
    plan = Path(json.loads(snapshot.read_text())['plan'])
    installed = str(directory/'candidate')
    assert str(plan) == subprocess.check_output([realnix, 'eval', '--raw', installed + '#smokeTestPlans.x86_64-linux'], text=True)
    assert (directory/'evidence/candidate-graph.json').read_text().strip() == subprocess.check_output(
        [realnix, 'eval', '--json', installed + '#graph'], text=True).strip()
    assert str(plan) in subprocess.check_output(['nix-store', '--query', '--references', str(snapshot.resolve())], text=True).splitlines()
    assert (directory/'validation/latest/plan').resolve()==plan
    assert 'Reused CI smoke plan' in (directory/'evidence/prepare.log').read_text()
calls = (area/'nix-calls').read_text()
assert '#smokeTestPlans.' not in calls
assert calls.count('builtins.toFile "tvp-ci-smoke-part.json"') == job.SMOKE_EVALUATORS

"""Real Git merge + Nix full-plan smoke test, without GitHub requests.

Run in the CI shell with --runner pointing to a realised trusted tvp-test executable.
The fixture uses the existing locked Nixpkgs revision and keeps evidence under /tmp.
"""
import argparse
import importlib.util,json,os,shutil,subprocess,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--runner', required=True, type=Path)
args=parser.parse_args()
spec=importlib.util.spec_from_file_location('job',root/'ci/buildbot/job.py');job=importlib.util.module_from_spec(spec);spec.loader.exec_module(job)
area=Path(tempfile.mkdtemp(prefix='tvp-ci-smoke-')); repository=area/'remote';repository.mkdir()
realnix=shutil.which('nix');bash=str(Path(shutil.which('bash')).resolve());git=shutil.which('git')
def g(*argv): return subprocess.check_output([git,'-C',str(repository),*argv],text=True).strip()
g('init','--quiet');g('config','user.name','Offline CI fixture');g('config','user.email','fixture@invalid');g('config','commit.gpgSign','false')
revision=json.load(open(root/'flake.lock'))['nodes']['nixpkgs']['locked']['rev']
flake='''{ inputs.nixpkgs.url = "github:NixOS/nixpkgs/NIXPKGS_REV"; outputs = { self, nixpkgs }: let
  pkgs = import nixpkgs { inherit system; };
  system = "x86_64-linux";
  discard = builtins.unsafeDiscardStringContext;
  script = builtins.path { name = "fixture-builder";
    path = builtins.toFile "tvp-ci-generated-SMOKE_ID" "printf passed > $out\\n"; };
  result = builtins.derivation { name = "tvp-ci-smoke-result"; inherit system; builder = BASH; args = [ script ]; };
  plan = builtins.derivation { name = "tvp-ci-smoke-plan"; inherit system; builder = BASH; args = [ "-c" "printf '%s' \\\"$manifest\\\" > $out" ];
    manifest = builtins.toJSON { schema = 1; revision = self.rev or null; source = self.outPath; inherit system;
      aggregate = builtins.unsafeDiscardOutputDependency result.drvPath;
      jobs = [{ name = "fixture"; drv = builtins.unsafeDiscardOutputDependency result.drvPath; outputs = [ (discard result.outPath) ];
        tests = [{ name = "run"; drv = builtins.unsafeDiscardOutputDependency result.drvPath; outputs = [ (discard result.outPath) ]; }]; }]; skipped = []; }; };
in { testPlans.${system} = plan; checks.${system}.fixture = result;
 graph = { schema = 1; entries.fixture = { drv = discard result.drvPath; out = discard result.outPath; }; }; }; }
'''.replace('NIXPKGS_REV',revision).replace('BASH', '"${pkgs.bash}/bin/bash"').replace('SMOKE_ID',area.name)
(repository/'flake.nix').write_text(flake);g('add','flake.nix');subprocess.run([realnix,'flake','lock',str(repository)],check=True);g('add','flake.lock');g('commit','--quiet','-m','base');base=g('rev-parse','HEAD')
(repository/'expansion').write_text('new package version\n');g('add','expansion');g('commit','--quiet','-m','expand');head=g('rev-parse','HEAD')
# Make the base diverge so the harness must perform a real merge.
g('checkout','--quiet',base);(repository/'other-pr').write_text('another merged expansion\n');g('add','other-pr');g('commit','--quiet','-m','other expansion');base=g('rev-parse','HEAD')
runner=args.runner.resolve()
if not runner.is_file(): raise ValueError('Build the trusted test runner first')
wrappers=area/'bin';wrappers.mkdir();nix=wrappers/'nix';nix.write_text(f'''#!{bash}
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
# Master must work before any writable evaluation has registered its generated
# script. Running only the PR case would hide this fresh-store failure.
master_work=area/'master-work';master_work.mkdir();os.chdir(master_work)
master_result,master_code=job.validate(SimpleNamespace(repository='fixture/tvp',head=base,base='',tools_ref='offline-fixture',compare=str(root/'tools/graph/compare.py'),allow_change=[]))
assert master_code==0 and master_result['phase']=='passed'
assert (master_work/'evidence/candidate-graph.json').is_file()
work=area/'work';work.mkdir();os.chdir(work)
result,code=job.validate(SimpleNamespace(repository='fixture/tvp',head=head,base=base,tools_ref='offline-fixture',compare=str(root/'tools/graph/compare.py'),allow_change=[]))
print(json.dumps({'fixture':str(area),'code':code,'phase':result['phase'],'counts':result['counts'],'identity':result['ciIdentity']},indent=2))
assert code==0 and result['phase']=='passed'
assert result['ciIdentity']['merge'] not in [base,head]
assert (work/'candidate/expansion').is_file() and (work/'candidate/other-pr').is_file()

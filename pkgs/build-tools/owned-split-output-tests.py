import gzip,json,os,subprocess,sys,tempfile
from pathlib import Path
repo = Path(__file__).resolve().parents[2]
helper = repo / 'pkgs/build-tools/owned-split-output.py'
primitives = repo / 'lib/installed-tree.py'
count=0
with tempfile.TemporaryDirectory(prefix='tvp-owned-tools-fixture-') as td:
 root=Path(td)/'final';root.mkdir();old=os.fsencode(str(root).replace('final','prior'));new=os.fsencode(root);assert len(old)==len(new)
 shell='/nix/store/build-shell/bin/bash';runtime='/nix/store/changed-runtime-shell/bin/bash'
 slot=shell.encode()+b'\0TVP_ORDINARY_SHELL_'+b'X'*238
 config={'slots':[[shell,runtime]], 'fixed':[['/////bin/sh','//////bin/z']]}
 # Synthetic byte fixtures deliberately require no compiler or package build.
 elf=b'\x7fELF\0string\0'+old+b'/share/data\0'+slot+b'\0/////bin/sh\0'
 (root/'elf').write_bytes(elf);os.link(root/'elf',root/'hardlink')
 (root/'archive').write_bytes(b'!<arch>\n\0'+old+b'/include\0')
 (root/'text').write_bytes(b'-I'+old+b'/include -L'+old+b'/lib\n')
 (root/'manual.gz').write_bytes(gzip.compress(old+b'/share/info\n',mtime=0))
 (root/'link').symlink_to(os.fsdecode(old)+ '/text')
 def run(ok):
  r=subprocess.run([sys.executable,'-B',str(helper),str(root),os.fsdecode(old),json.dumps(config),str(primitives)],capture_output=True)
  assert (r.returncode==0)==ok,r.stderr.decode()
 run(True)
 assert (root/'elf').read_bytes()==elf.replace(old,new).replace(slot,runtime.encode()+b'\0'*(len(slot)-len(runtime))).replace(b'/////bin/sh',b'//////bin/z')
 assert (root/'elf').stat().st_ino==(root/'hardlink').stat().st_ino
 assert os.readlink(root/'link')==str(root/'text')
 assert gzip.decompress((root/'manual.gz').read_bytes())==new+b'/share/info\n'
 assert (root/'text').read_bytes()==b'-I'+new+b'/include -L'+new+b'/lib\n'
 count+=7
 # Validation errors occur before any write, including earlier valid files.
 for bad in [b'unknown\0'+old, old+b'not-a-path', b'\x7fELF\0'+old+b'/data\0TVP_ORDINARY_SHELL_'+b'X'*238]:
  (root/'text').write_bytes(old+b'/bin/tool\n');(root/'bad').write_bytes(bad)
  run(False);assert (root/'text').read_bytes()==old+b'/bin/tool\n';(root/'bad').unlink();count+=1
 external=Path(td)/'external';external.write_bytes(b'fixture');os.link(external,root/'outside-hardlink')
 run(False);count+=1
print(f'{count} relocation fixture checks passed (no compilation)')

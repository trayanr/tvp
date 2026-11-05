# Python is a BUILD helper. ninja_syntax.py remains ordinary installed source data.
{
  lib,
  tvp,
  base,
  src,
  version,
  bash,
  coreutils,
  python,
  gnutar,
  gzip,
  findutils,
  patch,
  sed,
  binutils,
  patchelf,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
in
{
  pname = "ninja";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment.tools = [
    python
    patch
    sed
  ];
  runtime.libraries = (final.base.environment final.environment).libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (command "ninja.prepare" ''
      ${patch}/bin/patch -p1 -i ${./patches/store-shell.patch}
      ${python}/bin/python3 -B - ${lib.escapeShellArg "${bash}/bin/bash"} <<'PY'
      from pathlib import Path
      import sys
      p = Path('src/subprocess-posix.cc')
      text = p.read_text()
      assert text.count('@TVP_SHELL@') == 2
      p.write_text(text.replace('@TVP_SHELL@', sys.argv[1]))
      # The optional web browser launches Python at runtime. The selected
      # minimal Python is BUILD-only; omit this optional feature explicitly.
      p = Path('configure.py')
      text = p.read_text()
      start = text.index('    def supports_ninja_browse(self) -> bool:')
      end = text.index('    def can_rebuild_in_place', start)
      text = text[:start] + '    def supports_ninja_browse(self) -> bool:\n        return False\n\n' + text[end:]
      p.write_text(text)
      PY
    '')
    (steps.shebangs {
      name = "ninja.source-shells";
      inherit python;
      paths = [ "src/inline.sh" ];
      names = [ "sh" ];
      interpreter = "${bash}/bin/bash";
    })
    (command "ninja.build" ''
      mkdir -p "$out/.tvp-evidence"
      trap 'status=$?; if (( status != 0 )); then cat "$out/.tvp-evidence/build.log"; fi' EXIT
      # Only the prepared compiler environment contributes flags.
      ${python}/bin/python3 -B configure.py --bootstrap --verbose --with-python=${python}/bin/python3 > "$out/.tvp-evidence/build.log" 2>&1
      cp build.ninja "$out/.tvp-evidence/"
    '')
    (
      (command "ninja.check" ''
        status=0
        ${python}/bin/python3 -B misc/ninja_syntax_test.py -v > "$out/.tvp-evidence/check.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$out/.tvp-evidence/check.status"
        cat "$out/.tvp-evidence/check.log"
        test "$status" = 0
      '')
      // {
        enabled = doCheck;
      }
    )
    (command "ninja.install" ''
      install -Dm755 ninja "$out/bin/ninja"
      # Drop the unused /usr/bin/python shebang: this file is an imported module.
      tail -n +2 misc/ninja_syntax.py > ninja_syntax.py
      install -Dm644 ninja_syntax.py "$out/share/ninja/ninja_syntax.py"
      install -Dm644 doc/manual.asciidoc "$out/share/doc/ninja/manual.asciidoc"
      install -Dm644 COPYING "$out/share/licenses/ninja/COPYING"
    '')
    (steps.split "ninja.finalize")
    (outputs.copyArtifacts { inherit coreutils; })
    {
      name = "ninja.remove-evidence";
      run = ''rm -rf "$out/.tvp-evidence"'';
    }
    (outputs.strip {
      inherit python binutils;
      paths = [ "bin" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [ "bin" ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "bin" ];
    })
  ];
}

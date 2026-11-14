# Test-only linker support, same sysroot wrapper and plan; no production edge.
{ package, context }:
let
  inherit (package.specification) base bash coreutils;
in
(context.mkTest {
  inherit package;
  name = "sysroot-linker-support";
  script = ":";
  expected = "";
}).edit
  (
    s:
    s
    // {
      pname = "python-test-sysroot-linker";
      version = "1";
      plan = [
        {
          name = "linker.install";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/ld" <<'SH'
            #!${bash}/bin/bash
            exec ${base.compiler.bintools}/bin/ld --sysroot=${base.compiler.libc} "$@"
            SH
            chmod +x "$out/bin/ld"
          '';
        }
      ];
    }
  )

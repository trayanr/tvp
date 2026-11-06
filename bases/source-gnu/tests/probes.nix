{
  candidate ? import ../. { },
}:
let
  inherit (candidate)
    builder
    base
    tools
    lib
    ;
  make =
    recipe:
    builder {
      inherit recipe;
      args = { };
      dependencyNames = [ ];
      metadata = { };
      selection.kind = "source-gnu-compiler-probe";
      mkTests = _: { };
    };
  sentinel = make (
    { }:
    {
      pname = "source-gnu-forwarding-compiler";
      version = "1";
      src = null;
      inherit base;
      inherit (tools) bash coreutils;
      passthru = {
        inherit (base.compiler)
          bintools
          libc
          libcTools
          defaultHardeningFlags
          runtimeDirectories
          ;
      };
      plan = [
        {
          name = "sentinel.install";
          run = ''
            mkdir -p "$out/bin"
            for name in cc c++; do
              cat > "$out/bin/$name" <<SCRIPT
            #!${tools.bash}/bin/bash
            printf '%s\n' selected >> "\$PWD/selected-compiler"
            exec ${base.compiler}/bin/$name "\$@"
            SCRIPT
              chmod +x "$out/bin/$name"
            done
            cat > "$out/bin/reject" <<'SCRIPT'
            #!${tools.bash}/bin/bash
            printf '%s\n' deliberate-rejection >&2
            exit 23
            SCRIPT
            chmod +x "$out/bin/reject"
          '';
        }
      ];
    }
  );
  selected = base.override { compiler = sentinel; };
  consumer = make (
    { }:
    final: {
      pname = "source-gnu-compiler-probes";
      version = "1";
      src = null;
      base = selected;
      inherit (tools) bash coreutils;
      plan = [
        (
          (final.base.environment { })
          // {
            name = "compiler.replacement";
            run = ''
              printf 'int main(void) { return 0; }\n' > probe.c
              "$CC" probe.c -o probe-c
              "$CXX" -x c++ probe.c -o probe-cxx
              ./probe-c
              ./probe-cxx
              test "$(cat selected-compiler)" = $'selected\nselected'
              mkdir -p "$out"
              cp selected-compiler "$out/compiler-replacement"
            '';
          }
        )
        (
          (final.base.environment { overrides.values.CC = "${sentinel}/bin/reject"; })
          // {
            name = "compiler.environment-override";
            run = ''
              status=0
              "$CC" probe.c -o forbidden >stdout 2>stderr || status=$?
              test "$status" = 23
              test "$(cat stderr)" = deliberate-rejection
              test ! -e forbidden
              cp stderr "$out/environment-override"
            '';
          }
        )
        (
          (
            (final.base.override {
              compiler = sentinel // {
                outPath = "/missing-selected-compiler";
              };
            }).environment
            { }
          )
          // {
            name = "compiler.poisoned-selection";
            run = ''
              status=0
              "$CC" probe.c -o forbidden >stdout 2>stderr || status=$?
              test "$status" = 127
              test ! -e forbidden
              cp stderr "$out/poisoned-selection"
            '';
          }
        )
      ];
    }
  );
in
{
  inherit sentinel consumer;
}

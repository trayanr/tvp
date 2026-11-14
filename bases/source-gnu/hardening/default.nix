# Consumer adapters only; all selected construction producers remain unchanged.
{
  candidate,
  policy ? { },
}:
let
  inherit (candidate) base builder tools;
  checked = import ../../../lib/hardening-policy.nix policy;
  make =
    args: recipe:
    builder {
      inherit args recipe;
      dependencyNames = builtins.filter (name: name != "policy") (builtins.attrNames args);
      metadata = { };
      selection.kind = "source-gnu-consumer-hardening";
      mkTests = _: { };
    };
  # Shell-quoted paths are construction data, never caller command fragments.
  launcher =
    {
      python,
      driver,
      bintools,
      selected,
      names,
    }:
    ''
      mkdir -p "$out/bin"
      cp ${./adapter.py} "$out/adapter.py"
      for name in ${builtins.concatStringsSep " " names}; do
        cat > "$out/bin/$name" <<SCRIPT
      #!${python}/bin/python3
      import os, sys, runpy
      runpy.run_path("$out/adapter.py", init_globals={
          "PROGRAM": os.path.basename(sys.argv[0]),
          "DRIVER": "${driver}/bin",
          "BINTOOLS": "${bintools}/bin",
          "DEFAULTS": ${builtins.toJSON selected},
      }, run_name="__main__")
      SCRIPT
        chmod +x "$out/bin/$name"
      done
    '';
  linker =
    make
      {
        bintools = base.compiler.bintools;
        python = tools.python;
        inherit policy;
      }
      (
        {
          bintools,
          python,
          policy,
        }:
        final: {
          pname = "source-gnu-consumer-hardening-linker";
          version = "1";
          src = null;
          inherit
            base
            bintools
            python
            policy
            ;
          inherit (tools) bash coreutils;
          passthru = {
            underlyingBintools = final.bintools;
            hardeningPolicy = (import ../../../lib/hardening-policy.nix final.policy);
          };
          plan = [
            {
              name = "hardening.linker";
              run =
                launcher {
                  inherit (final) python bintools;
                  driver = final.bintools; # unused in ld mode, an explicit valid path
                  selected = (import ../../../lib/hardening-policy.nix final.policy).selected;
                  names = [ "ld" ];
                }
                + ''
                  for tool in ${final.bintools}/bin/*; do
                    name=$(basename "$tool")
                    test -e "$out/bin/$name" || ln -s "$tool" "$out/bin/$name"
                  done
                '';
            }
          ];
        }
      );
  compiler =
    make
      {
        driver = base.compiler;
        bintools = linker;
        python = tools.python;
        inherit policy;
      }
      (
        {
          driver,
          bintools,
          python,
          policy,
        }:
        final: {
          pname = "source-gnu-consumer-hardening-driver";
          version = "1";
          src = null;
          inherit
            base
            driver
            bintools
            python
            policy
            ;
          inherit (tools) bash coreutils;
          passthru = {
            inherit (final.driver) libc libcTools runtimeDirectories;
            inherit (final) bintools;
            hardeningPolicy = import ../../../lib/hardening-policy.nix final.policy;
            defaultHardeningFlags = (import ../../../lib/hardening-policy.nix final.policy).selected;
            underlyingDriver = final.driver;
            underlyingBintools = (final.bintools.underlyingBintools or final.bintools);
          };
          plan = [
            {
              name = "hardening.driver";
              run = launcher {
                inherit (final) python driver bintools;
                selected = (import ../../../lib/hardening-policy.nix final.policy).selected;
                names = [
                  "cc"
                  "gcc"
                  "c++"
                  "g++"
                  "cpp"
                  "x86_64-unknown-linux-gnu-gcc"
                  "x86_64-unknown-linux-gnu-g++"
                  "x86_64-unknown-linux-gnu-cpp"
                ];
              };
            }
          ];
        }
      );
in
if checked.selected == [ ] then base else base.override { inherit compiler; }

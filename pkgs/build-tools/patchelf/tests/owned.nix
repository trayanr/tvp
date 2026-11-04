{
  pkgs,
  tvpLib,
  package,
  tvp,
}:
let
  inherit (package.tvp.declaredDependencies)
    binutils
    patchelf
    cxxRuntime
    python
    ;
  custom = (package.override { doCheck = false; }).editSteps (
    tvp.builder.steps.append [
      {
        name = "patchelf.custom-marker";
        run = ''mkdir -p "$out/nix-support"; printf edited > "$out/nix-support/marker"'';
      }
    ]
  );
  runtime = custom.editRuntime (
    r:
    r // { dlopenDirectories = [ "${cxxRuntime}/lib/gcc/x86_64-pc-linux-gnu/${cxxRuntime.version}" ]; }
  );
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    compiler-runtime = {
      extraInputs = [
        binutils
        patchelf
        cxxRuntime
      ];
      script = ''
        ${binutils}/bin/readelf -d ${package}/bin/patchelf | grep -q 'libstdc++.so.6'
        rpath=$(${patchelf}/bin/patchelf --print-rpath ${package}/bin/patchelf)
        case ":$rpath:" in *:${cxxRuntime}/lib:*) ;; *) exit 1;; esac
        env -i ${package}/bin/patchelf --version
      '';
      expected = "patchelf ${package.version}";
    };
    customization = {
      extraInputs = [
        runtime
        patchelf
      ];
      script = ''
        test "$(cat ${runtime}/nix-support/marker)" = edited
        case ":$(${patchelf}/bin/patchelf --print-rpath ${runtime}/bin/patchelf):" in
          *:${cxxRuntime}/lib/gcc/x86_64-pc-linux-gnu/${cxxRuntime.version}:*) ;; *) exit 1;;
        esac
        ${runtime}/bin/patchelf --version
      '';
      expected = "patchelf ${package.version}";
    };
    runtime-expectation = {
      extraInputs = [ python ];
      script = ''
        test ${pkgs.lib.escapeShellArg patchelf.outPath} != ${pkgs.lib.escapeShellArg package.outPath}
        ${package}/bin/patchelf --print-needed ${package}/bin/patchelf | sort
      '';
      expected = "libc.so.6\nlibgcc_s.so.1\nlibm.so.6\nlibstdc++.so.6";
    };
  };
}

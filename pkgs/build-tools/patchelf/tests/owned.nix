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
    r
    // {
      dlopenDirectories = [ "${cxxRuntime}/lib/gcc/x86_64-unknown-linux-gnu/${cxxRuntime.version}" ];
    }
  );
  mkSuite =
    args:
    package.testContext.mkSuite {
      inherit package;
      tests = builtins.mapAttrs (_: spec: {
        inherit (spec) script expected;
        tools = (spec.extraInputs or [ ]) ++ [ package.tvp.deps.gnugrep ];
      }) args.tests;
    };
in
mkSuite {
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
        test "$(readlink -f "$(c++ -print-file-name=libstdc++.so.6)")" = "$(readlink -f ${cxxRuntime}/lib/libstdc++.so.6)"
        test "$(readlink -f "$(c++ -print-file-name=libgcc_s.so.1)")" = "$(readlink -f ${cxxRuntime}/lib/libgcc_s.so.1)"
        env -i LD_DEBUG=libs ${package}/bin/patchelf --version >/dev/null 2>loader
        grep -F 'calling init: ${cxxRuntime}/lib/libstdc++.so.6' loader >&2
        grep -F 'calling init: ${cxxRuntime}/lib/libgcc_s.so.1' loader >&2
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
          *:${cxxRuntime}/lib/gcc/x86_64-unknown-linux-gnu/${cxxRuntime.version}:*) ;; *) exit 1;;
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

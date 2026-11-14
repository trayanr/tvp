{
  pkgs,
  tvpLib,
  package,
}:
let
  make = package.specification.gnumake;
  construction = import ../../../../bases/source-gnu { };
  sourceCopy = (package.edit (s: removeAttrs s [ "artifactName" ])).editSteps (_: [
    {
      name = "source.copy";
      run = ''cp ${package.src} "$out"'';
    }
  ]);
  combined =
    ((package.override { doCheck = false; }).edit (
      spec:
      spec
      // {
        src = sourceCopy;
        bash = construction.tools.bash;
        coreutils = construction.tools.coreutils;
        base = spec.base.override {
          name = "source-gnu-which-control";
          shell = construction.tools.bash;
        };
        gnumake = spec.gnumake // {
          buildEnvironment = _: { values.WHICH_CONTROL = "selected"; };
        };
        configureFlags = [ "--disable-dependency-tracking" ];
        doCheck = true;
      }
    )).editRuntime
      (
        runtime:
        runtime
        // {
          dlopenDirectories = [ "${construction.toolchain.libc}/lib" ];
        }
      );
  combinedSteps = combined.editSteps (
    plan:
    plan
    ++ [
      {
        name = "which.final-control";
        tools = [ combined.specification.gnumake ];
        env =
          (builtins.head (builtins.filter (step: step.name == "which.configure") combined.buildSteps)).env;
        run = ''
          test "$WHICH_CONTROL" = selected
          printf '%s\n' final-fields > "$out/nix-support/final-fields"
        '';
      }
    ]
  );
  custom = (package.override { doCheck = false; }).editSteps (
    plan:
    plan
    ++ [
      {
        name = "which.consumer-marker";
        run = ''printf '%s\n' 'edited' > "$out/nix-support/consumer-marker"'';
      }
    ]
  );
in
package.testContext.mkSuite {
  inherit package;
  tools = with package.specification; [
    sed
    grep
    diffutils
  ];
  tests = {
    alias = {
      script = ''
        printf "alias tvp='tvp-no-such-command --flag'\n" | which --read-alias tvp
      '';
      expected = "alias tvp='tvp-no-such-command --flag'";
    };
    make-consumer = {
      tools = [ make ];
      script = ''
        printf 'all:\n\t@printf "consumer-ok\\n"\n' > Makefile
        found=$(PATH=${make}/bin ${package}/bin/which make)
        test "$found" = ${make}/bin/make
        "$found" --no-print-directory
      '';
      expected = "consumer-ok";
    };
    customization = {
      tools = [
        custom
        package.specification.sed
      ];
      script = ''
        cat ${custom}/nix-support/consumer-marker
        mkdir discovery
        touch discovery/tvp-tool
        chmod +x discovery/tvp-tool
        PATH="$PWD/discovery" ${custom}/bin/which tvp-tool | sed "s|$PWD/||"
      '';
      expected = "edited\ndiscovery/tvp-tool";
    };
    final-fields = {
      tools = [
        combinedSteps
        package.specification.patchelf
        package.specification.grep
      ];
      script =
        assert combinedSteps.specification.src.drvPath == sourceCopy.drvPath;
        assert combinedSteps.tests.lookup.drvPath != package.tests.lookup.drvPath;
        assert combinedSteps.specification.upstreamCheck.command.enabled;
        ''
          cat ${combinedSteps}/nix-support/final-fields
          ${combinedSteps.specification.patchelf}/bin/patchelf --print-rpath ${combinedSteps}/bin/which | grep -q '${construction.toolchain.libc}/lib'
          PATH=${combinedSteps.specification.gnumake}/bin ${combinedSteps}/bin/which make
        '';
      expected = "final-fields\n${combinedSteps.specification.gnumake}/bin/make";
    };
  };
}

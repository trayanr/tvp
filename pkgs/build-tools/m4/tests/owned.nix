{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  make = package.tvp.declaredDependencies.gnumake;
  custom = (package.override { doCheck = false; }).editSteps (
    plan:
    plan
    ++ [
      {
        name = "m4.consumer-marker";
        run = ''printf '%s\n' 'edited' > "$out/nix-support/consumer-marker"'';
      }
    ]
  );
  shell = tvp.lib.packages.withConstraint {
    category = "construction";
    reason = "Customization probe uses the completed base shell as an independently built runtime interpreter.";
  } tvp.bases.default.components.floor.bash;
  runtime = (package.override { doCheck = false; }).editRuntime (r: r // { inherit shell; });
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    runtime-shell = {
      extraInputs = [
        runtime
        shell
      ];
      script = ''
        grep -aFq '${shell}/bin/bash' ${runtime}/bin/m4
        printf "esyscmd(\`printf 42')\n" | ${runtime}/bin/m4
      '';
      expected = "42";
    };

    shell-command = {
      script = ''printf "esyscmd(\`printf shell-ok')\n" | m4'';
      expected = "shell-ok";
    };
    frozen-state = {
      script = ''
        printf "define(\`answer', \`42')dnl\n" | m4 --freeze-state=state
        printf 'answer\n' | m4 --reload-state=state
      '';
      expected = "42";
    };
    make-consumer = {
      extraInputs = [ make ];
      script = ''
        cat > make.m4 <<'M4'
        define(`answer', `42')dnl
        .RECIPEPREFIX := @
        all:
        @@printf '%s\n' answer
        M4
        m4 make.m4 > Makefile
        ${make}/bin/make --no-print-directory
      '';
      expected = "42";
    };
    customization = {
      extraInputs = [ custom ];
      script = ''
        cat ${custom}/nix-support/consumer-marker
        printf 'eval(20 + 22)\n' | ${custom}/bin/m4
      '';
      expected = "edited\n42";
    };
  };
}

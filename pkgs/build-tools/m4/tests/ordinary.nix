# One suite, shared by every m4 version. Never fork it per builder: a test that
# exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  tvp,
  package,
}:
package.testContext.mkSuite {
  inherit package;
  tools = [ package.tvp.deps.gawk ];

  tests = {
    version = {
      script = ''
        m4 --version | head -1 | awk '{ print $NF }'
      '';
      expected = package.version;
    };

    define = {
      script = ''
        printf "define(\`greet', \`tvp')greet\n" | m4
      '';
      expected = "tvp";
    };

    # The arithmetic evaluator, which is a separate engine from macro expansion.
    eval = {
      script = ''
        printf "eval(6 * 7)\n" | m4
      '';
      expected = "42";
    };

    # File inclusion is what autoconf actually leans on.
    include = {
      script = ''
        cp ${./fixtures/included.m4} included.m4
        printf "include(\`included.m4')tvp_included\n" | m4
      '';
      expected = "yes";
    };

    # Quoting is m4's most-used and most-misunderstood feature; a build that got
    # it wrong would corrupt every configure script it touched.
    changequote = {
      script = ''
        printf "changequote([, ])define([q], [tvp])q\n" | m4
      '';
      expected = "tvp";
    };
  };
}
// (
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
    } (import ../../../../bases/source-gnu { }).tools.bash;
    runtime = (package.override { doCheck = false; }).editRuntime (r: r // { inherit shell; });
  in
  package.testContext.mkSuite {
    inherit package;
    tools = [ package.tvp.deps.grep ];
    tests = {
      runtime-shell = {
        tools = [
          runtime
          shell
        ];
        script = ''
          ${package.tvp.deps.grep}/bin/grep -aFq '${shell}/bin/bash' ${runtime}/bin/m4
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
        tools = [ make ];
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
        tools = [ custom ];
        script = ''
          cat ${custom}/nix-support/consumer-marker
          printf 'eval(20 + 22)\n' | ${custom}/bin/m4
        '';
        expected = "edited\n42";
      };
    };
  }
)
// {
  constructor = import ../../native-tool-contract.nix { inherit pkgs tvp package; };
}
// (package.testContext.mkSuite {
  inherit package;
  tests = {
    empty-path-shell = {
      script = ''
        cat > shell.m4 <<'M4'
        syscmd(`exit 7')sysval
        esyscmd(`printf shell-ok')
        sysval
        M4
        env -i PATH=/absent ${package}/bin/m4 shell.m4
      '';
      expected = "7\nshell-ok\n0";
    };
    installed-payload = {
      script = ''
        test -s ${package}/share/info/m4.info
        test -s ${package}/share/man/man1/m4.1.gz
        test -s ${package}/nix-support/source-date-epoch
        test "$(cat ${package}/nix-support/source-date-epoch)" -ge 315532800
        printf manuals
      '';
      expected = "manuals";
    };
  };
})

// {
  split = import ./ordinary-split.nix { inherit package; };
}

# Installed assertions are shared by all supported releases. Build controls edit
# the effective base; their providers are test-only and never production defaults.
{
  package,
  lib,
  context,
}:
let
  p = package;
  tools = p.specification.base.standardTools;
  testDeps = p.tvp.declaredTestDependencies;
  shell = testDeps.runtimeShell;
  custom = (p.override { doCheck = false; }).editSteps (
    plan:
    plan
    ++ [
      {
        name = "m4.consumer-marker";
        run = ''printf '%s\n' 'edited' > "$out/nix-support/consumer-marker"'';
      }
    ]
  );
  runtime = (p.override { doCheck = false; }).editRuntime (r: r // { inherit shell; });
in
(context.mkSuite {
  inherit package;
  tools = [
    tools.gawk
    tools.grep
  ];
  tests = {
    version = {
      script = ''m4 --version | head -1 | awk '{ print $NF }' '';
      expected = p.version;
    };
    define = {
      script = ''printf "define(\`greet', \`tvp')greet\n" | m4'';
      expected = "tvp";
    };
    eval = {
      script = ''printf "eval(6 * 7)\n" | m4'';
      expected = "42";
    };
    include = {
      script = ''
        cp ${./fixtures/included.m4} included.m4
        printf "include(\`included.m4')tvp_included\n" | m4
      '';
      expected = "yes";
    };
    changequote = {
      script = ''printf "changequote([, ])define([q], [tvp])q\n" | m4'';
      expected = "tvp";
    };
    runtime-shell = {
      tools = [
        runtime
        shell
        tools.grep
      ];
      script = ''
        test ${lib.escapeShellArg (toString shell)} != ${lib.escapeShellArg (toString p.specification.base.shell)}
        ${tools.grep}/bin/grep -aFq '${shell}/bin/bash' ${runtime}/bin/m4
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
      tools = [ tools.gnumake ];
      script = ''
        cat > make.m4 <<'M4'
        define(`answer', `42')dnl
        .RECIPEPREFIX := @
        all:
        @@printf '%s\n' answer
        M4
        m4 make.m4 > Makefile
        ${tools.gnumake}/bin/make --no-print-directory
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
        test -s ${p}/share/info/m4.info
        test -s ${p}/share/man/man1/m4.1.gz
        test -s ${p}/nix-support/source-date-epoch
        test "$(cat ${p}/nix-support/source-date-epoch)" -ge 315532800
        test ! -e ${p}/nix-support/m4-build-tree
        printf manuals
      '';
      expected = "manuals";
    };
  };
})
// {
  constructor = import ../../native-tool-contract.nix { inherit package lib context; };
  split = import ./split.nix { inherit package context; };
}
// lib.optionalAttrs (p.specification.upstreamCheck.enabled or true) {
  upstream = context.mkUpstream { inherit package; };
}

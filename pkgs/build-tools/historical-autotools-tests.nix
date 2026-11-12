# Historical consumer qualification uses each package's retained feature profile.
# Upstream make check is a separate rebuild, never a production dependency.
{
  pkgs,
  tvp,
  package,
}:
let
  p = package;
  steps = tvp.builder.steps;
  parts = steps.partition p.specification.plan;
  upstream = p.editSteps (
    _:
    parts.first
    ++ [
      (
        (p.specification.base.environment p.specification.environment)
        // {
          name = "${p.pname}.upstream";
          cwd = "source";
          run = ''
            export CONFIG_SHELL=${p.specification.bash}/bin/bash SHELL=${p.specification.bash}/bin/bash
            status=0
            ${p.specification.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL="$CONFIG_SHELL" check || status=$?
            find . -name '*suite.log' -exec cat {} \; >&2
            if (( status != 0 )); then exit "$status"; fi
            mkdir -p "$out/nix-support/upstream"
            printf 'historical upstream checks completed\n' > "$out/nix-support/upstream/result"
          '';
        }
      )
    ]
  );
  runtime = p.editRuntime (r: r // { shell = p.tvp.declaredTestDependencies.runtimeShell; });
  source = p.edit (s: s // { src = p.tvp.declaredTestDependencies.alternateSource; });
in
p.testContext.mkSuite {
  package = p;
  tests = {
    helper-confinement-and-frontends = {
      script = ''
        ${p.specification.python}/bin/python3 -B ${./ordinary-autotools-safety-tests.py} \
          ${./ordinary-autotools-source.py} ${./automake/ordinary/prepare-api.py} \
          ${./ordinary-autotools-output.py} ${./historical-autotools-output.py}
      '';
      expected = "helper-contracts";
    };
    upstream = {
      script = ''test -s ${upstream}/nix-support/upstream/result; printf upstream'';
      expected = "upstream";
    };
    artifact-finalization = {
      expected =
        assert (p.override { }).drvPath == p.drvPath;
        assert (p.edit (s: s)).drvPath == p.drvPath;
        assert runtime.artifact.drvPath == p.artifact.drvPath;
        assert runtime.drvPath != p.drvPath;
        assert source.artifact.drvPath != p.artifact.drvPath;
        assert p.out.artifact.drvPath == p.artifact.drvPath;
        assert (builtins.head p.all).drvPath == p.drvPath;
        "split";
      script = ''
        env -i PATH=/absent ${runtime}/bin/${p.pname} --version >&2
        printf split
      '';
    };
  };
}

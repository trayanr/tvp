# Pure regressions for public tool overrides and header/runtime test binding.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  sed = (import ../../../../bases/source-gnu { }).tools.sed;
  selectedSed = pkgs.runCommand "ruby-gnused-override-contract" { } ''
    mkdir -p "$out/bin"
    ln -s ${sed}/bin/sed "$out/bin/sed"
  '';
  overrideContract =
    package:
    let
      direct = package.override { gnused = selectedSed; };
      function = package.override (_: {
        gnused = selectedSed;
      });
      configure = lib.findFirst (s: s.name == "ruby.configure") null direct.buildSteps;
    in
    direct.drvPath == function.drvPath
    && direct.artifact.drvPath != package.artifact.drvPath
    && lib.hasInfix (builtins.unsafeDiscardStringContext "${selectedSed}/bin/sed") configure.run
    &&
      builtins.all (p: p.tvp.deps.gnused.drvPath == selectedSed.drvPath && p.drvPath == direct.drvPath)
        (
          [
            direct
            direct.out
            function
            function.out
          ]
          ++ direct.all
          ++ function.all
        );
  construction = tvp.canonical.ruby_3_3_12.override { openssl = tvp.packages.openssl_4_0_0; };
  runtime = construction.editRuntime (r: r // { openssl = tvp.packages.openssl_4_0_1; });
  compare = lib.findFirst (s: s.name == "test.compare") null runtime.tests.openssl.buildSteps;
in
{
  canonicalGnusedOverride = overrideContract tvp.canonical.ruby_4_0_6;
  variantGnusedOverride = overrideContract tvp.variants.build-steps.ruby_4_0_6;
  constructionOpenSSLExpectation =
    runtime.artifact.drvPath == construction.artifact.drvPath
    && runtime.drvPath != construction.drvPath
    && runtime.tvp.deps.openssl.version == "4.0.1"
    && lib.hasInfix "expected='4.0.0 f6f6ead0bd85c312'" compare.run
    && !(lib.hasInfix "expected='4.0.1 f6f6ead0bd85c312'" compare.run);
}

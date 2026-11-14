{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  retained = (import ./legacy.nix { inherit pkgs tvp; }).publicArgs;
  candidate = import ../../../bases/source-gnu { };
  tool =
    role:
    tvpLib.packages.tagSelection {
      namespace = "source-gnu.inputs";
      selector = role;
      kind = "source-base-build-tool";
      reason = "Explicit retained owned tool for the C-source Go bootstrap procedure.";
    } candidate.tools.${role};
  definition =
    (tvpLib.packages.mkDefs {
      "20171003" = {
        constructor = tvp.builder;
        builder = ./native/build-20171003.nix;
        base = candidate.base;
        helpers = {
          inherit tvp;
        };
        source =
          { version, sha256 }:
          pkgs.fetchurl {
            url = "https://dl.google.com/go/go1.4-bootstrap-${version}.tar.gz";
            inherit sha256;
          };
        testContext =
          package:
          tvpLib.tests.fromPackage {
            builder = tvp.builder;
            inherit package;
          };
        deps = {
          compiler = candidate.base.compiler;
          bash = tool "bash";
          coreutils = tool "coreutils";
          gnutar = tool "tar";
          gzip = tool "gzip";
          findutils = tool "findutils";
          grep = tool "grep";
          sed = tool "sed";
          helperPython = tool "python";
          binutils = tool "binutils";
          patchelf = tool "patchelf";
          runtimeShell = tool "bash";
          runtimeLibc = candidate.toolchain.libc;
        };
        opts = {
          cStandard = "gnu17";
          goOS = "linux";
          goArch = "amd64";
          reportedVersion = "go1.4-bootstrap-20170531";
          compiledRoot = "/tvp/go-bootstrap";
          cgo = false;
        };
      };
    })."20171003";
  versionTable = retained.versionTable // {
    "20171003" = retained.versionTable."20171003" // {
      def =
        if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
          definition
        else
          retained.versionTable."20171003".def;
    };
  };
  publicArgs = retained // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit package; }
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  pname = "go-bootstrap";
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

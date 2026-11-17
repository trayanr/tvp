{ pkgs, tvp }:
let
  pname = "jdk-bootstrap";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-21.0.13.nix;
        deps = {
          runtimeLibc = tvp.packages.glibc_2;
          runtimeCompiler = tvp.packages.gcc_16;
          zlib = tvp.packages.zlib_1;
          alsa = tvp.packages.alsa-lib_1;
          fontconfig = tvp.packages.fontconfig_2;
        };
        blob = {
          reason = "Explicit Temurin binary boot JDK for compiling the first owned OpenJDK source release.";
          needs = "A source Java bootstrap chain from a non-Java compiler seed.";
          blocked.package = "jdk-bootstrap-from-source";
        };
      };
      releases."21.0.13" = "sha256-1/XVz4ZaKQK3D/VJuXWGp9PyNOAW8EGrRH6nQMfWbRw=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${version}%2B9/OpenJDK21U-jdk_x64_linux_hotspot_${version}_9.tar.gz";
    };
    tests = (import ./tests/installed.nix);
    testDeps.fontArchive =
      let
        sourceFamily = (import ../jdk { inherit pkgs tvp; }).recipes.jdk;
      in
      tvp.lib.packages.tagSelection
        {
          namespace = "upstream-source-fixture";
          selector = "openjdk-21.0.13-ga-font";
          kind = "test-source";
          reason = "Pinned A.ttf fixture for the headless binary seed test; no source JDK build.";
        }
        (
          sourceFamily.source {
            version = "21.0.13";
            sha256 = sourceFamily.versionTable."21.0.13".sha256;
          }
        );
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.jdk-bootstrap = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ tvp, ... }:
let
  pname = "android-platform-tools";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          runtimeLibc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Exact earlier source-GNU host libc selected by the released SDK adapter; preserve this generation independently of public compiler aliases.";
          } tvp.bases.gcc_16.full.compiler.libc;
          runtimeCompiler = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Exact earlier source-GNU host compiler runtime selected by the released SDK adapter; preserve its overridable runtime-payload role.";
          } tvp.bases.gcc_16.full.compiler.cc;
          unzip = tvp.packages.unzip;
        };
        opts = {
          sourceLayout = {
            url = "https://dl.google.com/android/repository/platform-tools_r37.0.1-linux.zip";
          };
        };
        blob = {
          reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
          needs = "A source Android toolchain and component build graph.";
          blocked.package = "android-sdk-from-source";
        };
      };
      releases."37.0.1" = "sha256-0jDxOEL2D3gqhkX5yBP4+EW/NgiepyifKMSPF5eTE/E=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: versionTable.${version}.def.opts.sourceLayout.url;
      discovery = {
        type = "android-repository";
        scope = "Published SDK repository index; superseded revisions may be absent.";
        url = "https://dl.google.com/android/repository/repository2-3.xml";
        packagePrefix = "platform-tools";
      };
    };
    tests = import ./tests/installed.nix;
    testDeps = { };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."android-platform-tools" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

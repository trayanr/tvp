{ tvp, ... }:
let
  pname = "android-cli";
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

        };
        opts = {
          sourceLayout = {
            url = "https://dl.google.com/android/cli/1.1.16717390/linux_x86_64/android-cli";
          };
        };
        blob = {
          reason = "Pinned Android CLI executable; replaces the command-line tools launcher which otherwise downloads an unpinned latest binary.";
          needs = "A source build of Android CLI and its dependency graph.";
          blocked.package = "android-cli-from-source";
        };
      };
      releases."1.1.16717390" = "sha256-s07Quu7/oqruJyDYJJG5dYNWluLlaEBEkHi+yIVDZWQ=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: versionTable.${version}.def.opts.sourceLayout.url;
      discovery = {
        type = "directory-index";
        url = "https://developer.android.com/tools/agents/android-cli/release-notes";
        # Release-note headings retain the complete published version, including
        # the build number used by the immutable download URL.
        pattern = ''data-text="Version [0-9]+(\.[0-9]+)+ \([^"]+\)"'';
        normalise =
          heading:
          let
            match = builtins.match ''data-text="Version ([0-9]+(\.[0-9]+)+) \([^"]+\)"'' heading;
          in
          if match == null then null else builtins.head match;
      };
    };
    tests = import ./tests/installed.nix;
    testDeps = { };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."android-cli" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

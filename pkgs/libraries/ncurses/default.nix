{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "6.2" = {
      builder = ./build-6.0.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
    };

    # etip.h declares `throw()` on operator new, which C++17 removed and gcc 11
    # made the default dialect. 6.1 rewrote the header.
    "6.0" = {
      builder = ./build-6.0.nix;
      base = tvp.bases.gcc9;
      deps = {
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
    };

    # MKlib_gen.sh post-processes `gcc -E` output, and gcc 5 started emitting
    # extra #line markers into it. 6.0 detects that and adds -P.
    "5.8" = {
      builder = ./build-5.8.nix;
      base = tvp.bases.gcc49;
      deps = {
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
      opts = {
        hardeningDisable = [ "format" ];
      };
    };

    # 5.0 … 5.2 hard-code <strstream.h> in cursesw.h, from the pre-standard C++
    # library. 5.3 made the include conditional on HAVE_STRSTREAM_H.
    "5.0" = {
      builder = ./build-4.2.nix;
      base = tvp.bases.gcc49;
      deps = { };
      opts = {
        hardeningDisable = [ "format" ];
        cxxBinding = false;
      };
    };

    # configure clears CXX when `g++ --version` matches its `1*` template-support
    # blacklist, which every gcc from 10 onwards does.
    "4.2" = {
      builder = ./build-4.2.nix;
      base = tvp.bases.gcc49;
      deps = { };
      opts = {
        hardeningDisable = [ "format" ];
      };
    };
  };

  inherit (tvpLib.packages) merge mkTable;

  versionTable = merge {
    "4" = mkTable (import ./4.nix { inherit defs; });
    "5" = mkTable (import ./5.nix { inherit defs; });
    "6" = mkTable (import ./6.nix { inherit defs; });
  };

  pname = "ncurses";

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests =
        ncurses:
        import ./tests {
          inherit pkgs tvpLib ncurses;
        };
    };

    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://mirrors.kernel.org/gnu/ncurses/";
        pattern = "ncurses-[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "ncurses-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "ncurses-" file)
          else
            null;

        include = version: builtins.match "[0-9].*" version != null;
      };
    };
  };

in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

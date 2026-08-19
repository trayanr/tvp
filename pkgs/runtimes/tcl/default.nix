{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "9.0.0" = {
      builder = ./build-8.6.0.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1_3_2;
      };
      opts = {
        zipfsImage = false;
      };
    };

    "8.6.2" = {
      builder = ./build-8.6.0.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1_3_2;
      };
    };

    "8.0.2" = {
      builder = ./build-8.0.2.nix;
      base = tvp.bases.default;
      deps = { };
      opts = {
        reportedVersion = "8.0p2";
      };
      patches = [
        {
          file = ./patches/8.0.3-eopnotsupp-duplicate-case.patch;
          reason = "tclPosixStr.c gives ENOTSUP and EOPNOTSUPP separate case labels, and glibc later made them the same value, so the switch no longer compiles. This is upstream's own guard from 8.0.5 applied earlier.";
        }
      ];
    };

    "8.1.0" = {
      builder = ./build-8.0.2.nix;
      base = tvp.bases.default;
      deps = { };
      patches = [
        {
          file = ./patches/8.1.0-va-list-assignment.patch;
          reason = "Tcl_AppendResultVA assigns one va_list to another, which is an array type on x86_64 and does not compile. This is upstream's own memcpy from 8.1.1 applied one release earlier.";
        }
      ];
    };

    "8.0.3" = {
      builder = ./build-8.0.2.nix;
      base = tvp.bases.default;
      deps = { };
      patches = [
        {
          file = ./patches/8.0.3-eopnotsupp-duplicate-case.patch;
          reason = "tclPosixStr.c gives ENOTSUP and EOPNOTSUPP separate case labels, and glibc later made them the same value, so the switch no longer compiles. This is upstream's own guard from 8.0.5 applied two releases earlier.";
        }
      ];
    };

    "8.0.5" = {
      builder = ./build-8.0.2.nix;
      base = tvp.bases.default;
      deps = { };
    };

    "8.6.0" = {
      builder = ./build-8.6.0.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1_3_2;
      };
      opts = {
        pkgConfigVersion = "8.6";
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (
    import ./9.nix { inherit defs; } ++ import ./8.nix { inherit defs; }
  );

  pname = "tcl";

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests =
        tcl:
        import ./tests {
          inherit pkgs tvpLib tcl;
        };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://github.com/tcltk/tcl";

        # Releases are core-8-6-15; everything else in the namespace is a
        # development or merge tag.
        normalise =
          tag:
          if builtins.match "core-[0-9]+-[0-9]+-[0-9]+" tag != null then
            builtins.replaceStrings [ "-" ] [ "." ] (pkgs.lib.removePrefix "core-" tag)
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

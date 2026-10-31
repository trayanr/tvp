{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.12.5" = {
      builder = ./build-3.12.5.nix;
      base = tvp.bases.default;
      deps = {
        bash = tvp.packages.bash_5;
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/subprocess-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
      opts.disabledModules = [
        "_crypt"
        "_ctypes"
        "_curses"
        "_curses_panel"
        "_dbm"
        "_gdbm"
        "_sqlite3"
        "_tkinter"
        "_uuid"
        "nis"
        "readline"
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.12.5";
      releases."3.12.5" = "sha256-+oouEsXmILCfU+ZbzYdVDS5aHi4Ev4upkdzFUROHY5c=";
    }
  ];
  pname = "python-build";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;

        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };

  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

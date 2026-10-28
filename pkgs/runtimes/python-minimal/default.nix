{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.12.5" = {
      builder = ./build-3.12.5.nix;
      base = tvp.bases.default;
      deps = {
        bash = tvp.packages.bash_5_2_37;
      };
      patches = [
        {
          file = ./patches/subprocess-shell.patch;
          reason = "Store-layout adaptation: subprocess shell commands use the declared Bash instead of the host /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
      # This build interpreter intentionally omits third-party extension libraries.
      opts.disabledModules = [
        "_bz2"
        "_crypt"
        "_ctypes"
        "_curses"
        "_curses_panel"
        "_dbm"
        "_gdbm"
        "_hashlib"
        "_lzma"
        "_sqlite3"
        "_ssl"
        "_tkinter"
        "_uuid"
        "nis"
        "readline"
        "zlib"
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.12.5";
      releases."3.12.5" = "sha256-+oouEsXmILCfU+ZbzYdVDS5aHi4Ev4upkdzFUROHY5c=";
    }
  ];
  pname = "python-minimal";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }: package: import ./tests { inherit pkgs tvpLib package; }
    ) { inherit pkgs; };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

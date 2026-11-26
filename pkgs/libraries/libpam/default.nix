{ tvp, ... }:
let
  pname = "libpam";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          bison = tvp.packages.bison;
          flex = tvp.packages.flex;
          gdbm = tvp.packages.gdbm;
          gettext = tvp.packages.gettext;
          libxcrypt = tvp.packages.libxcrypt;
          meson = tvp.packages.meson;
          ninja = tvp.packages.ninja;
          openssl = tvp.packages.openssl_3;
        };
      };
      releases."1.7.3" = "sha256-LOR2X9Sd9mk3ce8pQfgeM9juFLlKgaXHs2mqOxN7haU=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/linux-pam/linux-pam/releases/download/v${version}/Linux-PAM-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/linux-pam/linux-pam";
        normalise =
          tag:
          if builtins.match "v[0-9]+\\.[0-9]+\\.[0-9]+" tag == null then
            null
          else
            builtins.substring 1 (builtins.stringLength tag) tag;
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libpam = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

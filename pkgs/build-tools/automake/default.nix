{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  base = tvp.bases.default;
  defs = tvpLib.packages.mkDefs {
    "1.2" = {
      builder = ./build-1.2.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_13;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.gz";
      opts.headerMacro = "AM_CONFIG_HEADER";
    };
    "1.5" = {
      builder = ./build-1.2.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.gz";
      opts.headerMacro = "AM_CONFIG_HEADER";
    };
    "1.6.3" = {
      builder = ./build-1.6.3.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.bz2";
      opts.headerMacro = "AM_CONFIG_HEADER";
    };
    "1.7.9" = {
      builder = ./build-1.6.3.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.bz2";
    };
    "1.10.3" = {
      builder = ./build-1.6.3.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.archiveExt = "tar.bz2";
    };
    "1.11.6" = {
      builder = ./build-1.6.3.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.installAclocalDir = true;
    };
    "1.12.6" = {
      builder = ./build-1.6.3.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.2";
      releases = {
        "1.2" = "sha256-5FEV79YJTx+5xhfk2E84af5yy76vrYhZVDC75RsHxbg=";
        "1.3" = "sha256-xqbrs4M11YqlAfp3P6SQQelRNbzOl3sZ78nxRWdAPWA=";
      };
    }
    {
      def = defs."1.5";
      releases = {
        "1.5" = "sha256-JLR3XjFD/T4121y6uoCEXZNZx7/XUabOvjAU+/YRXXg=";
      };
    }
    {
      def = defs."1.6.3";
      releases = {
        "1.6.3" = "sha256-Dbr6yvIeE1yrNdNXoUvc2YHS8tAOE4eAG+gJGjG3u4E=";
      };
    }
    {
      def = defs."1.7.9";
      releases = {
        "1.7.9" = "sha256-MsE7atOO1ee/0XVsvBnPXv1nt63i0GAApMmbDOlL1G0=";
        "1.8.5" = "sha256-hMk6qjw2UannR0tyGw5niDGFklCefeYEuv5OqASdxBA=";
        "1.9.6" = "sha256-jsyqmOGGPRDkpfhh2OLsNJoj6IyxKtEPa295AirSu40=";
      };
    }
    {
      def = defs."1.10.3";
      releases = {
        "1.10.3" = "sha256-6Yq0O7g5wxaWpCAuW2/ziLORZZ7yOHz5NlAZ+tF+Gtw=";
      };
    }
    {
      def = defs."1.11.6";
      releases = {
        "1.11.6" = "sha256-H/vGzEHw6myGT76UhbmBZ53F41D2xLxsNRL1pCJpNrU=";
      };
    }
    {
      def = defs."1.12.6";
      releases = {
        "1.12.6" = "sha256-+DSrIUWx7iS9hTh5UARPXLQY3QryuExS5gwr8pFi2/o=";
        "1.13.4" = "sha256-ic5JM/WbjwwgEVw5z+RQpZXMp07eJ7aIHojsJ3INHWY=";
        "1.14.1" = "sha256-qbTwS4tpysLoMqOKcYlDqpdtva0AlyEfizRIr9rPBmk=";
        "1.15.1" = "sha256-r2ujkUIiBofFAPebSqLxgdmyTk+NjsSXzqS6JsZL7a8=";
        "1.16.5" = "sha256-8B1YzW2dd/vcqetLvV6tGYgij9tz1veiAfX41rEYtGk=";
        "1.17" = "sha256-iSDB/EEeE7kL9wTvnbbynVQOdtIyyzssn03EzFmb2ZA=";
        "1.18.1" = "sha256-FoqjYyeDUbia9WaERI9SWlvOUHnQtoQr2RD90/FkaIc=";
        "1.19" = "sha256-4+LC46vzeJgTjbW2wdHcNckWDFl4vnlH0sdBcFJR1EU=";
      };
    }
  ];
  pname = "automake";
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
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/automake/";
      pattern = "automake-[0-9][^\"]*\\.tar\\.gz";
      normalise =
        file:
        if pkgs.lib.hasPrefix "automake-" file && pkgs.lib.hasSuffix ".tar.gz" file then
          pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "automake-" file)
        else
          null;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*(-p[0-9]+)?" version != null;
    };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

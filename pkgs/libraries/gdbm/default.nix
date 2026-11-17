{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.7.3.nix;
        deps.file = tvp.packages.file;
        patches = [
          {
            file = ./patches/1.7.3-install-compat-unbalanced-paren.patch;
            reason = "install-compat writes 100 1 26 57 100 131 989 991srcdir/ndbm.h — an unbalanced paren make expands to nothing, so the target installs no ndbm.h at all.";
          }
        ];
      };
      status = {
        level = "degraded";
        capability = "shared";
        reason = "Static library only. This release predates libtool in gdbm; `all` builds libgdbm.a and there is no shared-library rule to install.";
        needs = "The libtool build upstream first shipped at 1.8.0.";
      };
      releases = {
        "1.7.3" = "sha256-gcBuiEc9aw/SI7nCf+c7u8yB3NT5OLmtzfX/K5m73no=";
      };
    }
    {
      def = {
        builder = ./build-1.8.0.nix;
        deps.file = tvp.packages.file;
        patches = [
          {
            file = ./patches/1.8.0-config-sub-x86_64.patch;
            reason = "The shipped config.sub predates x86_64; accept its native CPU spelling without changing libtool's Linux rules.";
          }
        ];
      };
      releases = {
        "1.8.0" = "sha256-S8jhb/4n+nF7Y1LPr0eiZbIG36nhhhZlZKcotzOP9xk=";
      };
    }
    {
      def = {
        builder = ./build-1.8.1.nix;
        deps.file = tvp.packages.file;
        opts = {
          configureHost = true;
          roundtrip = false;
          finalizerControls = false;
          sourceLayout = {
            selections = [
              "configure"
              "config.sub"
              "config.guess"
              "install-sh"
              "mkinstalldirs"
              "ltmain.sh"
            ];
            libtoolAnchors = {
              "ltmain.sh" = 1;
            };
            edits = [
              {
                path = "Makefile.in";
                before = " -o $(BINOWN) -g $(BINGRP)";
                after = "";
                count = 5;
              }
            ];
          };
        };
      };
      releases = {
        "1.8.1" = {
          sha256 = "sha256-VqMk/7VJSuFqKwoEqAa4IWk3E4ZcPbHjIAmzbdB2WBE=";
          status = {
            level = "degraded";
            knownTestFailures = [
              "store"
              "ndbm"
            ];
            reason = "gdbm_open returns a handle in reader mode whatever mode is asked for, so every write fails with GDBM_READER_CANT_STORE. Measured against GDBM_NEWDB and GDBM_WRCREAT; 1.8.0 and 1.8.2 both write.";
            needs = "Nothing TVP can supply. Upstream shipped 1.8.2 the following day.";
          };
        };
      };
    }
    {
      def = {
        builder = ./build-1.8.1.nix;
        deps.file = tvp.packages.file;
      };
      releases = {
        "1.8.2" = "sha256-DVr8LcDBTLo5Y2PMFeHKeFOoXV2Z6rW2tKnq95llImk=";
        "1.8.3" = "sha256-zDQDOKLii0AFirnrU1SiHVP4ihWC6iG6C7GFw3ooHck=";
      };
    }
    {
      def = {
        builder = ./build-1.9.nix;
        deps.file = tvp.packages.file;
        opts = {
          touchTestsuite = true;
        };
      };
      releases = {
        "1.9" = "sha256-+FMk1943d9sWdYH9XTST0tqj6F4ZWorpr8BbNFUbblc=";
        "1.9.1" = "sha256-YCWFJjd3KwaZ8ilLXxT9SghLyjyBYdKdZNHzDW0amu0=";
      };
    }
    {
      def = {
        builder = ./build-1.9.nix;
        deps.file = tvp.packages.file;
      };
      releases = {
        "1.10" = "sha256-I/gTTFuUu/sG11amt48HT7puYCjPL+ATQdQLJtt3NEE=";
      };
    }
    {
      def = {
        builder = ./build-1.9.nix;
        deps.file = tvp.packages.file;
        opts = {
          cStandard = "gnu89";
          commonSymbols = true;
          sourceLayout = {
            selections = [
              "configure"
              "build-aux"
            ];
            shellFragments = {
              "build-aux/ltmain.sh" = [ "" ];
            };
            libtoolAnchors = {
              "build-aux/ltmain.sh" = 1;
            };
          };
        };
      };
      releases = {
        "1.11" = "sha256-jZEvRPBdCxWkpdlqdvhS6QXQUbuIAi/N/Zi0O+CT48M=";
        "1.12" = "sha256-2XshZu6Gf9bKXAIu/ugHAtbzDdZq8OA+0JIoXDr5vOo=";
        "1.13" = "sha256-nSUsvX15P3sSvM6t3amNJXwU9NGJDYUcOGw3IHAAolM=";
        "1.14" = "sha256-raFDekFlpwez6fN7W3Tbvnwvi95jO4wsfbyPhPObqgk=";
        "1.14.1" = "sha256-zc7/AP/gFElb7TrtcceRCqiL8pN595WrwPRtTuX4vF8=";
        "1.15" = "sha256-+f3jIH9n7YpaXd2K1ees97J8LPDyDfvd6Hbc1uPS3A4=";
        "1.16" = "sha256-yKGLxiWdoMPu/vsBj4qimP3cb4bG/A8N7HMnCJarUS8=";
        "1.17" = "sha256-fNjMLjWxqu3mCE6lfMlEd1L0mNquqFQQCkutVnYUl30=";
        "1.18" = "sha256-uIIstHaeLXWcgowG8ZZhSTbIjBQcMTKxglL+JcK2Nc4=";
        "1.18.1" = "sha256-huYTUn5dulROcyCPQreLfAItT6Wm1UmL8YyNb3Rbkdw=";
      };
    }
    {
      def = {
        builder = ./build-1.9.nix;
        deps.file = tvp.packages.file;
        opts = {
          cStandard = "gnu17";
          sourceLayout = {
            selections = [
              "configure"
              "build-aux"
            ];
            shellFragments = { };
            libtoolAnchors = {
              "build-aux/ltmain.sh" = 1;
            };
          };
        };
      };
      releases = {
        "1.19" = "sha256-N+0SIUEiuXLhig2UmVA55XdIGRk573QRWx1B2IETZLw=";
        "1.20" = "sha256-OurAVkizSCoQotqYa586OAoprWUL6AuYF6Q1+4EUopI=";
        "1.21" = "sha256-sLfb3v15jefdzN2O32aTowSU93iXd4OAQpke8QcznMI=";
        "1.22" = "sha256-82bII6ZySvMTtrvpdbKAn5oVfl9qQ2EqcpSRONFh12I=";
        "1.23" = "sha256-dLEIHSH/8TrkvXwW5dblBKTCb3zeHcoNljpIQXS7ys0=";
        "1.24" = "sha256-aV6YJ/33Y1E/EzkQvH5s/bkYeUOk/slD5XRJcj0rjb8=";
      };
    }
    {
      def = {
        builder = ./build-1.9.nix;
        deps.file = tvp.packages.file;
        opts = {
          sourceLayout = {
            selections = [
              "configure"
              "build-aux"
            ];
            shellFragments = { };
            libtoolAnchors = {
              "build-aux/ltmain.sh" = 1;
            };
          };
        };
      };
      releases = {
        "1.25" = "sha256-0C2zxZJu2Hf4gXuBzR+S9T73TKjG21Q/u6AnGzTzk+w=";
      };
    }
    {
      def = {
        builder = ./build-1.26.nix;
      };
      releases = {
        "1.26" = "sha256-aiRQShTeSnRBA9y5Nr6Xbfb76IzP8mBl5UwcR5RvSl4=";
      };
    }
  ];
  pname = "gdbm";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;

    source = tvp.lib.sources.archive {
      url = version: "https://mirrors.kernel.org/gnu/gdbm/gdbm-${version}.tar.gz";
      fetch =
        { version, sha256 }:
        pkgs.fetchurl {
          urls = [
            "https://mirrors.kernel.org/gnu/gdbm/gdbm-${version}.tar.gz"
            "https://ftp.gnu.org/gnu/gdbm/gdbm-${version}.tar.gz"
          ];
          inherit sha256;
        };
      discovery = {
        type = "directory-index";
        url = "https://mirrors.kernel.org/gnu/gdbm/";
        pattern = "gdbm-[0-9][^\"]*\\.tar\\.gz";

        normalise = tvp.lib.versions.fromArchiveName {
          prefix = "gdbm-";
          suffixes = [ ".tar.gz" ];
        };

        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(pkgs.lib.hasInfix "alpha" version || pkgs.lib.hasInfix "beta" version);
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.gdbm = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

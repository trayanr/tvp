{ pkgs, tvp }:
let
  # Captured earlier Perl is a preparation role, not an ordinary runtime dependency.
  preparationPerl = tvp.lib.packages.withConstraint {
    category = "construction";
    reason = "Retained source-GNU perl is an explicit build-only host generation, independent of these target libraries and commands.";
  } (import ../../../bases/source-gnu { }).tools.perl;
  pname = "ncurses";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-4.2.nix;
        deps.gnu-config = tvp.packages.gnu-config;
        deps.perl = preparationPerl;
      };
      releases = {
        "4.2" = "sha256-sW1GX3BpftY3VWv/pRD2u65LMVru9UPHfdHrs5o8znw=";
      };
    }
    {
      def = {
        builder = ./build-owned-4.2.nix;
        deps.gnu-config = tvp.packages.gnu-config;
        opts.cxxBinding = false;
        deps.perl = preparationPerl;
      };
      status = {
        level = "degraded";
        capability = "cxx";
        reason = "The C++ binding is not built; libncurses++ and its headers are absent.";
        needs = "A C++ library shipping <strstream.h>, which no compiler since gcc 2.95 provides. 5.3 stopped requiring it.";
        blocked = {
          base = "gcc<=2.95";
        };
      };
      releases = {
        "5.0" = "sha256-pYu8/SpP2CsmCc89cA0ZM99hQNrUW0r4P9xdI6YcKd8=";
        "5.1" = "sha256-2FXO0nG47MBUzx16XZeTqDlEMFvQBpsqfsvtZu4DGYA=";
        "5.2" = "sha256-fRh7v3B7Yn7q6hC/EbctXngdespZEOFgLG9jI7ckq4Q=";
      };
    }
    {
      def = {
        builder = ./build-owned-4.2.nix;
        deps.gnu-config = tvp.packages.gnu-config;
        # The historical install rule marks the static C++ archive executable.
        opts.normalizeCxxArchiveMode = true;
        patches = [
          {
            file = ./patches/const-user-getters-5.3.patch;
            reason = "Preserve const UserData observational getters with the selected compiler; retain the existing source repair.";
          }
        ];
        deps.perl = preparationPerl;
      };
      releases = {
        "5.3" = "sha256-bKyXPdMfnnpQXkX/qbuCz6a0H4S0gy/XdeFYV+6bNdQ=";
        "5.4" = "sha256-WrzgY89DF5D05qgBqWx+6gszpB7NCXD2MS9SV1wIOzY=";
      };
    }
    {
      def = {
        builder = ./build-owned-4.2.nix;
        deps.gnu-config = tvp.packages.gnu-config;
        opts.normalizeCxxArchiveMode = true;
        patches = [
          {
            file = ./patches/const-user-getters-5.5.patch;
            reason = "Preserve const UserData observational getters with the selected compiler; retain the existing source repair.";
          }
        ];
        deps.perl = preparationPerl;
      };
      releases = {
        "5.5" = "sha256-J6Y/OirJ0Twe2aCjPuRJfBmmtYELj5c452VKDhIiW5M=";
        "5.6" = "sha256-+crCsxaDo31lvDcRlZl1IZigaR5GLQ0aJSz5gV9XJNU=";
      };
    }
    {
      def = {
        builder = ./build-owned-4.2.nix;
        deps.gnu-config = tvp.packages.gnu-config;
        patches = [
          {
            file = ./patches/const-user-getters-5.5.patch;
            reason = "Preserve const UserData observational getters with the selected compiler; retain the existing source repair.";
          }
        ];
        deps.perl = preparationPerl;
      };
      releases = {
        "5.7" = "sha256-Cpvepcfeje1ckyftZCkV8sw4B1PxLUrRIO99o+o0mPQ=";
      };
    }
    {
      def = {
        builder = ./build-owned-5.8.nix;
        patches = [
          {
            file = ./patches/const-user-getters-5.5.patch;
            reason = "Preserve const UserData observational getters with the selected compiler; retain the existing source repair.";
          }
        ];
        deps.perl = preparationPerl;
      };
      releases = {
        "5.8" = "sha256-UVl/if1TqpkDIZVOM+W0hpxKXuYTe/qAD5j5HUtrVLU=";
        "5.9" = "sha256-kEYpj7RAMkydQTXs6nh5/+2FRt0bWOWUMOoHpGM/Vjs=";
      };
    }
    {
      def = {
        builder = ./build-owned-6.0.nix;
        deps.perl = preparationPerl;
      };
      releases = {
        "6.0" = "sha256-9VHCSzDOi/tultn1m0L76jD6OmEjOEFy+ecoS89kcmA=";
        "6.1" = "sha256-qgV+7rShTUcBAe/0WX1YM9zvWWUzG+NSjAjZnOuqDRc=";
      };
    }
    {
      def = {
        builder = ./build-owned-6.0.nix;
        opts.cxxStandard = null;
        deps.perl = preparationPerl;
      };
      releases = {
        "6.2" = "sha256-MDBuDHbg+fHw3ph88cgqXCHhzmVouSJ/faW3HL6obJ0=";
        "6.3" = "sha256-l/xRrCsIXUzeMe9NLDEiwhq8IX6QkKQ6MPxewhaE4Fk=";
        "6.4" = "sha256-aTEoPZrIfFBz8wtikMTHXyFjK7T8NgOsgQCBK+0kgVk=";
        "6.5" = "sha256-E22RvCaamleF5fnpgLx2q1dCj2BM4+WlqQzrx2eXHMY=";
      };
    }
    {
      def = {
        builder = ./build-owned-6.6.nix;
        deps.perl = preparationPerl;
      };
      releases = {
        "6.6" = "sha256-NVtMu+2ICwOBoExGYXt2VuNiWF1S6c+Epn4gCbdJ/xE=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;

    source = tvp.lib.sources.archive {
      url = version: "https://mirrors.kernel.org/gnu/ncurses/ncurses-${version}.tar.gz";
      fetch =
        { version, sha256 }:
        tvp.lib.sources.fetchMirrors {
          certificates = tvp.packages.ca-certificates;
          urls = [
            "https://mirrors.kernel.org/gnu/ncurses/ncurses-${version}.tar.gz"
            "https://ftp.gnu.org/gnu/ncurses/ncurses-${version}.tar.gz"
          ];
          inherit sha256;
        };
      discovery = {
        type = "directory-index";
        url = "https://mirrors.kernel.org/gnu/ncurses/";
        pattern = "ncurses-[0-9][^\"]*\\.tar\\.gz";

        normalise = tvp.lib.versions.fromArchiveName {
          prefix = "ncurses-";
          suffixes = [ ".tar.gz" ];
        };

        include = version: builtins.match "[0-9].*" version != null;
      };
    };
    tests = import ./tests/installed.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.ncurses = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases {
    inherit pname versionTable canonical;
    lines = [ "6_4" ];
  };
}

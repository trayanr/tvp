{ pkgs, tvp }:
let
  retained = import ./retained-construction.nix { inherit pkgs tvp; };
  # Captured earlier Perl is a preparation role, not an ordinary runtime dependency.
  retainedPreparationPerl = tvp.lib.packages.withConstraint {
    category = "construction";
    reason = "Retained source-GNU perl is an explicit build-only host generation, independent of these target libraries and commands.";
  } (import ../../../bases/source-gnu { }).tools.perl;
  pname = "readline";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-2.1.nix;
        deps.ncurses = tvp.packages.ncurses_6;
        opts.commonSymbols = true;
        deps.perl = retainedPreparationPerl;
      };
      status = {
        level = "degraded";
        capability = "shared";
        reason = "Static libraries only. These releases predate support/shobj-conf and link shared objects with a SunOS-era `ld -assert pure-text` invocation that modern binutils rejects; 2.0 and 2.1 carry no install-shared target at all.";
        needs = "A shared-library rule that works against ELF, which upstream first shipped at 4.0, or a period linker that accepts the rule these releases have.";
        blocked = {
          base = "period-linker";
        };
      };
      releases = {
        "2.1" = "sha256-vZhE8r2ZBBbNjTskCB1tPGd2/nlQYwYU12iJ8iJCv70=";
      };
    }
    {
      def = {
        builder = ./build-owned-2.1.nix;
        deps.ncurses = tvp.packages.ncurses_6;
        patches = [
          {
            file = ./patches/2.2-install-clobbers-libreadline.patch;
            reason = "Preserve libreadline.a while installing libhistory.a; fixed upstream in 2.2.1.";
          }
        ];
        deps.perl = retainedPreparationPerl;
      };
      status = {
        level = "degraded";
        capability = "shared";
        reason = "Static libraries only. This release predates support/shobj-conf and links shared objects with a SunOS-era `ld -assert pure-text` invocation that modern binutils rejects.";
        needs = "A shared-library rule that works against ELF, which upstream first shipped at 4.0, or a period linker that accepts the rule this release has.";
        blocked = {
          base = "period-linker";
        };
      };
      releases = {
        "2.2" = "sha256-eErtGTfKrHRqpLiGoMorou8tMRlCCv3iS6pWvHDAbZQ=";
      };
    }
    {
      def = {
        builder = ./build-owned-2.1.nix;
        deps.ncurses = tvp.packages.ncurses_6;
        deps.perl = retainedPreparationPerl;
      };
      status = {
        level = "degraded";
        capability = "shared";
        reason = "Static libraries only. These releases predate support/shobj-conf and link shared objects with a SunOS-era `ld -assert pure-text` invocation that modern binutils rejects; 2.0 and 2.1 carry no install-shared target at all.";
        needs = "A shared-library rule that works against ELF, which upstream first shipped at 4.0, or a period linker that accepts the rule these releases have.";
        blocked = {
          base = "period-linker";
        };
      };
      releases = {
        "2.2.1" = "sha256-GBmwBUI7eOaHZlN4H+WdmyLtElWGe3NtlckeUpp7Gns=";
      };
    }
    {
      def = {
        builder = ./build-owned-4.0.nix;
        deps.ncurses = tvp.packages.ncurses_6;
        deps.automake = tvp.packages.automake_1;
        deps.perl = retainedPreparationPerl;
      };
      releases = {
        "4.0" = "sha256-9Tt2z2sld7EbcOFJDycyH+LWdB40YVxFE0JMCYPY7Ss=";
        "4.1" = "sha256-8bPPCD5/V+t9pfblOVy4rF0O0IsHUXzyhL6qGSq2S6Q=";
        "4.2" = "sha256-9NmiMED9JrN63tuMB+cZpc60btb9aHqExOf5SRyyOHI=";
        "4.2a" = "sha256-pQZJuTGODJVV941A9wGnjrd1LhkPC2cHu4CknXX+l/c=";
      };
    }
    {
      def = {
        builder = ./build-owned-4.3.nix;
        deps.ncurses = tvp.packages.ncurses_6;
        deps.perl = retainedPreparationPerl;
      };
      releases = {
        "4.3" = "sha256-7q9vBQufUVsGNuW08sFT+e946QYe5d109hL6tUx3v4g=";
      };
    }
    {
      def = {
        builder = ./build-owned-4.3.nix;
        deps.ncurses = tvp.packages.ncurses_6;
        deps.perl = retainedPreparationPerl;
      };
      releases = {
        "5.0" = "sha256-0Z5Pgg2mU7lCYrDlze2kX0dMLXs3ioWkua6q52JpphE=";
        "5.1" = "sha256-Fj7GQH7HWnCckHdlex/KkxTMdJmdV9HDWrGFcCuwZ8Y=";
        "5.2" = "sha256-EuiNlq7izRGSUANW8FNVQNtJkoLKf3Yzn7QijDEkn0U=";
      };
    }
    {
      def = {
        builder = ./build-owned-6.0.nix;
        deps.ncurses = tvp.packages.ncurses_6;
        deps.perl = retainedPreparationPerl;
      };
      releases = {
        "6.0" = "sha256-EZnZBcAlc1s0z2fQMHhYXhj4RwcFJBMnn+aM5Iwcwd4=";
        "6.1" = "sha256-8Mr2CMBszW1Ws77hhDRY1QnFP5tT3//+B8wR2PA/qWk=";
        "6.2" = "sha256-eaaWBwoFjCM8ct1qxpcCHMZKvV7VHlnbhn1m0Zaok4E=";
        "6.3" = "sha256-VrpgcblGL5gMWnKrACOJO2W6beu07rR116Vj3GXK/UM=";
      };
    }
    {
      def = {
        builder = ./build-owned-6.0.nix;
        deps.ncurses = tvp.packages.ncurses_6;
        deps.perl = retainedPreparationPerl;
      };
      releases = {
        "7.0" = "sha256-dQ1DcYUob0CjaeHk9HZO2pMrlFm17JpzFig5PdPTIzQ=";
      };
    }
    {
      def = {
        builder = ./build-owned-6.0.nix;
        deps.ncurses = tvp.packages.ncurses_6;
        opts.pkgConfigModules = [ "readline" ];
        deps.perl = retainedPreparationPerl;
      };
      releases = {
        "8.0" = "sha256-4zn1GXFHjTafigU6MwoZB4GsuYZM9MVBBg8SB4lI5GE=";
        "8.1" = "sha256-+M607hMeMjIiahf1GxZK/EbNC55s7zRL6Hxlliy4KwI=";
        "8.1.2" = "sha256-dYmiOBqEGeaGVKR2I859/LdWgVyP7nJrmPkL9mive8Y=";
      };
    }
    {
      def = {
        builder = ./build-owned-6.0.nix;
        deps.ncurses = tvp.packages.ncurses_6;
        opts.pkgConfigModules = [
          "readline"
          "history"
        ];
        deps.perl = retainedPreparationPerl;
      };
      releases = {
        "8.2" = "sha256-P+txcfFqhO6CyhijbXub4QmlLAT0kqBTMx19EJUAfDU=";
        "8.2.13" = "sha256-Dlvk0pN+i9m3zWDUZyHOefiKM0Fd1owtc4+1kkY49lY=";
      };
    }
    {
      def = {
        builder = ./build-owned-8.3.nix;
        deps.ncurses = tvp.packages.ncurses_6;
        deps.perl = retainedPreparationPerl;
      };
      releases = {
        "8.3" = "sha256-/lODIERngozUle6NHTwDen66E4nCK8agQfYnl2+QYcw=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta = retained.packageMeta;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/readline/readline-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/readline/readline-${version}.tar.gz"
        ];
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
  };
  # The established broken exclusion is neither ported nor instantiated by mkFamily.
  brokenTable = {
    "2.0" = retained.versionTable."2.0";
  };
  excluded = tvp.lib.packages.mkVersions (retained // { versionTable = brokenTable; });
  canonical = tvp.lib.packages.mkVersions family // excluded;
  allVersions = family.versionTable // brokenTable;
  variants = tvp.lib.packages.mkVariants (
    family
    // {
      inherit pkgs;
      versionTable = {
        "8.3" = family.versionTable."8.3";
      };
      profiles.ncurses64.base = family.versionTable."8.3".def.base;
      profiles.ncurses64.versions."8.3" = {
        deps.ncurses =
          tvp.lib.packages.withConstraint
            {
              reason = "Named ncurses64 profile preserves its documented Ncurses 6.4 public WINDOW/header contract; ordinary canonical Readline follows the current ABI line.";
            }
            (tvp.lib.packages.mkVersions
              (import ../ncurses { inherit pkgs tvp; }).recipes.ncurses.constructionRecipe
            ).ncurses_6_4;
        opts.installedInterface = {
          static = true;
          propagateNcurses = true;
        };
      };
    }
  );
in
{
  recipes.readline = family // {
    versionTable = allVersions;
    constructionRecipe = retained;
  };
  inherit canonical variants;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases {
    inherit pname canonical;
    versionTable = allVersions;
    lines = [ "6_2" ];
  };
}

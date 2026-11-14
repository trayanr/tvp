{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-2.10.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.packages.perl_5;
        };
        opts.modernInit = false;
      };
      releases = {
        "2.10" = "sha256-9PYB1+RVjW3JD+XsxP4VmfFfoOcxfAr7g/dUHPA6Th4=";
        "2.11" = "sha256-5ofbdqZLWvtcSXrCEROKvEL6xy7/Gwhzi0ir5MrJy6I=";
      };
    }
    {
      def = {
        builder = ./build-2.10.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.packages.perl_5;
        };
        opts.modernInit = false;
        # AC_PROG_CC_WORKS emits implicit-int main(), requiring C89.
        opts.consumerCStandard = "gnu89";
      };
      releases = {
        "2.12" = "sha256-Zv3kdOEk6AyENWAEHNaIIMnc5W5pbziDErowNhqBShY=";
        "2.13" = "sha256-8GERNr7lBYEenKEcp6wYjvUyOo4u8Zz/0+2zzwj9eR4=";
      };
    }
    {
      def = {
        builder = ./build-2.10.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.packages.perl_5;
        };
      };
      releases = {
        "2.50" = "sha256-JqECa7ZMvsosSJnzUj8lUW9z1390jzrHlSP9ULZAOkM=";
        "2.52" = "sha256-U06ZthuB55MnttCPGj7bB1WsJG4SSQCbDhv1iHtg16k=";
      };
    }
    {
      def = {
        builder = ./build-2.10.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.lib.packages.withConstraint {
            reason = "autom4te uses do on relative autom4te.cache/requests; Perl 5.26 removes dot from @INC. Native 2.53 passes with 5.24 and fails with 5.28; Autoconf 2.58 replaces this lookup with read/eval.";
          } tvp.packages.perl_5_24;
        };
      };
      releases = {
        "2.53" = "sha256-PFnFyggnm5n7bbrg7UDFdNQ1tTe2xtLEWVOe7DXYIgk=";
        "2.54" = "sha256-wCIZ8B9AWm/m5rczBPt1yc9wR0daTSAZhJbQsvw4TLk=";
        "2.55" = "sha256-yx6n2bfPjcwj/tSKmcE4Xt/bPmOK2pvNUnQWaZQ8Liw=";
        "2.56" = "sha256-OnOh14jCYE7o0IKEB86Rg/la1GgByqMaDdUyrc2aPSw=";
        "2.57" = "sha256-BjRjR3kFAJvZD2zHjkUTuVnoS/kpLzX+QIXgCBaljjQ=";
      };
    }
    {
      def = {
        builder = ./build-2.10.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.packages.perl_5;
        };
      };
      releases = {
        "2.58" = "sha256-UixOakPVPy8nj3g3+dpuh7XXhSkMDh7Vh0QqkDAmAiY=";
        "2.59" = "sha256-nNBcc8X8sfXMrlPdbKw2u4y5x7Ppf/rlp8BccllMiNg=";
        "2.60" = "sha256-C+911wr/8onQ4f43jWqh15swMstMr0hFeKwqigUwo68=";
        "2.61" = "sha256-nRTy7Q0bb4GASYpmUX9RHHxJyHDWhzIZo/9LizCCpos=";
        "2.62" = "sha256-g6p0fmRD3vDr0YglCcU/WiEz9QLd76IbPeFBxDORS90=";
        "2.63" = "sha256-sFps7oFlfdLbhhlKYjK4lbiyYGowo5nDpWbZJZNmdEs=";
        "2.64" = "sha256-qERxcz+GrCwSQKbSi3BbBaa3nDzKiDXDcS7734E8XrY=";
      };
    }
    {
      def = {
        builder = ./build-2.65.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.packages.perl_5;
        };
      };
      releases = {
        "2.65" = "sha256-87G6O/NyJQnnIiPyCttj957Q0gsBFq4s0ewMH3MI3bU=";
        "2.66" = "sha256-MCzk/SjvOf2mULnQbP5WiuRrLQtOCkmC3FF1eTfJNbs=";
        "2.67" = "sha256-JrdSxCdkctOyH6Kmz9+0lX451dYQik9AILEyNP+6ZtE=";
        "2.68" = "sha256-7/cKKRby4rPtf+ii1+Y9cs86I2hLVkVrMZw+vOBwXZk=";
        "2.69" = "sha256-lUvWmzke3BLWpKUaLdFHZUPaXGu/BalbWdwN1v1MKWk=";
        "2.70" = "sha256-8F9BD9p0MjraS9xGENs3+NvVVmArplvIQ+201NShsrc=";
        "2.71" = "sha256-QxB1rQv1Ke8Ty0HpBCxUI4EQPoABVoYiK4qdSr70Khw=";

      };
    }
    {
      def = {
        builder = ./build-2.65.nix;
        deps = {
          m4 = tvp.packages.m4;
          perl = tvp.packages.perl_5;
        };
        # The autoconf frontend switches to Perl; the procedure is unchanged.
        opts.autoconfFrontend = "perl";
      };
      releases = {
        "2.72" = "sha256-r7GBp24e5ygy9lgcDt343wMrg+LgI573nr7cRGfZLW4=";
        "2.73" = "sha256-JZ3fo73ceZz7gUicwPF9/fG9bRUF3aU8D0X/YNak+ac=";
      };
    }
  ];
  pname = "autoconf";
  retained = import ./retained { inherit pkgs tvp; };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    inherit (retained) packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/autoconf/autoconf-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
    testDeps = {
      automake = tvp.packages.automake_1;
      libtool = tvp.packages.libtool_2;
      alternatePerl = (import ../../../bases/source-gnu { }).tools.perl;
      alternateM4 = (import ../../../bases/source-gnu { }).tools.m4;
      runtimeShell = tvp.packages.bash_5;
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.autoconf = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases {
    lines = [ "2_13" ];
    inherit pname versionTable canonical;
  };
}

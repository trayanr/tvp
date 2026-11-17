{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-8.0.2.nix;
        opts = {
          installedInterface = {
            reportedVersion = "8.0p2";
          };
        };
        patches = [
          {
            file = ./patches/8.0.3-eopnotsupp-duplicate-case.patch;
            reason = "tclPosixStr.c gives ENOTSUP and EOPNOTSUPP separate case labels, and glibc later made them the same value, so the switch no longer compiles. This is upstream's own guard from 8.0.5 applied earlier.";
          }
        ];
      };
      releases = {
        "8.0.2" = "sha256-8nPQlCeRXJG2j4ukBQnzk70RfJZBYKpz0aS9q2lLS54=";
      };
    }
    {
      def = {
        builder = ./build-8.0.2.nix;
        patches = [
          {
            file = ./patches/8.0.3-eopnotsupp-duplicate-case.patch;
            reason = "tclPosixStr.c gives ENOTSUP and EOPNOTSUPP separate case labels, and glibc later made them the same value, so the switch no longer compiles. This is upstream's own guard from 8.0.5 applied two releases earlier.";
          }
        ];
      };
      releases = {
        "8.0.3" = "sha256-Vvii/yXpZlTYvlxAqmoYJKgeAyGO4hRKzmvMpzdwWKM=";
        "8.0.4" = "sha256-2imuap0hQ5D3OqirUbBmtBkttOntwIqXb0DD88MEp9c=";
      };
    }
    {
      def = {
        builder = ./build-8.0.2.nix;
      };
      releases = {
        "8.0.5" = "sha256-BAK+UakozBWRBJsC4yVlq8zk9MBvN7j+0PJXPuFrR54=";
        "8.1.1" = "sha256-jSx63Dr4/xeHz7hudAwkCR1HYRE+Cq6m4MBul67oUxQ=";
        "8.2.0" = "sha256-EfF6smgolyYgDFYcBbI8x05X8GyFq73orEgIN07q32c=";
        "8.2.1" = "sha256-46y4bteQNgYNI1jHoSBSXQdNZEPzFVlZ2Vw5cu6KsIs=";
        "8.2.2" = "sha256-IGm5ftB/UvKiYfLztvBfHIl0q/mKELqGFXWcGcwuQbo=";
        "8.2.3" = "sha256-4NNU54SksSkkShPHnWeLSBfVEE5ctPnBPYdHCszGdPs=";
        "8.3.0" = "sha256-y2sjoQI9W3XwhpTevzsEmPpZZsNoVTlL9qqTUed9V4o=";
        "8.3.1" = "sha256-6+WXBwSvQyQ0HyHCcOXYrxznGPA3jSi6cjDQpr3wFG8=";
        "8.3.2" = "sha256-a2wY9mqdkCNPW6GxH+YrNo6h4l5XDwuQEmF9E7gx+Lo=";
        "8.3.3" = "sha256-M6jlEtI6ZhMYolu+BVyM1pwWpjunribnJBoGovr3mAg=";
        "8.3.4" = "sha256-Qovze0v+KgVr7o9EOK7GMKpvWFq+Pk6r1lXIB/0Ls0E=";
        "8.3.5" = "sha256-UT1Lgk2lUbSS2O5SmxDYdaLQYQxzlya8aM2etwaLoP4=";
        "8.4.0" = "sha256-l21fW2ZHb9SEHezBPZwfQkEoeX+gm1H89Ad2fPHbbHY=";
        "8.4.1" = "sha256-x+dajEpEUGSO5FMJZfpMgLVTgNCgl2An0t8zWLsKly0=";
        "8.4.2" = "sha256-jFgHdOwBC++3n38FFzguyzNpOBgE2kZInmx6PC689So=";
        "8.4.3" = "sha256-3j2qSognH7UKx1h+kKcRX5+Tp/cSp9063CPFYWVALog=";
        "8.4.4" = "sha256-qehK5+M6rWchRR+y9P0zdYifV7XYrQsNRxMn+DobFLw=";
        "8.4.5" = "sha256-kPBo3FpbzYJUuoPaa+DiRMN5vIP7XaTLQTK5dpYs4yg=";
        "8.4.6" = "sha256-s0/qzGJEJRK4iT3gbz+gXoaGoFT+aE+wuEi73614L3g=";
        "8.4.7" = "sha256-6wtvSR1l9LNO5KFjffJCsR8Cm1OVZZD7gvGbh3P7sJw=";
        "8.4.8" = "sha256-0kO/8mZV0a5fiL8ti+gxNd4BE/8izuEITmcoSsonQSI=";
        "8.4.9" = "sha256-tBeJZ+lLz65rc6uq9XU5fmqsgf+68UTXV6OJHQv4nZY=";
        "8.4.10" = "sha256-gcmcsaFpEhsroUtBp7RAIHDxjpfY1HE3ol/coX1/+TE=";
        "8.4.11" = "sha256-jc+lS1imqvSFP8J3UsJdbCWSxIWVKy+tJam+pLUr7TM=";
        "8.4.12" = "sha256-hNEjMYpR4U5bvhuMLlyTrymTEPvAJrhvc3VZTNpeANg=";
        "8.4.13" = "sha256-xlASTK9HhbtTJyDLnSkCNY7pqdbHGFLvTNvda3xdtPw=";
        "8.4.14" = "sha256-J0bjxWilg3z7eoM1mrNEAYhq1iGWWrRXEzOFmAerYUM=";
        "8.4.15" = "sha256-hGcPajZHvE42CKtGMGIahMqo41sN2gF9a+6isGlAr60=";
        "8.4.16" = "sha256-I+klpZdE6fK853cJca1deyLqdHcPcf36JNXtNkeBNW0=";
        "8.4.17" = "sha256-8eH+/M2V9dk/XWHd4Yf4Xn6RJgy2T3YYlQxfRjsFfZk=";
        "8.4.18" = "sha256-3uJzy6WI7JGQ8O49/pF75JxSroR/IMOqckYVRkUd8KQ=";
        "8.4.19" = "sha256-HCRHIvtAnod0xdRdagsh7cPkVB/QFqQK/fU8lKaaPbk=";
        "8.4.20" = "sha256-/LMXtlxp8daWIFfFYiqAmAvCL/rfJcHMULbQL/bCz0A=";
        "8.5.0" = "sha256-82TIkResgzlQv+3YSBjDCfr99tYAqp5t+RCWhpZyeXw=";
        "8.5.1" = "sha256-aRYg9/McvFURWBEQgIYbwF5KhsKZMiMjNMdHhwc7DJQ=";
        "8.5.2" = "sha256-32X43GNPfu8Fl1OohZYp2lEZ8+hkcTa51s5kebALdcs=";
        "8.5.3" = "sha256-2WbtT087ffnFLobnYhcq9/VVbaGh0Rf5Jn1l3lq85gE=";
        "8.5.4" = "sha256-AVdigZX/2ZTCAvFtN5XE8TAoHZYC8O8PYdm9pFSVKwg=";
        "8.5.5" = "sha256-h1gIRo5rCQjoUj7CL19h1wljZ3JVsDuNR4TX1fQMjcM=";
        "8.5.6" = "sha256-JG0J2hFTB8YPHJH8/O+FGJUuFm3gWLau9/vP+nbKFQ4=";
        "8.5.7" = "sha256-Z9KNUajQTDcRQDAnZQO8iFmkspG8MxM1VqstETA+ZvI=";
        "8.5.8" = "sha256-awkMECQDjQOB4cz71tXA8ObvIFJpzrnSi9e9esW79Kc=";
        "8.5.9" = "sha256-OrZxtBfj7rQbnO9ibXQtj39XQlEB6D5fytHVUs2ZI30=";
        "8.5.10" = "sha256-9YIGPt1UGaOe6Pe1yPldVXtdqtE++w7S8JZ8oYVhO7c=";
        "8.5.11" = "sha256-it3DhfprW+RgXm1o+9xMDmdMWvHcHJXsVCA5DEsIBCo=";
        "8.5.12" = "sha256-ILp6EKMFcZg6/TWZ8ZtEGttSIrIfHSsn0Puj7Y1HB8I=";
        "8.5.13" = "sha256-m4aN1WPmVnGib89Ri2uGwbsbZ1b0j9yQ8EMB1POmWWo=";
        "8.5.14" = "sha256-dJTpTx4ZWlBcVCo8UOAVidL4v9GVlzgoJ6iV+hxHHy0=";
        "8.5.15" = "sha256-8k6q5GF5XmsJv1TH6fON7wJYktpV8mAIwWQTz92iiE4=";
        "8.5.16" = "sha256-omy9sEN9BeWgDJk1cHN+cfpsyQhOGRdNcUCXtcuqwbE=";
        "8.5.17" = "sha256-THzY8uCQDLNt3ombP59NXEce48T4MEz57HH9GM1emNY=";
        "8.5.18" = "sha256-AyvlemB73yUhNbUvrJ46cBblJiQjdKx2N7CD7MTF08k=";
        "8.5.19" = "sha256-0/BEVtqHPRfwLvwwc0sDAPtsO4UCjURf4oS4MlOm2xg=";
      };
    }
    {
      def = {
        builder = ./build-8.0.2.nix;
        patches = [
          {
            file = ./patches/8.1.0-va-list-assignment.patch;
            reason = "Tcl_AppendResultVA assigns one va_list to another, which is an array type on x86_64 and does not compile. This is upstream's own memcpy from 8.1.1 applied one release earlier.";
          }
        ];
      };
      releases = {
        "8.1.0" = "sha256-LgRrAYSb8hJAcYmdu2qENmcVKJCvBeCsX3yfuZWIyIY=";
      };
    }
    {
      def = {
        builder = ./build-8.6.0.nix;
        deps = {
          zlib = tvp.packages.zlib_1;
          libgcc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Keep the exact full-tier raw GCC runtime selected by this native driver, independently of public compiler generations.";
          } tvp.bases.gcc_16.full.compiler.cc;
        };
        opts = {
          buildFeatures = {
            cStandard = "gnu89";
            linkUnwinder = true;
          };
          installedInterface = {
            pkgConfigVersion = "8.6";
          };
        };
      };
      releases = {
        "8.6.0" = "sha256-NUQiucR5FoVJkSOy3+Afqpi1VcCJBsAQy0RJ3cddyt4=";
        "8.6.1" = "sha256-Fu52kkjmS6HK5rSDT8xOTt10cNiBQQ6NWPfdFDQ0NRQ=";
      };
    }
    {
      def = {
        builder = ./build-8.6.0.nix;
        deps = {
          zlib = tvp.packages.zlib_1;
          libgcc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Keep the exact full-tier raw GCC runtime selected by this native driver, independently of public compiler generations.";
          } tvp.bases.gcc_16.full.compiler.cc;
        };
        opts = {
          buildFeatures = {
            cStandard = "gnu89";
            linkUnwinder = true;
          };
        };
      };
      releases = {
        "8.6.2" = "sha256-hveuX1gd0JBNBEFWN6s671pQmGwbbQTDQOKxsCWNqcQ=";
        "8.6.3" = "sha256-bOB3jeDVDaqpw0XXwf0SiPtlj2dAKIEufu7pkuMFEAU=";
        "8.6.4" = "sha256-nm7ZTJgcHQxfX++4ES0Gxr9NBQpzJ+lecdQXxBZRnI0=";
      };
    }
    {
      def = {
        builder = ./build-8.6.0.nix;
        deps = {
          zlib = tvp.packages.zlib_1;
          libgcc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Keep the exact full-tier raw GCC runtime selected by this native driver, independently of public compiler generations.";
          } tvp.bases.gcc_16.full.compiler.cc;
        };
        opts = {
          buildFeatures = {
            cStandard = "gnu89";
          };
        };
      };
      releases = {
        "8.6.5" = "sha256-zibVucdQT8JdLxDvC4KxTPEXMVRFta+p5nPtMxgw+1M=";
        "8.6.6" = "sha256-omVAl4Hks+3MTvgiUzBxs0w9xnkLiTljgJuf4iG+/gc=";
        "8.6.7" = "sha256-fGuPhONzMkI8/luuUDRA2IRQ2ozBJDSWJJ+qUmgCa6U=";
        "8.6.8" = "sha256-xDywwVGM5CsA58j26t3VGVxTqY+UrccXI0ply8/T+Wo=";
      };
    }
    {
      def = {
        builder = ./build-8.6.0.nix;
        deps = {
          zlib = tvp.packages.zlib_1;
          libgcc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Keep the exact full-tier raw GCC runtime selected by this native driver, independently of public compiler generations.";
          } tvp.bases.gcc_16.full.compiler.cc;
        };
      };
      releases = {
        "8.6.9" = "sha256-rQzS3iyHubqAhrQ5V6DePrLrVlxxWdX1PMu6P+uRX04=";
        "8.6.10" = "sha256-UZbb9mOOPfjVyHtYFcjCt1hJbrbw5BRGWWyaTmONh+0=";
        "8.6.11" = "sha256-jASGZoWGZyxWk9fZWBfLBaGMXsyi9A4oNrlXgGQIglg=";
        "8.6.12" = "sha256-JsmV3Q8WfkixGWHYke5VX2gMF19xc/+MuCn0683kwaY=";
        "8.6.13" = "sha256-Q6H650EvYf8R3iz9BdKM/Dpzdi81SkF8YjcKVOLK8GY=";
        "8.6.14" = "sha256-WIAiW6v3lUxY1PsPXPYnkQTOHNaqm3HppjIlQOHE3mY=";
        "8.6.15" = "sha256-hh4Vl1Py4vvW7BSEEDcVsL5WvjNXUiuFjTy7X4k//vE=";
        "8.6.16" = "sha256-kcuPphdxxjwmLvtVMFm3x61nV6+lhXr2Jl5LC9wqFKU=";
        "8.6.17" = "sha256-o5Azce/M6KQFxcJF0Cnp9oUCWKYPo3YcTViZVhCUmzE=";
      };
    }
    {
      def = {
        builder = ./build-8.6.18.nix;
        deps = {
          zlib = tvp.packages.zlib_1;
          libgcc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Keep the exact full-tier raw GCC runtime selected by this native driver, independently of public compiler generations.";
          } tvp.bases.gcc_16.full.compiler.cc;
        };
      };
      releases = {
        "8.6.18" = "sha256-FPmvMrF2f/cYR3qPl0rQPDQ0EJfmtD9M5UZE7pdOJo4=";
      };
    }
    {
      def = {
        builder = ./build-8.6.0.nix;
        deps = {
          zlib = tvp.packages.zlib_1;
          libgcc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Keep the exact full-tier raw GCC runtime selected by this native driver, independently of public compiler generations.";
          } tvp.bases.gcc_16.full.compiler.cc;
        };
        opts = {
          buildFeatures = {
            zipfsImage = false;
          };
        };
      };
      status = {
        level = "degraded";
        capability = "zipfsImage";
        reason = "Built with --disable-zipfs, so the script library installs as ordinary files and `info library` names a directory rather than //zipfs:/tcl_library. The zipfs command itself is present and working — mkzip, mount and list all succeed — so what is off is the self-contained interpreter, not the feature.";
        needs = "More than a bootstrap interpreter. Handing configure a TCLSH_NATIVE from a packaged Tcl 9 does get it to report `building with zipfs... yes`, but the resulting tree puts the scripts under lib/tcl9/9.0 with no image built and none mounted, and the interpreter then cannot find init.tcl at all.";
        blocked = {
          package = "tclsh9 (bootstrap)";
        };
      };
      releases = {
        "9.0.0" = "sha256-O/2m267o6bHurMFRG04YoHqR3/gtmVTNuccp2Lyku7c=";
        "9.0.1" = "sha256-pysWB9ejmcdRSMgPzerYjtM3GimIQYHyAPIgDN7jO7w=";
        "9.0.2" = "sha256-4HTGqNm6LN35FLqXtmd6VS16UqPKECkkOJoFzLJJtSA=";
        "9.0.3" = "sha256-JTe6DIYRLIyVP3wJ0z8TTdRcD7OnHy1/dpH9MB0sM6Y=";
        "9.0.4" = "sha256-0K7UkjC8AqZcHgIp5l80WQpLA37EDVRvMlc7Rn91Ueo=";
      };
    }
    {
      def = {
        builder = ./build-9.1.0.nix;
        deps = {
          zlib = tvp.packages.zlib_1;
          libgcc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Keep the exact full-tier raw GCC runtime selected by this native driver, independently of public compiler generations.";
          } tvp.bases.gcc_16.full.compiler.cc;
        };
        opts = {
          testPatches = map (p: p.file) [
            {
              file = ./patches/9.1.0-offline-http-proxy.patch;
              reason = "Tcl 9.1 httpProxy no-proxy tests contact Google without a network constraint. Use the unchanged upstream loopback httpd fixture and retain every response/header/thread assertion in the sandbox. Bind the independent home-directory shell oracle to the declared Bash rather than an absent ambient sh.";
            }
          ];
        };
      };
      status = {
        level = "degraded";
        capability = "zipfsImage";
        reason = "Built with --disable-zipfs, so the script library installs as ordinary files and `info library` names a directory rather than //zipfs:/tcl_library. The zipfs command itself is present and working — mkzip, mount and list all succeed — so what is off is the self-contained interpreter, not the feature.";
        needs = "More than a bootstrap interpreter. Handing configure a TCLSH_NATIVE from a packaged Tcl 9 does get it to report `building with zipfs... yes`, but the resulting tree puts the scripts under lib/tcl9/9.0 with no image built and none mounted, and the interpreter then cannot find init.tcl at all.";
        blocked = {
          package = "tclsh9 (bootstrap)";
        };
      };
      releases = {
        "9.1.0" = "sha256-U2xFVD9k1usRgy2XujSUqs/wRvvFBAJzvVUljQ5Ej/E=";
      };
    }
  ];
  pname = "tcl";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
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
    source = import ./source.nix { inherit (pkgs) lib fetchurl; };
    tests = import ./tests/installed.nix;
    testDeps.pkg-config = tvp.packages.pkg-config;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.tcl = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

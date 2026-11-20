{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-3.0.9.nix;
        deps.file = tvp.packages.file;
        opts.testEdits = [
          {
            path = "testsuite/libffi.call/err_bad_abi.c";
            before = "args[0] = NULL;";
            after = "args[0] = NULL;\n        (void)args;";
            count = 1;
          }
        ];
      };
      releases = {
        "3.0.9" = "sha256-WJ0lFSMYvHgM2JGbFGcHk/SXHZg42rRu04wys+6SxFI=";
      };
    }
    {
      def = {
        builder = ./build-3.0.9.nix;
        deps.file = tvp.packages.file;
        opts.testHarnessFile = "testsuite/lib/libffi.exp";
      };
      releases = {
        "3.0.10" = "sha256-8B65An6etWrq7vY2ZJh3dW1HXXFO+LR/Yn9lvF87SS8=";
      };
    }
    {
      def = {
        builder = ./build-3.0.9.nix;
        deps.file = tvp.packages.file;
        opts = {
          variadic = true;
          testHarnessFile = "testsuite/lib/libffi.exp";
          upstreamData = {
            "testsuite/libffi.call/a.out" = {
              magic = "7f454c4602010100";
              mode = 493;
              sha256 = "a8dcdd09dbb6110ba74176197c3ca5a640a178f1af7763a98e5d42312132ee42";
            };
          };
        };
      };
      releases = {
        "3.0.11" = "sha256-cL+wE1Y2AImql9PnHj7fBdGVWZ/YIuki5Q1GoAVaYoM=";
      };
    }
    {
      def = {
        builder = ./build-3.0.9.nix;
        deps.file = tvp.packages.file;
        opts = {
          variadic = true;
          additionalSourceScripts = [ "libtool-ldflags" ];
          # These archives install multi-os libraries in lib64 despite --libdir.
          artifactLibraryDirectory = "lib64";
          testHarnessFile = "testsuite/lib/libffi.exp";
        };
      };
      releases = {
        "3.0.12" = "sha256-LqDbkMK7zJB8Ou/D926d/Ds1x6D7daQxn1JI4BcsHp4=";
        "3.0.13" = "sha256-Hd3eFADDvLd0nTmAca+Iw+R1QFjS1MCzaWwvgtxc8Rw=";
      };
    }
    {
      def = {
        builder = ./build-3.1.nix;
        deps.file = tvp.packages.file;
      };
      releases = {
        "3.1" = "sha256-l/7urcpeIYcPpEM7yVPRs68/aY1d+KQo9otzzWCu9us=";
        "3.2" = "sha256-ayaA+/aunCOB04EkhwWFfeIuBbrhkYiSmPjmv7Le1O8=";
        "3.2.1" = "sha256-0G67jh2aItGeONY/24OVQlPzm+3F1GIyoFZFaFciyjc=";
      };
    }
    {
      def = {
        builder = ./build-3.3.nix;
        deps.file = tvp.packages.file;
      };
      releases = {
        "3.3" = "sha256-cvunkicD3fp6Ao1ROsFahcjVTI1n9V+lpIAohdxlIFY=";
        "3.4.2" = "sha256-VA+3IWGaaro73u99lA2Ong5tLBk1lbwkMkG3f/npNiA=";
      };
    }
    {
      def = {
        builder = ./build-3.3.nix;
        deps.file = tvp.packages.file;
        # tramp.c calls its existing int(void) helper without a declaration.
        # Upstream fixes it in 3.4.5; retain the source/warning and demote only this GCC14 error.
        opts.cFlags = [ "-Wno-error=implicit-function-declaration" ];
      };
      releases = {
        "3.4.3" = "sha256-RBbdkrauj8tbEEIecRxNPLMSA9d1Iad9hdAQIxHmw7g=";
        "3.4.4" = "sha256-1mxWrSWags8qnfxAizK/XaUjcVALhHRff7i2RXEt9nY=";
      };
    }
    {
      def = {
        builder = ./build-3.3.nix;
        deps.file = tvp.packages.file;
      };
      releases = {
        "3.4.5" = "sha256-lv/05YnjsjnYiNmqRLP/MGk8K6Fhf5U5JacN3rzBArI=";
        "3.4.6" = "sha256-sN6p3yPIY6elDoJUQPPr/6vWXfFJcQjl1Dd0eEOJWk4=";
        "3.4.7" = "sha256-E4YH3uJovezzdK35FEwA6DnjhUH3XySh/PGLeP2kiy0=";
        "3.4.8" = "sha256-vJhCoYiYv6yw7RJSxP68x+ePoTn9J/3Ho+MNnZNWEZs=";
      };
    }
    {
      def = {
        builder = ./build-3.3.nix;
        deps.file = tvp.packages.file;
        opts.versionFunction = true;
      };
      releases = {
        "3.5.0" = "sha256-jHJnhiil3YeC8IrUIdWkQeQsHFwbM+C8IRy/zx87OXg=";
        "3.5.1" = "sha256-+Z62imfH1Uhmt3Bq8kXoe6Bg1BmgYkdLRW07yNSr29E=";
        "3.5.2" = "sha256-86MIKiOzfCk6T80QUxR7Nx8v+R+n6hsqUuM1Z2usgtw=";
      };
    }
    {
      def = {
        builder = ./build-3.3.nix;
        deps.file = tvp.packages.file;
        opts = {
          versionFunction = true;
          # The archive reports its release version in pkg-config, but ffi_get_version is stale.
          reportedVersion = "3.5.2";
        };
      };
      releases = {
        "3.6.0" = "sha256-Mf8f4y3q6/uziHJ/Mmd7slS/KkE4LFFGTAsYN8numCg=";
      };
    }
    {
      def = {
        builder = ./build-3.3.nix;
        deps.file = tvp.packages.file;
        opts.versionFunction = true;
      };
      releases = {
        "3.7.0" = "sha256-IlXFpjjftRv2fCChKnu3DRf+senqurrAX1VzFG9YZDY=";
        "3.7.1" = "sha256-1emmY43b0lE921RRjrZ+S75vpwe8wBwQ9iEvCgiNgZ0=";
      };
    }
    {
      def = {
        builder = ./build-3.8.0.nix;
      };
      releases = {
        "3.8.0" = "sha256-faPi2aFx6woDj1kuytP/K7JVDzSW2Hs7Ka0M9EMMDbQ=";
        "3.8.1" = "sha256-geh5wJTMXsMYbEhRDGOFrGs+hmGS6Lxxo1JFcDdX7kA=";
      };
    }
  ];
  pname = "libffi";
  sourcewareUrl = version: "https://sourceware.org/pub/libffi/libffi-${version}.tar.gz";
  releaseUrl =
    version: "https://github.com/libffi/libffi/releases/download/v${version}/libffi-${version}.tar.gz";
  sourceUrls =
    version:
    # Upstream published the 3.8.1 tarball on GitHub only.
    if version == "3.8.1" then
      [ (releaseUrl version) ]
    else
      [
        (sourcewareUrl version)
        (releaseUrl version)
      ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;

    source = tvp.lib.sources.archive {
      url = version: builtins.head (sourceUrls version);
      fetch =
        { version, sha256 }:
        tvp.lib.sources.fetchMirrors {
          certificates = tvp.packages.ca-certificates;
          urls = sourceUrls version;
          inherit sha256;
        };
      discovery = {
        type = "git-tags";
        url = "https://github.com/libffi/libffi";

        normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;

        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(pkgs.lib.hasInfix "rc" version || pkgs.lib.hasInfix "dev" version);

        unavailable = [
          {
            versions = [
              "3.4.0"
              "3.4.1"
            ];
            reason = "Tagged but never published as a tarball: the GitHub release for each carries no assets at all, where 3.4.2's carries one, and sourceware's archive has neither. Only git-archive snapshots exist, and that is a different artifact.";
          }
        ];
      };
    };
    tests = import ./tests;
    testDeps = {
      pkgConfig = tvp.packages.pkg-config;
      dejagnu = tvp.lib.packages.withConstraint {
        category = "construction";
        reason = "Retain the exact source GCC DejaGnu/Expect/Tcl harness for libffi ABI and closure tests; it is test-only and does not activate a public compiler generation.";
      } (import ../../../bootstrap/source-gcc-test-harness.nix { }).dejagnu;
      sentinel = tvp.lib.tests.fixtures.sentinel;
      alternateSource = tvp.lib.tests.fixtures.alternateSource;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libffi = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

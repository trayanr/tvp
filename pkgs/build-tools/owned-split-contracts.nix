# Evaluate only the 26 public owned build-tool splits. This returns producer and
# test-registration contracts; evaluating it never realizes a derivation.
{ pkgs, tvp }:
let
  rows = [
    {
      name = "bash_5_2_37";
      id = "canonical/bash_5_2_37";
    }
    {
      name = "binutils_2_42";
      id = "canonical/binutils_2_42";
    }
    {
      name = "bison_3_8_2";
      id = "canonical/bison_3_8_2";
    }
    {
      name = "bzip2_1_0_8";
      id = "canonical/bzip2_1_0_8";
    }
    {
      name = "cmake_4_4_5";
      id = "canonical/cmake_4_4_5";
    }
    {
      name = "coreutils_9_5";
      id = "canonical/coreutils_9_5";
    }
    {
      name = "diffutils_3_12";
      id = "canonical/diffutils_3_12";
    }
    {
      name = "file_5_48";
      id = "canonical/file_5_48";
    }
    {
      name = "findutils_4_11_0";
      id = "canonical/findutils_4_11_0";
    }
    {
      name = "flex_2_6_4";
      id = "canonical/flex_2_6_4";
    }
    {
      name = "gawk_5_4_1";
      id = "canonical/gawk_5_4_1";
    }
    {
      name = "gettext_1_0";
      id = "canonical/gettext_1_0";
    }
    {
      name = "gnugrep_3_12";
      id = "canonical/gnugrep_3_12";
    }
    {
      name = "gnumake_4_4_1";
      id = "canonical/gnumake_4_4_1";
    }
    {
      name = "gnused_4_10";
      id = "canonical/gnused_4_10";
    }
    {
      name = "gnutar_1_35";
      id = "canonical/gnutar_1_35";
    }
    {
      name = "gperf_3_3";
      id = "canonical/gperf_3_3";
    }
    {
      name = "gzip_1_15";
      id = "canonical/gzip_1_15";
    }
    {
      name = "m4_1_4_21";
      id = "canonical/m4_1_4_21";
    }
    {
      name = "meson_1_12_1";
      id = "canonical/meson_1_12_1";
    }
    {
      name = "ninja_1_13_2";
      id = "canonical/ninja_1_13_2";
    }
    {
      name = "patch_2_8_1";
      id = "canonical/patch_2_8_1";
    }
    {
      name = "pkg-config_0_29_2";
      id = "canonical/pkg-config_0_29_2";
    }
    {
      name = "texinfo_7_1";
      id = "canonical/texinfo_7_1";
    }
    {
      name = "which_2_21";
      id = "canonical/which_2_21";
    }
    {
      name = "xz_5_8_4";
      id = "canonical/xz_5_8_4";
    }
  ];
  inherit (tvp.builder) steps;
  attempt = x: builtins.tryEval (builtins.deepSeq x x);
  id = p: {
    drv = p.drvPath;
    out = p.outPath;
  };
  projected =
    p:
    builtins.all (q: q.drvPath == p.drvPath && q.artifact.drvPath == p.artifact.drvPath) (
      [ p.out ] ++ p.all
    );
  inspect =
    r:
    let
      p = tvp.canonical.${r.name};
      parts = steps.partition p.buildSteps;
      suffix = p.editSteps (
        steps.append [
          {
            name = "split.control";
            run = "printf control > \"$out/split-control\"";
          }
        ]
      );
      runtime = p.editRuntime (
        r:
        r
        // {
          libraries = (r.libraries or [ ]) ++ [ p.specification.base.compiler.libc ];
          shell = p.specification.base.shell;
        }
      );
      source = p.override { src = "/scoped-source-control"; };
      testEdit = p.edit (
        s:
        s
        // {
          upstreamCheck = (s.upstreamCheck or { }) // {
            enabled = false;
          };
          upstreamPreparation = [ ];
        }
      );
      testCommands = p.edit (
        s:
        s
        // {
          upstreamCheck = (s.upstreamCheck or { }) // {
            command = {
              name = "test.control";
              run = "exit 87";
            };
          };
        }
      );
      tool = p.edit (
        s:
        s
        // {
          environment = s.environment // {
            overrides.values.OWNED_SPLIT_TOOL_CONTROL = "changed";
          };
        }
      );
    in
    {
      inherit (r) id;
      artifact = id p.artifact;
      final = id p;
      checks = {
        split =
          parts.split
          && builtins.length (steps.active parts.first) > 0
          && builtins.length (steps.active parts.second) > 0;
        suffixReuses = suffix.artifact.drvPath == p.artifact.drvPath && suffix.drvPath != p.drvPath;
        runtimeReuses = runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
        sourceInvalidates = source.artifact.drvPath != p.artifact.drvPath;
        toolInvalidates = tool.artifact.drvPath != p.artifact.drvPath;
        testsReuse =
          testEdit.drvPath == p.drvPath
          && testEdit.artifact.drvPath == p.artifact.drvPath
          && testCommands.drvPath == p.drvPath;
        projection = projected p && projected suffix;
        productionNoChecks = builtins.all (
          s: builtins.match ".*\\.(check|upstream)" s.name == null
        ) parts.first;
        finalWorkspace = builtins.all (s: (s.cwd or ".") == ".") (steps.active parts.second);
        noOp = (p.override { }).drvPath == p.drvPath && (p.edit (s: s)).drvPath == p.drvPath;
        freshProducers =
          p.drvPath == ((import (../../lib/owned-build.nix) { inherit (pkgs) lib; }) p.specification).drvPath;
      };
      # Force every shared installed test and the separate check variant, without realizing it.
      tests = pkgs.lib.mapAttrs (_: t: attempt t.drvPath) p.tests;
      upstream = p.specification ? upstreamCheck;
      options = builtins.attrNames p.tvp.declaredDependencies;
      sourceVersion = p.version;
      testCount = builtins.length (builtins.attrNames p.tests);
      finalCwds = map (s: s.cwd or ".") (steps.active parts.second);
      outputChecks = p.outputChecks or { };
      plan = map (s: s.name) p.buildSteps;
    };
in
map inspect rows

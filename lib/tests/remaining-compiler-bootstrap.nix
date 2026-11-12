# Bounded source contracts only: the assigned five ordinary recipes.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  steps = tvp.builder.steps;
  alternate = tvp.canonical.coreutils_9_5;
  has =
    a: b:
    lib.hasInfix (builtins.unsafeDiscardStringContext (toString a)) (
      builtins.unsafeDiscardStringContext b
    );
  run = p: name: (builtins.head (builtins.filter (s: s.name == name) p.buildSteps)).run;
  goNames = [
    "go_1_17_13"
    "go_1_20_14"
    "go_1_22_12"
    "go_1_24_13"
  ];
  targets = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = tvp.canonical.${name};
    }) ([ "gcc_13_3_0" ] ++ goNames)
  );
  common =
    name: p:
    let
      s = p.specification;
      noop = p.override { };
      edit = p.edit (s: s);
      checked = p.override { doCheck = true; };
      changed = p.override { coreutils = alternate; };
      suffix = p.editSteps (
        plan:
        plan
        ++ [
          {
            name = "contract.final";
            tools = [ alternate ];
            run = "printf final > \"$out/contract-final\"";
          }
        ]
      );
      prefix = p.editSteps (
        plan:
        [
          {
            name = "contract.artifact";
            tools = [ alternate ];
            run = "printf artifact > \"$out/contract-artifact\"";
          }
        ]
        ++ plan
      );
      runtime = p.editRuntime (
        r:
        r
        // (
          if lib.hasPrefix "go_" name then
            { shell = alternate; }
          else
            { loader = "${s.glibc}/lib/ld-linux-x86-64.so.2.contract"; }
        )
      );
      parts = steps.partition s.plan;
    in
    {
      owned = p ? stageInputs && !(p ? stdenv);
      split = parts.split && builtins.length parts.first > 1 && builtins.length parts.second > 1;
      noOp =
        noop.drvPath == p.drvPath
        && noop.artifact.drvPath == p.artifact.drvPath
        && edit.drvPath == p.drvPath;
      checkIsolation = checked.drvPath == p.drvPath && checked.artifact.drvPath == p.artifact.drvPath;
      effective =
        changed.drvPath != p.drvPath
        && changed.artifact.drvPath != p.artifact.drvPath
        && changed.tvp.deps.coreutils.outPath == alternate.outPath;
      sourceEdit =
        let
          changedSource = p.edit (
            s: s // { src = builtins.toFile "source-edit-contract" "synthetic; never built"; }
          );
        in
        changedSource.artifact.drvPath != p.artifact.drvPath && changedSource.drvPath != p.drvPath;
      prefix = prefix.artifact.drvPath != p.artifact.drvPath;
      suffix = suffix.drvPath != p.drvPath && suffix.artifact.drvPath == p.artifact.drvPath;
      runtime = runtime.drvPath != p.drvPath && runtime.artifact.drvPath == p.artifact.drvPath;
      rebound =
        suffix.tests.version.package.drvPath == suffix.drvPath
        && suffix.tests.version.drvPath != p.tests.version.drvPath;
      named = p.out.drvPath == p.drvPath && (builtins.head p.all).drvPath == p.drvPath;
      metadata =
        p.meta.license.spdxId == (if name == "gcc_13_3_0" then "GPL-3.0-or-later" else "BSD-3-Clause");
    };
  gcc = targets.gcc_13_3_0;
  gs = gcc.specification;
  go =
    name:
    let
      p = targets.${name};
      s = p.specification;
      changed = p.edit (
        s:
        s
        // {
          bootstrap = alternate;
          helperPython = alternate;
        }
      );
      cc = p.edit (
        s:
        s
        // {
          environment = s.environment // {
            overrides.values = {
              CC = "${alternate}/selected-cc";
              CXX = "${alternate}/selected-cxx";
            };
          };
        }
      );
      local = p.editRuntime (r: r // { toolchain = "auto"; });
    in
    {
      bootstrap =
        has "${alternate}/share/go" (run changed "go.build")
        && changed.artifact.drvPath != p.artifact.drvPath;
      cc =
        has "${alternate}/selected-cc" (run cc "go.build")
        && has "${alternate}/selected-cxx" (run cc "go.build")
        && has "${alternate}/selected-cc" (builtins.head cc.tests.compiler-default.buildSteps).run;
      tests = builtins.all (n: builtins.hasAttr n p.tests) [
        "version"
        "compiler-default"
        "modules"
        "compile"
        "cgo"
        "standard-library"
        "installed-environment"
      ];
      boundary = p.tvp.features.toolchainSelection == lib.versionAtLeast p.version "1.21";
      stable =
        (has "export GOROOT_FINAL=/tvp/go" (run p "go.build")) == lib.versionOlder p.version "1.24";
      local =
        if p.tvp.features.toolchainSelection then
          local.artifact.drvPath == p.artifact.drvPath
          && local.drvPath != p.drvPath
          && local.tests.toolchain-default.drvPath != p.tests.toolchain-default.drvPath
        else
          !(p.tests ? toolchain-default);
      upstreamIsolation =
        let
          changed = p.edit (
            s:
            s
            // {
              upstreamArguments = [
                "-rebuild"
                "-v"
              ];
            }
          );
        in
        changed.drvPath == p.drvPath
        && changed.artifact.drvPath == p.artifact.drvPath
        && changed.validation.drvPath != p.validation.drvPath
        && changed.tests.upstream-audit.drvPath != p.tests.upstream-audit.drvPath;
      layout = has "$out/share/go" (run p "go.install") && has "../share/go/bin/go" (run p "go.install");
    };
in
{
  common = lib.mapAttrs common targets;
  go = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = go name;
    }) goNames
  );
  gcc = {
    bootstrap = has "make" (run gcc "gcc.bootstrap") && has "compare" (run gcc "gcc.bootstrap");
    patches = builtins.length gs.patches == 3;
    libc = gs.glibc.drvPath == tvp.bases.default.stdenv.cc.libc.drvPath;
    raw = gcc.rawCompiler && gcc.tvp.bootstrap && gcc.libc.drvPath == gs.glibc.drvPath;
    tests = builtins.all (n: builtins.hasAttr n gcc.tests) [
      "version"
      "c"
      "cxx"
      "lto"
      "binutils"
      "tool-overrides"
      "tracker"
      "upstream-audit"
    ];
    validation =
      gcc.validation.drvPath != gcc.drvPath && gcc.validation.drvPath != gcc.artifact.drvPath;
    sourceRoot = has "sourceRoot =" (
      builtins.readFile .././../pkgs/compilers/gcc/tests/upstream-13.3.0.nix
    );
    provider =
      let
        p = gcc.override { binutils = alternate; };
      in
      has "${alternate}/bin/as" (run p "gcc.configure")
      && has "${alternate}/bin/as" (builtins.head p.tests.binutils.buildSteps).run;
    testOnly =
      let
        changed = gcc.edit (
          s:
          s
          // {
            upstreamRestore = builtins.toFile "gcc13-restore-test-edit.py" (
              (builtins.readFile s.upstreamRestore) + "\n# source-only contract edit\n"
            );
          }
        );
      in
      changed.drvPath == gcc.drvPath
      && changed.artifact.drvPath == gcc.artifact.drvPath
      && changed.validation.drvPath != gcc.validation.drvPath
      && changed.tests.upstream-audit.drvPath != gcc.tests.upstream-audit.drvPath;
    bootstrapOverride =
      let
        p = gcc.override { bootstrap = false; };
      in
      p.artifact.drvPath != gcc.artifact.drvPath
      && has "--disable-bootstrap" (run p "gcc.configure")
      && !(has "Comparison successful." (run p "gcc.bootstrap"));
    noGcc16Rules =
      !(has "upstream-known-16" (builtins.readFile ../../pkgs/compilers/gcc/tests/upstream-13.3.0.nix));
  };
}

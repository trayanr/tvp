# A -> private T -> private R -> registered owned U. Installed consumers use F.
{
  package,
  tvpLib,
  builder,
  lib,
}:
let
  s = package.specification;
  environment = s.base.environment (s.environment // { tools = s.environment.tools ++ s.testTools; });
  protocol = s.upstreamIsolation.protocol;
  validation =
    role: plan:
    builder {
      recipe =
        { }:
        _: {
          pname = "openssl-${role}";
          inherit (s)
            version
            base
            bash
            coreutils
            ;
          src = null;
          inherit plan;
          validationRole = role;
        };
      args = { };
      dependencyNames = [ ];
      metadata.kind = "owned-validation";
      selection.kind = "owned-validation";
      mkTests = _: { };
    };
  restore = from: {
    name = "openssl.restore-private-tree";
    tools = [ s.python ];
    run = ''${s.python}/bin/python3 -B ${s.testRestoreScript} ${from} "$TVP_SOURCE_ROOT" ${s.stateScript}'';
  };
  make = ''${s.gnumake}/bin/make -j1 SHELL=${s.bash}/bin/bash PERL=${s.testPerl}/bin/perl'';
  construction = validation "upstream-construction" [
    (restore "${package.artifact}/${s.upstreamIsolation.statePath}")
    (
      environment
      // {
        name = "openssl.prepare-private-tests";
        run = ''
          cd -- "$(cat "$TVP_SOURCE_ROOT/tree-path")"
          ${builtins.concatStringsSep "\n" (
            map (p: "${s.testPatchTool}/bin/patch -p1 < ${p.file}") (
              tvpLib.packages.checkPatches "openssl.testPatches" s.testPatches
            )
          )}
          ${s.python}/bin/python3 -B ${s.testPrepareScript} ${s.bash}/bin/bash ${s.testPerl}/bin/perl ${s.coreutils} ${lib.escapeShellArg s.sourceEncoding}
        '';
      }
    )
    (
      environment
      // {
        name = "openssl.construct-private-tests";
        run = ''
          cd -- "$(cat "$TVP_SOURCE_ROOT/tree-path")"
          export NIX_CFLAGS_COMPILE="''${NIX_CFLAGS_COMPILE:-} ${builtins.concatStringsSep " " s.testCompileFlags}"
          ${
            if protocol == "openssl-0.9.7" then
              (if lib.versionOlder s.version "0.9.8" then "${make} DIRS=test all" else "${make} build_tests")
            else if protocol == "openssl-1.0.0" then
              "${make} build_tests"
            else
              "${make} build_programs ${if protocol == "openssl-1.1.0" then "build_engines" else "build_modules"}"
          }
          ${s.python}/bin/python3 -B ${s.stateScript} save "$PWD" "$out" ${s.stateManifest} \
            ${protocol} "$(cat "$TVP_SOURCE_ROOT/production-prefix")" "$TVP_SOURCE_ROOT/source-date-epoch" fixture
        '';
      }
    )
  ];
  execution = validation "upstream-execution" [
    (restore construction)
    (
      environment
      // {
        name = "openssl.capture-upstream";
        run = ''
          cd -- "$(cat "$TVP_SOURCE_ROOT/tree-path")"
          export NIX_CFLAGS_COMPILE="''${NIX_CFLAGS_COMPILE:-} ${builtins.concatStringsSep " " s.testCompileFlags}"
          ${builtins.concatStringsSep "\n" (
            lib.mapAttrsToList (n: v: "export ${n}=\"${v}\"") s.testEnvironment
          )}
          ${s.python}/bin/python3 -B ${s.captureScript} "$out/raw" \
            ${s.bash}/bin/bash ${s.runnerScript} ${s.gnumake}/bin/make ${s.bash}/bin/bash ${s.testPerl}/bin/perl
        '';
      }
    )
  ];
in
(package.testContext.mkTest {
  package = execution;
  name = "upstream";
  tools = [ s.python ];
  script = ''${s.python}/bin/python3 -B ${s.classifyScript} ${execution}/raw'';
  expected = s.upstreamExpected;
}).edit
  (
    spec:
    spec
    // {
      validation = {
        role = "upstream-acceptance";
        inherit construction execution;
        production = package.artifact;
        factory = "owned.mkTest";
      };
      passthru = spec.passthru // {
        validation = {
          inherit construction execution;
          production = package.artifact;
        };
      };
    }
  )

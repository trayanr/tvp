# Actual validation producers. Only the acceptance test is a registered test.
{
  package,
  tvpLib,
  builder,
  lib,
}:
let
  s = package.specification;
  # Use the same explicit production environment and fixture-only additions.
  environment = s.base.environment s.environment;
  protocol = s.upstreamIsolation.protocol;
  modern = protocol == "veryquick";
  fixtureEnv = ''
    export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE ${
      builtins.concatStringsSep " " (s.compileFlags ++ s.testCompileFlags)
    } -isystem ${s.testZlib}/include -DSQLITE_HAVE_ZLIB=1"
    export NIX_LDFLAGS="$NIX_LDFLAGS -rpath-link ${s.readline.tvp.deps.ncurses}/lib -rpath-link ${s.tcl.tvp.deps.zlib}/lib -L${s.testZlib}/lib -rpath ${s.testZlib}/lib -L${s.tcl}/lib -rpath ${s.tcl}/lib${if modern then "" else " -lz"}"
  '';
  hardening = ''
    export NIX_HARDENING_ENABLE=${lib.escapeShellArg (builtins.concatStringsSep " " (lib.subtractLists s.hardeningDisable s.base.compiler.defaultHardeningFlags))}
    export NIX_HARDENING_DISABLE=${lib.escapeShellArg (builtins.concatStringsSep " " s.hardeningDisable)}
  '';
  validation =
    role: plan:
    builder {
      recipe = { }: _: {
        pname = "sqlite-${role}";
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
    name = "sqlite.restore-private-tree";
    tools = [ s.python ];
    run = ''
      ${s.python}/bin/python3 -B ${s.testRestoreScript} ${from} "$TVP_SOURCE_ROOT" ${s.stateScript}
    '';
  };
  construction = validation "upstream-construction" [
    (restore "${package.artifact}/${s.upstreamIsolation.statePath}")
    (
      environment
      // {
        name = "sqlite.prepare-private-fixture";
        run = ''
          cd -- "$(cat "$TVP_SOURCE_ROOT/tree-path")"
          ${builtins.concatStringsSep "\n" (
            map (p: "${s.patch}/bin/patch -p1 < ${p.file}") (
              tvpLib.packages.checkPatches "sqlite.testPatches" s.testPatches
            )
          )}
          ${s.python}/bin/python3 -B ${s.testPrepareScript} "$PWD" ${protocol} ${s.bash}/bin/bash
        '';
      }
    )
    (
      environment
      // {
        name = "sqlite.build-private-fixture";
        run =
          hardening
          + fixtureEnv
          + ''
            cd -- "$(cat "$TVP_SOURCE_ROOT/tree-path")"
            prefix=$(cat "$TVP_SOURCE_ROOT/production-prefix")
            export TCLLIBPATH="$prefix/lib/tcl"
            ${s.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${s.bash}/bin/bash \
              TCLLIBDIR="$prefix/lib/tcl" testfixture ${if modern then ''LDFLAGS.libsqlite3="-lm -lz"'' else ""}
            ${s.python}/bin/python3 -B ${s.stateScript} save "$PWD" "$out" \
              ${s.stateManifest} ${protocol} "$prefix" "$TVP_SOURCE_ROOT/source-date-epoch" fixture
          '';
      }
    )
  ];
  execution = validation "upstream-execution" [
    (restore construction)
    (
      environment
      // {
        name = "sqlite.run-upstream";
        run =
          hardening
          + (if s.testFixtureRelinks then fixtureEnv else "")
          + ''
            cd -- "$(cat "$TVP_SOURCE_ROOT/tree-path")"
            export HOME="$TMPDIR" TERM=xterm TZ=UTC
          ''
          + (
            if modern then
              ''
                cp -- ${s.runnerScript} fixture-runner.tcl
                ${s.bash}/bin/bash ${s.captureScript} "$out/raw" \
                  ${s.coreutils}/bin/timeout 900 ./testfixture fixture-runner.tcl ${s.reportedVersion}
                # Preserve capture even on missing runner files: strict U rejects them.
                if [[ -f testrunner.log ]]; then cp -- testrunner.log "$out/raw/runner.log"; fi
                if [[ -f testrunner.db ]]; then cp -- testrunner.db "$out/raw/runner.db"; fi
              ''
            else
              ''
                ${s.bash}/bin/bash ${s.captureScript} "$out/raw" \
                  ${s.coreutils}/bin/timeout 900 ./testfixture test/quick.test
              ''
          );
      }
    )
  ];
in
(package.testContext.mkTest {
  package = execution;
  name = "upstream";
  tools = [ s.python ];
  script = ''
    ${s.python}/bin/python3 -B ${s.classifyScript} ${execution}/raw ${
      if modern then "${package}/bin/sqlite3" else ""
    }
  '';
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

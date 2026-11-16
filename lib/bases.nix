{ lib, platforms }:
rec {
  # The definition is the owned base. Retained recipes still need their original
  # stdenv interface; this view verifies that it selects the same physical inputs.
  # Do not merge the owned fields here: .compiler changes environment dispatch,
  # and legacy .libc is a version string rather than a selected package.
  legacyEnvironment =
    {
      base,
      stdenv,
      name,
      builtBy,
    }:
    let
      fail = message: throw "TVP legacy environment '${name}': ${message}";
      package = value: builtins.isAttrs value && value ? outPath;
      same = left: right: package left && package right && left.outPath == right.outPath;
      owned =
        builtins.isAttrs base
        && base ? compiler
        && base ? tools
        && base.tools ? bash
        && base ? baselineTools
        && base ? platform
        && !(base ? stdenv);
      selected = base.compiler;
      version = package: package.version or (builtins.parseDrvName package.name).version;
      platform = platforms.forStdenv stdenv;
      matchedPlatform =
        base.platform.system == platform.system
        && base.platform.config == platform.config
        && (base.platform.isMusl or false) == (stdenv.hostPlatform.isMusl or false)
        && (stdenv.system or platform.system) == platform.system;
      checked =
        if !owned then
          fail "expected an owned base without stdenv"
        else if name == "" then
          fail "name must be nonempty"
        else if !same selected stdenv.cc then
          fail "stdenv compiler differs from the owned selection"
        else if !same selected.bintools stdenv.cc.bintools then
          fail "stdenv Binutils differs from the owned selection"
        else if !same selected.libc stdenv.cc.libc then
          fail "stdenv libc differs from the owned selection"
        else if map (p: p.outPath) base.baselineTools != map (p: p.outPath) stdenv.initialPath then
          fail "stdenv execution floor differs from the ordered owned baseline"
        else if "${base.tools.bash}/bin/bash" != stdenv.shell then
          fail "stdenv shell differs from the owned Bash selection"
        else if !matchedPlatform then
          fail "stdenv execution platform differs from the owned selection"
        else
          true;
      result = {
        inherit
          name
          builtBy
          stdenv
          platform
          ;
        ownedBase = base;
        cc = version selected;
        binutils = version selected.bintools;
        libc = version selected.libc;
        floor = map (p: p.pname or (builtins.parseDrvName p.name).name) base.baselineTools;
        environment = import ./build-environment.nix {
          inherit lib;
          base = result;
        };
      };
    in
    builtins.seq checked result;

  # A base test runs *on* the base, so it is built by that base's own stdenv
  # rather than by runCommand.
  mkBaseTest =
    {
      base,
      name,
      script,
      expected,
    }:
    base.stdenv.mkDerivation {
      name = "tvp-base-${base.name}-${name}";
      dontUnpack = true;
      dontConfigure = true;
      dontInstall = true;

      passthru = {
        inherit base;
        testName = name;
      };
      meta.description = "TVP ${name} test for base ${base.name}";

      buildPhase = ''
        set -eo pipefail

        actual=$(
        ${script}
        )
        expected=${lib.escapeShellArg expected}

        if [ "$actual" != "$expected" ]; then
          echo "FAIL  base ${base.name} / ${name}" >&2
          echo "  expected: $expected" >&2
          echo "  actual:   $actual" >&2
          exit 1
        fi

        printf '%s\n' "$actual" > "$out"
      '';
    };

  mkBaseSuite =
    { base, tests }: lib.mapAttrs (name: spec: mkBaseTest ({ inherit base name; } // spec)) tests;

  # An ownership audit only needs roots and allowed outputs. It does not imply
  # any compiler family, optional tools, component layout or consumer suite.
  mkOwnershipTest =
    {
      pkgs,
      base,
      name,
      roots,
      allowedRuntimePaths,
    }:
    mkBaseTest {
      inherit base name;
      script =
        let
          closure = pkgs.closureInfo { rootPaths = roots; };
          allowed = pkgs.writeText "tvp-${name}-paths" (
            lib.concatMapStrings (path: "${path}\n") allowedRuntimePaths
          );
        in
        ''
          foreign=0
          while IFS= read -r path; do
            if ! grep -Fx "$path" ${allowed} > /dev/null; then
              echo "unowned runtime dependency: $path" >&2
              foreign=1
            fi
          done < ${closure}/store-paths
          test "$foreign" = 0
          echo ok
        '';
      expected = "ok";
    };
}

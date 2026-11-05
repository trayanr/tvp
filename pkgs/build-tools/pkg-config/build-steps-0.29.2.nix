# Owned route; intentionally separate from the canonical stdenv recipe.
{
  lib,
  tvp,
  base,
  src,
  version,
  bash,
  coreutils,
  python,
  gnumake,
  gnutar,
  gzip,
  findutils,
  sed,
  grep,
  diffutils,
  gawk,
  binutils,
  patchelf,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
  logged =
    name: run:
    command "pkg-config.${name}" ''
      mkdir -p "$out/.tvp-evidence"
      export SHELL=${bash}/bin/bash CONFIG_SHELL=${bash}/bin/bash
      status=0
      ${bash}/bin/bash -euc ${lib.escapeShellArg run} > "$out/.tvp-evidence/${name}.log" 2>&1 || status=$?
      printf '%s\n' "$status" > "$out/.tvp-evidence/${name}.status"
      if (( status != 0 )); then cat "$out/.tvp-evidence/${name}.log"; exit "$status"; fi
    '';
in
{
  pname = "pkg-config";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  buildEnvironment = import ../../../lib/pkg-config-environment.nix;
  environment = {
    tools = [
      gnumake
      sed
      grep
      diffutils
      gawk
      findutils
    ];
    # Bundled GLib has a bool field, reserved in C23. Keep the measured dialect.
    overrides.flags.NIX_CFLAGS_COMPILE = [ "-std=gnu17" ];
  };
  runtime.libraries = (final.base.environment final.environment).libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "pkg-config.prepare";
      inherit bash python;
      base = final.base;
    })
    (steps.shebangs {
      name = "pkg-config.source-shells";
      inherit python;
      paths = [
        "configure"
        "glib/configure"
        "config.guess"
        "config.sub"
        "install-sh"
        "missing"
        "check"
        "glib/install-sh"
        "glib/missing"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${bash}/bin/bash";
    })
    (logged "configure" ''
      # Empty compiled default: only explicitly provided public .pc directories.
      ./configure --prefix="$out" --with-internal-glib --with-pc-path= --disable-dependency-tracking
      cp config.log "$out/.tvp-evidence/"
    '')
    (logged "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'')
    (
      (logged "check" ''
        # The complete pkg-config discovery suite; not bundled GLib's own suite.
        ${gnumake}/bin/make -C check -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash TESTS_SHELL=${bash}/bin/bash check
      '')
      // {
        enabled = doCheck;
      }
    )
    (logged "install" ''${gnumake}/bin/make SHELL=${bash}/bin/bash install'')
    (steps.split "pkg-config.finalize")
    (outputs.copyArtifacts { inherit coreutils; })
    {
      name = "pkg-config.remove-evidence";
      run = ''rm -rf "$out/.tvp-evidence"'';
    }
    (outputs.strip {
      inherit python binutils;
      paths = [ "bin" ];
    })
    {
      name = "pkg-config.charset-directory";
      tools = [ python ];
      run = ''
        # Internal GLib's libcharset embeds LIBDIR, even with an empty pc path.
        # Rebase only that NUL-terminated constant after stripping debug data.
        ${python}/bin/python3 -B - "$out" "$TVP_ARTIFACT_ROOT" <<'PYCODE'
        from pathlib import Path
        import sys
        root, artifact = sys.argv[1:]
        # The optimized charset constant can fold overlapping literal tails;
        # identify its store hash and validate the complete /lib string.
        prefix = artifact.rsplit('/', 1)[0] + '/' + artifact.rsplit('/', 1)[1].split('-', 1)[0] + '-'
        new = (root + '/lib').encode() + b'\0'
        for path in (Path(root) / 'bin').iterdir():
            data = path.read_bytes()
            start = data.find(prefix.encode())
            if start >= 0:
                assert data.count(prefix.encode()) == 1
                end = data.index(b'\0', start) + 1
                old = data[start:end]
                assert old.endswith(b'/lib\0') and len(new) <= len(old), old
                path.write_bytes(data[:start] + new.ljust(len(old), b'\0') + data[end:])
                print('rebased internal GLib charset directory:', path.name, repr(old))
        PYCODE
      '';
    }
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [ "bin" ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "bin" ];
    })
  ];
}

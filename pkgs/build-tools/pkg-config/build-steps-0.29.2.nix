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
      python
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
    (command "pkg-config.charset-source" ''
      # GNU libc supplies canonical codeset names; upstream installs no alias
      # file here. Keep its missing-file fallback and the environment override,
      # with a stable runtime directory rather than the split artifact prefix.
      ${python}/bin/python3 -B - ${lib.escapeShellArg "${final.base.stdenv.cc.libc}/lib"} <<'PYCODE'
      import json, sys
      from pathlib import Path
      path = Path('glib/glib/libcharset/localcharset.c')
      text = path.read_text()
      old = 'dir = relocate (LIBDIR);'
      assert text.count(old) == 1
      path.write_text(text.replace(old, 'dir = ' + json.dumps(sys.argv[1]) + ';'))
      PYCODE
    '')
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
        # Exercise the actual vendored object, including the path passed to
        # fopen. CLI output alone need not call GLib's charset alias helper.
        mapfile -t charsetArchives < <(${findutils}/bin/find glib/glib -type f -name libcharset.a)
        test "''${#charsetArchives[@]}" = 1
        "$CC" ${./owned/charset-check.c} "''${charsetArchives[0]}" \
          -Wl,--wrap=fopen,--wrap=fopen64 -o "$out/.tvp-evidence/charset-probe"
        mkdir charset-fixture
        printf 'TVP_ALIAS UTF-8\n' > charset-fixture/charset.alias
        {
          env -i "$out/.tvp-evidence/charset-probe" C \
            ${final.base.stdenv.cc.libc}/lib/charset.alias TVP_ALIAS ANSI_X3.4-1968
          env -i "$out/.tvp-evidence/charset-probe" C.UTF-8 \
            ${final.base.stdenv.cc.libc}/lib/charset.alias TVP_ALIAS UTF-8
          env -i CHARSETALIASDIR="$PWD/charset-fixture" "$out/.tvp-evidence/charset-probe" C.UTF-8 \
            "$PWD/charset-fixture/charset.alias" UTF-8 UTF-8
          env -i CHARSETALIASDIR="$PWD/charset-missing" "$out/.tvp-evidence/charset-probe" C \
            "$PWD/charset-missing/charset.alias" TVP_ALIAS ANSI_X3.4-1968
        } > "$out/.tvp-evidence/charset-check.log" 2>&1
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

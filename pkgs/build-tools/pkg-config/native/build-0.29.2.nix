# Native ordinary 0.29.2: internal GLib and explicit discovery on the source-GNU base.
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
  patch,
  cStandard,
  patches,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  environment = final.base.environment final.environment;
  compileFlags = environment.environmentContributions.NIX_CFLAGS_COMPILE.value;
  linkFlags = environment.environmentContributions.NIX_LDFLAGS.value;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
      env = environment.env // {
        NIX_CFLAGS_COMPILE = "";
        NIX_LDFLAGS = "";
        CFLAGS = environment.env.CFLAGS or (lib.concatStringsSep " " compileFlags);
        CXXFLAGS = environment.env.CXXFLAGS or (lib.concatStringsSep " " compileFlags);
        LDFLAGS = environment.env.LDFLAGS or (lib.concatMapStringsSep " " (f: "-Wl,${f}") linkFlags);
      };
    };
  logged =
    name: run:
    command "pkg-config.${name}" ''
      mkdir -p "$out/.tvp-evidence"
      export SHELL=${final.bash}/bin/bash CONFIG_SHELL=${final.bash}/bin/bash
      status=0
      ${final.bash}/bin/bash -euc ${lib.escapeShellArg run} > "$out/.tvp-evidence/${name}.log" 2>&1 || status=$?
      printf '%s\n' "$status" > "$out/.tvp-evidence/${name}.status"
      cat "$out/.tvp-evidence/${name}.log" >&2
      if (( status != 0 )); then exit "$status"; fi
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
  buildEnvironment = import ../../../../lib/pkg-config-environment.nix;
  environment = {
    tools = [
      patch
      gnumake
      python
      sed
      grep
      diffutils
      gawk
      findutils
    ];
    # Bundled GLib has a bool field, reserved in C23. Keep the measured dialect.
    overrides.flags.NIX_CFLAGS_COMPILE = [ "-std=${cStandard}" ];
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
      bash = final.bash;
      inherit python;
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
      interpreter = "${final.bash}/bin/bash";
    })
    (command "pkg-config.charset-source" ''
      ${lib.concatMapStringsSep "\n" (p: ''${patch}/bin/patch --batch --fuzz=0 -p1 < ${p}'') patches}
      ${python}/bin/python3 -B - ${lib.escapeShellArg "${final.base.compiler.libc}/lib"} <<'PYCODE'
      import json, sys
      from pathlib import Path
      path = Path('glib/glib/libcharset/localcharset.c')
      text = path.read_text()
      assert text.count('@TVP_CHARSET_DIR@') == 1
      path.write_text(text.replace('"@TVP_CHARSET_DIR@"', json.dumps(sys.argv[1])))
      PYCODE
    '')
    (logged "configure" ''
      # Empty compiled default: only explicitly provided public .pc directories.
      ./configure --prefix="$out" --with-internal-glib --with-pc-path= --disable-dependency-tracking
      cp config.log "$out/.tvp-evidence/"
    '')
    (logged "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (
      (logged "check" ''
        # The complete pkg-config discovery suite; not bundled GLib's own suite.
        ${gnumake}/bin/make -C check -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash TESTS_SHELL=${final.bash}/bin/bash check
        # Exercise the actual vendored object, including the path passed to
        # fopen. CLI output alone need not call GLib's charset alias helper.
        mapfile -t charsetArchives < <(${findutils}/bin/find glib/glib -type f -name libcharset.a)
        test "''${#charsetArchives[@]}" = 1
        "$CC" ${../owned/charset-check.c} "''${charsetArchives[0]}" \
          -Wl,--wrap=fopen,--wrap=fopen64 -o "$out/.tvp-evidence/charset-probe"
        mkdir charset-fixture
        printf 'TVP_ALIAS UTF-8\n' > charset-fixture/charset.alias
        {
          env -i "$out/.tvp-evidence/charset-probe" C \
            ${final.base.compiler.libc}/lib/charset.alias TVP_ALIAS ANSI_X3.4-1968
          env -i "$out/.tvp-evidence/charset-probe" C.UTF-8 \
            ${final.base.compiler.libc}/lib/charset.alias TVP_ALIAS UTF-8
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
    (logged "install" ''
      ${gnumake}/bin/make SHELL=${final.bash}/bin/bash install
      ${gzip}/bin/gzip -n -9 "$out/share/man/man1/pkg-config.1"
    '')
    (command "pkg-config.remove-evidence" ''rm -rf "$out/.tvp-evidence"'')
    (outputs.strip {
      inherit python binutils;
      paths = [ "bin" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "bin" ];
    })
  ];
  meta = {
    homepage = "https://www.freedesktop.org/wiki/Software/pkg-config/";
    description = "Tool that returns compiler and linker flags for installed libraries";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pkg-config";
  };
}

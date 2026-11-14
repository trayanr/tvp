# Ordinary 0.27.1–0.29.1: GLib 2.32.4 removes the Gettext requirement.
# Keep the older g_date_strftime diagnostic adaptation and GNU17 dialect.
# Neutral prefix plus DESTDIR installs a useful artifact before final relocation.
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
  # The selected compiler wrapper is an explicit tool interface. Keep required
  # transitive development paths when callers replace upstream scalar flags or
  # the structured flag defaults; no ambient NIX_* values participate.
  requiredEnvironment = final.base.environment {
    libraries = final.environment.libraries or [ ];
  };
  customCompile =
    environment.env ? CFLAGS
    || environment.env ? CXXFLAGS
    || environment.env ? CPPFLAGS
    || (final.environment.overrides.flags or { }) ? NIX_CFLAGS_COMPILE;
  customLink = environment.env ? LDFLAGS || (final.environment.overrides.flags or { }) ? NIX_LDFLAGS;
  compileFlags = environment.environmentContributions.NIX_CFLAGS_COMPILE.value;
  linkFlags = environment.environmentContributions.NIX_LDFLAGS.value;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
      env = environment.env // {
        NIX_CFLAGS_COMPILE =
          if customCompile then
            lib.concatStringsSep " " requiredEnvironment.environmentContributions.NIX_CFLAGS_COMPILE.value
          else
            "";
        NIX_LDFLAGS =
          if customLink then
            lib.concatStringsSep " " requiredEnvironment.environmentContributions.NIX_LDFLAGS.value
          else
            "";
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
  finalCommand = name: run: (command name run) // { cwd = "."; };
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
  inherit
    python
    gnumake
    gnutar
    gzip
    findutils
    sed
    grep
    diffutils
    gawk
    binutils
    patchelf
    patch
    ;
  inherit cStandard patches doCheck;
  buildEnvironment = import ../../../../lib/pkg-config-environment.nix;
  environment = {
    tools = [
      final.patch
      final.gnumake
      final.python
      final.sed
      final.grep
      final.diffutils
      final.gawk
      final.findutils
    ];
    # Bundled GLib has a bool field, reserved in C23. Keep the measured dialect.
    overrides.flags.NIX_CFLAGS_COMPILE = [ "-std=${final.cStandard}" ];
  };
  runtime.libraries = (final.base.environment final.environment).libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "pkg-config.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (steps.shebangs {
      name = "pkg-config.source-shells";
      python = final.python;
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
    (command "pkg-config.date-diagnostic" ''
      ${final.python}/bin/python3 -B - ${../../source-targets.py} <<'PYCODE'
      import re, runpy, sys
      text_file = runpy.run_path(sys.argv[1])['text_file']
      p, text = text_file('glib/glib/gdate.c')
      pattern = r'\ngsize[ \t]*\ng_date_strftime '
      text, count = re.subn(pattern, lambda m: '\n#pragma GCC diagnostic push\n#pragma GCC diagnostic ignored "-Wformat-nonliteral"\n' + m[0], text)
      assert count == 1
      p.write_text(text + '\n#pragma GCC diagnostic pop\n')
      PYCODE
    '')
    (command "pkg-config.charset-source" ''
      # Check the target before patch can follow one of its parent directories.
      ${final.python}/bin/python3 -B ${../../source-targets.py} glib/glib/libcharset/localcharset.c
      ${lib.concatMapStringsSep "\n" (
        p: ''${final.patch}/bin/patch --batch --fuzz=0 -p1 < ${p}''
      ) final.patches}
      ${final.python}/bin/python3 -B - ${../../source-targets.py} ${lib.escapeShellArg "${final.base.compiler.libc}/lib"} <<'PYCODE'
      import json, runpy, sys
      text_file = runpy.run_path(sys.argv[1])['text_file']
      path, text = text_file('glib/glib/libcharset/localcharset.c')
      assert text.count('@TVP_CHARSET_DIR@') == 1
      path.write_text(text.replace('"@TVP_CHARSET_DIR@"', json.dumps(sys.argv[2])))
      PYCODE
    '')
    (logged "configure" ''
      # Empty compiled default: only explicitly provided public .pc directories.
      ./configure --prefix=/ --with-internal-glib --with-pc-path= --disable-dependency-tracking
      cp config.log "$out/.tvp-evidence/"
    '')
    (logged "build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (
      (logged "check" ''
        # The complete pkg-config discovery suite; not bundled GLib's own suite.
        ${final.gnumake}/bin/make -C check -j1 SHELL=${final.bash}/bin/bash TESTS_SHELL=${final.bash}/bin/bash check
        # Exercise the actual vendored object, including the path passed to
        # fopen. CLI output alone need not call GLib's charset alias helper.
        mapfile -t charsetArchives < <(${final.findutils}/bin/find glib/glib -type f -name libcharset.a)
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
        enabled = final.doCheck;
      }
    )
    (logged "install" ''
      ${final.gnumake}/bin/make SHELL=${final.bash}/bin/bash DESTDIR="$out" install
    '')
    (command "pkg-config.remove-evidence" ''rm -rf "$out/.tvp-evidence"'')
    (steps.split "pkg-config.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (finalCommand "pkg-config.compress-man" ''
      ${final.gzip}/bin/gzip -n -9 "$out/share/man/man1/pkg-config.1"
    '')
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [ "bin" ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [ "bin" ];
    })
  ];
  meta = {
    homepage = "https://www.freedesktop.org/wiki/Software/pkg-config/";
    description = "Tool that returns compiler and linker flags for installed libraries";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.unix;
    mainProgram = "pkg-config";
  };
}

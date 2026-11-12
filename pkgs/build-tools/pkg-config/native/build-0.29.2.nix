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
in
{
  pname = "pkg-config";
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
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
  upstreamPreparation = [
    (steps.shebangs {
      name = "pkg-config.source-shells";
      inherit python;
      paths = [ "check" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
  ];
  upstreamCheck = {
    enabled = doCheck;
    before = "pkg-config.install";
    command = (
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
    );
  };
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
      ${lib.concatMapStringsSep "\n" (p: "${patch}/bin/patch --batch --fuzz=0 -p1 < ${p}") patches}
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
    (logged "install" ''
      ${gnumake}/bin/make SHELL=${final.bash}/bin/bash install
    '')
    (steps.split "pkg-config.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "pkg-config.relocate";
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${../../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            text = [ ];
            slots = [ ];
            fixed = [ ];
          }
        )
      } ${../../../../lib/installed-tree.py}'';
    }
    {
      name = "output.manuals";
      tools = [ gzip ];
      run = ''${gzip}/bin/gzip -n -9 "$out/share/man/man1/pkg-config.1"'';
    }
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

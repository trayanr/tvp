# Complete pkg-config 0.29.2 procedure. Upstream date fix; preserve equal-width installed prefix fields.
{
  tvp,
  lib,
  base,
  src,
  version,
  patches,
  cStandard ? "gnu17",
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
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
      export SHELL=${tools.bash}/bin/bash CONFIG_SHELL=${tools.bash}/bin/bash TVP_SOURCE_ROOT
      status=0
      ${tools.bash}/bin/bash -euc ${lib.escapeShellArg run} > "$out/.tvp-evidence/${name}.log" 2>&1 || status=$?
      printf '%s\n' "$status" > "$out/.tvp-evidence/${name}.status"
      cat "$out/.tvp-evidence/${name}.log" >&2
      if (( status != 0 )); then exit "$status"; fi
    '';

  checkpoint = "nix-support/pkg-config-build-tree";
  preparation = steps.shebangs {
    name = "pkg-config.upstream-shells";
    cwd = ".";
    paths = [ "check" ];
    names = [
      "sh"
      "bash"
    ];
    interpreter = "${tools.bash}/bin/bash";
  };
in
{
  pname = "pkg-config";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    patches
    cStandard
    doCheck
    ;
  inherit (tools) bash coreutils;
  buildEnvironment = import ../../../lib/pkg-config-environment.nix;
  sourceLayout.scripts = [
    "configure"
    "glib/configure"
    "config.guess"
    "config.sub"
    "install-sh"
    "missing"
    "glib/install-sh"
    "glib/missing"
  ];
  environment = {
    tools = [
      tools.patch
      tools.gnumake
      tools.python
      tools.sed
      tools.grep
      tools.diffutils
      tools.gawk
      tools.findutils
    ];
    # The vendored GLib field named bool predates C23.
    overrides.flags.NIX_CFLAGS_COMPILE = [ "-std=${final.cStandard}" ];
  };
  runtime.libraries = environment.libraries;
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools { name = "pkg-config.prepare"; })
    (steps.shebangs {
      name = "pkg-config.source-shells";
      paths = final.sourceLayout.scripts;
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "pkg-config.charset-source" ''
      # Validate the existing regular leaf and parents before patch can write.
      ${tools.python}/bin/python3 -B ${../source-targets.py} glib/glib/libcharset/localcharset.c
      ${lib.concatMapStringsSep "\n" (
        p: ''${tools.patch}/bin/patch --batch --fuzz=0 -p1 < ${p}''
      ) final.patches}
      ${tools.python}/bin/python3 -B - ${../source-targets.py} ${lib.escapeShellArg "${final.base.compiler.libc}/lib"} <<'PYCODE'
      import json, runpy, sys
      text_file = runpy.run_path(sys.argv[1])['text_file']
      path, text = text_file('glib/glib/libcharset/localcharset.c')
      assert text.count('@TVP_CHARSET_DIR@') == 1
      path.write_text(text.replace('"@TVP_CHARSET_DIR@"', json.dumps(sys.argv[2])))
      PYCODE
    '')
    (logged "configure" ''
      # Explicit discovery directories are the only source of public .pc files.
      ./configure --prefix="$out" --with-internal-glib --with-pc-path= --disable-dependency-tracking
      cp config.log "$out/.tvp-evidence/"
    '')
    (logged "build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'')
    (logged "install" ''
      ${tools.gnumake}/bin/make SHELL=${tools.bash}/bin/bash  install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "pkg-config.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    {
      name = "pkg-config.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }
    (
      preparation
      // {
        run = ''
          cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
          ${preparation.run}
        '';
      }
    )
  ];
  upstreamCheck =
    (command "pkg-config.check" ''
      # Run pkg-config's own discovery suite, not the entire bundled GLib suite.
      ${tools.gnumake}/bin/make -C check -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash TESTS_SHELL=${tools.bash}/bin/bash check
      # Exercise the actual vendored object and the path it passes to fopen.
      mapfile -t charsetArchives < <(${tools.findutils}/bin/find glib/glib -type f -name libcharset.a)
      test "''${#charsetArchives[@]}" = 1
      "$CC" ${./owned/charset-check.c} "''${charsetArchives[0]}" \
        -Wl,--wrap=fopen,--wrap=fopen64 -o "$out/raw/charset-probe"
      mkdir charset-fixture
      printf 'TVP_ALIAS UTF-8\n' > charset-fixture/charset.alias
      {
        env -i "$out/raw/charset-probe" C \
          ${final.base.compiler.libc}/lib/charset.alias TVP_ALIAS ANSI_X3.4-1968
        env -i "$out/raw/charset-probe" C.UTF-8 \
          ${final.base.compiler.libc}/lib/charset.alias TVP_ALIAS UTF-8
        env -i CHARSETALIASDIR="$PWD/charset-fixture" "$out/raw/charset-probe" C.UTF-8 \
          "$PWD/charset-fixture/charset.alias" UTF-8 UTF-8
        env -i CHARSETALIASDIR="$PWD/charset-missing" "$out/raw/charset-probe" C \
          "$PWD/charset-missing/charset.alias" TVP_ALIAS ANSI_X3.4-1968
      } > "$out/raw/charset-check.log" 2>&1
      cat "$out/raw/charset-check.log" >&2
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "pkg-config.finalize")
    (outputs.copyArtifacts { })
    {
      name = "pkg-config.drop-build-state";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}" "$out/.tvp-evidence"'';
    }
    {
      name = "pkg-config.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" '{}' ${../../../lib/installed-tree.py}'';
    }
    {
      name = "output.manuals";
      tools = [ tools.gzip ];
      run = ''${tools.gzip}/bin/gzip -n -9 "$out/share/man/man1/pkg-config.1"'';
    }
    (outputs.strip { paths = [ "bin" ]; })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
    })
    (outputs.checkPaths { paths = [ "bin" ]; })
  ];
  meta = {
    homepage = "https://www.freedesktop.org/wiki/Software/pkg-config/";
    description = "Tool that returns compiler and linker flags for installed libraries";
    license = lib.licenses.gpl2Plus;
    mainProgram = "pkg-config";
  };
}

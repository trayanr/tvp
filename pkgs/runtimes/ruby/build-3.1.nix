# 3.1: upstream removed GDBM; Fiddle and Psych still vendor libraries.
# Complete source construction with independent installed and upstream tests.
{
  tvp,
  lib,
  base,
  src,
  version,
  openssl,
  readline,
  zlib,
  libDir ? "${lib.versions.majorMinor version}.0",
  doCheck ? true,
  cStandard ? null,
  mkmfProbeFlags ? [ ],
  compileFlags ? [ ],
  extraWarnFlags ? [ ],
  patches ? [ ],
  restoreConfigScripts ? false,
  nativeControls ? false,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  environment = final.base.environment final.environment;
  record =
    name: run:
    environment
    // {
      name = "ruby.${name}";
      cwd = "../ruby-${final.version}";
      inherit run;
    };
  lookup =
    name: paths: libraries:
    # Named providers select distinct ELF scopes. Reject edits to their derived
    # summary rather than silently changing only runtime-expectation metadata.
    assert
      map toString final.runtime.libraries == map toString [
        final.runtime.openssl
        final.runtime.readline
        final.runtime.zlib
      ]
      || throw "Ruby runtime.libraries is derived; edit its named providers instead.";
    (outputs.rpaths {
      inherit
        paths
        libraries
        ;
      base = final.base;
      elfKinds = [ "runtime" ];
    })
    // {
      name = "ruby.lookup.${name}";
    };
in
{
  pname = "ruby";
  inherit
    base
    src
    version
    ;
  inherit (tools) bash coreutils;
  inherit doCheck nativeControls;
  libraries = {
    inherit
      openssl
      readline
      zlib
      ;
  };
  inherit
    libDir
    cStandard
    mkmfProbeFlags
    compileFlags
    extraWarnFlags
    patches
    restoreConfigScripts
    ;
  artifactName = "${final.pname}-${final.version}";
  dependencyProviders = lib.mapAttrs (name: _: final.runtime.${name}) final.libraries;
  buildFeatures = {
    shared = true;
    cStandard = final.cStandard;
    mkmfProbeFlags = final.mkmfProbeFlags;
    compileFlags = final.compileFlags;
    extraWarnFlags = final.extraWarnFlags;
  };
  sourceLayout.restoreConfigScripts = final.restoreConfigScripts;
  installedInterface = {
    libDir = final.libDir;
    nativeControls = final.nativeControls;
    nativeLine = "3";
  };
  gemPath = "lib/ruby/gems/${final.libDir}";
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = with final.libraries; [
      openssl
      readline
      zlib
    ];
    # GNU ld resolves transitive RUNPATHs inside its sysroot. Name Readline's
    # runtime providers for linking without exposing their headers or adding
    # their paths to the installed Ruby runtime.
    overrides.flags.NIX_CFLAGS_LINK = map (library: "-Wl,-rpath-link,${lib.getLib library}/lib") (
      final.libraries.readline.runtime.libraries or [ ]
    );
    # LC_ALL=C from the base overrides LANG; RDoc needs UTF-8 explicitly.
    overrides.values = {
      LANG = "C.UTF-8";
      LC_ALL = "C.UTF-8";
      CONFIG_SHELL = "${tools.bash}/bin/bash";
      lt_cv_deplibs_check_method = "pass_all";
    }
    //
      lib.optionalAttrs
        (final.cStandard != null || final.mkmfProbeFlags != [ ] || final.compileFlags != [ ])
        {
          cflags = lib.concatStringsSep " " (
            lib.optional (final.cStandard != null) "-std=${final.cStandard}"
            ++ final.mkmfProbeFlags
            ++ final.compileFlags
          );
        }
    // lib.optionalAttrs (final.extraWarnFlags != [ ]) {
      extra_warnflags = lib.concatStringsSep " " final.extraWarnFlags;
    };
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;

      compression = "gzip";
    })
    {
      name = "ruby.source-layout";
      # Match the canonical source placement: Ruby embeds assertion filenames.
      run = ''mv source "../ruby-${final.version}"'';
    }
    (record "patches" ''
      :
      ${lib.concatMapStringsSep "\n" (p: "${tools.patch}/bin/patch -p1 < ${p}") final.patches}
    '')
    (steps.prepareAutotools {
      name = "ruby.prepare";
      bash = tools.bash;

      base = final.base;
      cwd = "../ruby-${final.version}";
    })
    (record "configure" ''
      # Preserve canonical bare tool assignments in installed RbConfig. The
      # explicit environment supplies precisely these selected tool binaries.
      test "$LC_ALL" = C.UTF-8
      test "$(${tools.sed}/bin/sed -n '1p' configure)" = '#!${tools.bash}/bin/bash'
      ./configure --prefix="$out" --enable-shared \
        --with-readline-dir=${lib.getDev final.libraries.readline} \
        --with-openssl-dir=${lib.getDev final.libraries.openssl} --with-zlib-dir=${lib.getDev final.libraries.zlib} \
        AR=ar AS=as CC=cc CXX=c++ LD=ld NM=nm \
        OBJCOPY=objcopy RANLIB=ranlib STRIP=strip
    '')
    (record "build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    {
      name = "ruby.gem-home";
      run = ''mkdir -p "$out/${final.gemPath}"'';
    }
    (record "install" ''
      export GEM_HOME="$out/${final.gemPath}"
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
    '')
    (steps.split "ruby.finalize")
    (outputs.copyArtifacts { })
    (outputs.stripArchives {
      paths = [ "lib" ];
    })
    (outputs.strip {
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [
        "runtime"
        "relocatable"
      ];
    })
    {
      name = "ruby.relocate";
      tools = [
        tools.python
        tools.binutils
        tools.patchelf
      ];
      run = ''
        ${tools.python}/bin/python3 -B ${./owned/finalize.py} \
                '${
                  builtins.toJSON {
                    ar = "${tools.binutils}/bin/ar";
                    readelf = "${tools.binutils}/bin/readelf";
                    patchelf = "${tools.patchelf}/bin/patchelf";
                  }
                }' \
                "$out" "$TVP_ARTIFACT_ROOT" ${../perl/ordinary/elf-finalize.py}'';
    }
    {
      name = "ruby.consumer-metadata";
      # Explicit compatibility metadata: native hostOffset was the empty string.
      run = ''
        mkdir -p "$out/nix-support"
        cat > "$out/nix-support/setup-hook" <<'EOF'
        addGemPath() {
          addToSearchPath GEM_PATH $1/${final.gemPath}
        }
        addRubyLibPath() {
          addToSearchPath RUBYLIB $1/lib/ruby/site_ruby
          addToSearchPath RUBYLIB $1/lib/ruby/site_ruby/${final.libDir}
          addToSearchPath RUBYLIB $1/lib/ruby/site_ruby/${final.libDir}/${final.base.platform.system}
        }

        addEnvHooks "" addGemPath
        addEnvHooks "" addRubyLibPath
        EOF
      '';
    }
    (outputs.rpaths {
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    # Apply only the provider needed by each ELF scope. dlopen users declare
    # their provider too; base and own-library lookups survive the helper.
    (lookup "ruby"
      [
        "bin/ruby"
        "lib/libruby.so.${builtins.head (lib.splitString "-p" final.version)}"
      ]
      [ final.runtime.zlib ]
    )
    (lookup "readline"
      [ "lib/ruby/${final.libDir}/x86_64-linux/readline.so" ]
      [
        final.runtime.readline
      ]
    )
    (lookup "openssl" [ "lib/ruby/${final.libDir}/x86_64-linux/openssl.so" ] [ final.runtime.openssl ])
    (lookup "zlib" [ "lib/ruby/${final.libDir}/x86_64-linux/zlib.so" ] [ final.runtime.zlib ])
    (outputs.shebangs {
      paths = [
        "bin"
        "lib/ruby/gems"
      ];
      names = [ "ruby" ];
      selfInterpreter = "bin/ruby";
    })
    {
      name = "ruby.manuals";
      tools = [
        tools.python
        tools.gzip
      ];
      run = ''${tools.python}/bin/python3 -B ${./compress-manuals.py} "$out" ${tools.gzip}/bin/gzip'';
    }
    (outputs.development {
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      paths = [
        "lib/libruby.so"
        "lib/libruby.so.${lib.versions.majorMinor final.version}"
      ];
    })
    (outputs.checkPaths {
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  runtime = {
    inherit (final.libraries)
      openssl
      readline
      zlib
      ;
    libraries = [
      final.runtime.openssl
      final.runtime.readline
      final.runtime.zlib
    ];
  };
  development = output: {
    libraryDirectories = [ "${output}/lib" ];
    pkgconfig = [ "${output}/lib/pkgconfig" ];
    includeDirectories = [
      "include/ruby-${final.libDir}"
      "include/ruby-${final.libDir}/x86_64-linux"
    ];
  };
  buildEnvironment = import ./build-environment.nix { inherit lib; };

  tvp = {
    features = {
      consumerCStandard = final.cStandard;
      enumerableSum = lib.versionAtLeast final.version "2.4";
      yamlSafeLoad = lib.versionAtLeast final.version "2.1";
      doCheck = final.doCheck;
    };
  };
  passthru = {
    version = final.version;
    libDir = final.libDir;
    gemPath = final.gemPath;
    libPath = "lib/ruby/${final.libDir}";
    rubyEngine = "ruby";
    baseRuby = false;
    majorVersion = lib.versions.major final.version;
    minorVersion = lib.versions.minor final.version;
    teenyVersion = lib.versions.patch final.version;
    patchLevel = null;
  };
  meta = {
    description = "The Ruby programming language";
    homepage = "https://www.ruby-lang.org/";
    license = lib.licenses.ruby;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ruby";
  };
}

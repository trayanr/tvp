# Owned Ruby 4.0.6. Compiled own-prefix load paths require a single stage.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnutar,
  gzip,
  gnumake,
  gnused,
  python,
  binutils,
  patchelf,
  openssl,
  zlib,
  libyaml,
  libffi,
  rustc,
  yjit ? true,
  zjit ? true,
  libDir ? "${lib.versions.majorMinor version}.0",
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
  libraries = [
    openssl
    zlib
    libyaml
    libffi
  ];
  gemPath = "lib/ruby/gems/${libDir}";
in
final:
let
  environment = final.base.environment final.environment;
  record =
    name: run:
    environment
    // {
      name = "ruby.${name}";
      cwd = "../ruby-${version}";
      inherit run;
    };
  lookup =
    name: paths: libraries:
    # Named providers select distinct ELF scopes. Reject edits to their derived
    # summary rather than silently changing only runtime-expectation metadata.
    assert
      map toString final.runtime.libraries == map toString [
        final.runtime.openssl
        final.runtime.zlib
        final.runtime.libyaml
        final.runtime.libffi
      ]
      || throw "Ruby runtime.libraries is derived; edit runtime.openssl, zlib, libyaml or libffi instead.";
    (outputs.rpaths {
      inherit
        python
        binutils
        patchelf
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
    bash
    coreutils
    ;
  environment = {
    tools = [
      gnumake
      gnused
    ] ++ lib.optional (yjit || zjit) rustc;
    inherit libraries;
    # LC_ALL=C from the base overrides LANG; RDoc needs UTF-8 explicitly.
    overrides.values = {
      LANG = "C.UTF-8";
      LC_ALL = "C.UTF-8";
      CONFIG_SHELL = "${bash}/bin/bash";
      lt_cv_deplibs_check_method = "pass_all";
    };
  };
  plan = steps.sequence [
    (steps.unpack {
      inherit src gzip;
      tar = gnutar;
      compression = "gzip";
    })
    {
      name = "ruby.source-layout";
      # Match the canonical source placement: Ruby embeds assertion filenames.
      run = ''mv source "../ruby-${version}"'';
    }
    (steps.prepareAutotools {
      name = "ruby.prepare";
      inherit bash python;
      base = final.base;
      cwd = "../ruby-${version}";
    })
    (record "configure" ''
      # Preserve canonical bare tool assignments in installed RbConfig. The
      # explicit environment supplies precisely these selected tool binaries.
      test "$LC_ALL" = C.UTF-8
      test "$(${gnused}/bin/sed -n '1p' configure)" = '#!${bash}/bin/bash'
      ./configure --prefix="$out" --enable-shared \
        --with-openssl-dir=${lib.getDev openssl} --with-zlib-dir=${lib.getDev zlib} \
        ${if yjit then "--enable-yjit" else "--disable-yjit"} \
        ${if zjit then "--enable-zjit" else "--disable-zjit"} \
        AR=ar AS=as CC=cc CXX=c++ LD=ld NM=nm \
        OBJCOPY=objcopy RANLIB=ranlib STRIP=strip
    '')
    (record "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    ((record "check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" test-basic'') // { enabled = doCheck; })
    {
      name = "ruby.gem-home";
      run = ''mkdir -p "$out/${gemPath}"'';
    }
    (record "install" ''
      export GEM_HOME="$out/${gemPath}"
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" install
    '')
    {
      name = "ruby.consumer-metadata";
      # Explicit compatibility metadata: native hostOffset was the empty string.
      run = ''
        mkdir -p "$out/nix-support"
        cat > "$out/nix-support/setup-hook" <<'EOF'
        addGemPath() {
          addToSearchPath GEM_PATH $1/${gemPath}
        }
        addRubyLibPath() {
          addToSearchPath RUBYLIB $1/lib/ruby/site_ruby
          addToSearchPath RUBYLIB $1/lib/ruby/site_ruby/${libDir}
          addToSearchPath RUBYLIB $1/lib/ruby/site_ruby/${libDir}/${base.stdenv.targetPlatform.system}
        }

        addEnvHooks "" addGemPath
        addEnvHooks "" addRubyLibPath
        EOF
      '';
    }
    (outputs.strip {
      inherit python binutils;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [
        "runtime"
        "relocatable"
      ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    # Apply only the provider needed by each ELF scope. dlopen users declare
    # their provider too; base and own-library lookups survive the helper.
    (lookup "ruby" [
      "bin/ruby"
      "lib/libruby.so.4.0.6"
    ] [ final.runtime.zlib ])
    (lookup "openssl" [ "lib/ruby/${libDir}/x86_64-linux/openssl.so" ] [ final.runtime.openssl ])
    (lookup "zlib" [ "lib/ruby/${libDir}/x86_64-linux/zlib.so" ] [ final.runtime.zlib ])
    (lookup "yaml" [ "lib/ruby/${libDir}/x86_64-linux/psych.so" ] [ final.runtime.libyaml ])
    (lookup "ffi" [
      "lib/ruby/gems/${libDir}/extensions/x86_64-linux/${libDir}/fiddle-1.1.8/fiddle.so"
    ] [ final.runtime.libffi ])
    (outputs.shebangs {
      inherit python;
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
        python
        gzip
      ];
      run = ''${python}/bin/python3 -B ${./compress-manuals.py} "$out" ${gzip}/bin/gzip'';
    }
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libruby.so"
        "lib/libruby.so.4.0"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  runtime = {
    inherit
      openssl
      zlib
      libyaml
      libffi
      ;
    libraries = [
      final.runtime.openssl
      final.runtime.zlib
      final.runtime.libyaml
      final.runtime.libffi
    ];
  };
  development = {
    includeDirectories = [
      "include/ruby-${libDir}"
      "include/ruby-${libDir}/x86_64-linux"
    ];
  };
  buildEnvironment = import ./build-environment.nix { inherit lib; };

  tvp = {
    features = {
      enumerableSum = true;
      yamlSafeLoad = true;
      inherit doCheck;
    };
    jit = {
      inherit yjit zjit;
    };
  };
  passthru = {
    inherit version libDir gemPath;
    libPath = "lib/ruby/${libDir}";
    rubyEngine = "ruby";
    baseRuby = false;
    majorVersion = lib.versions.major version;
    minorVersion = lib.versions.minor version;
    teenyVersion = lib.versions.patch version;
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

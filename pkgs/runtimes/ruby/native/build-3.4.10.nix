# Owned Ruby 3.4.10. Compiled own-prefix load paths require a single stage.
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
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  python,
  binutils,
  patchelf,
  openssl,
  zlib,
  libyaml,
  libffi,
  rustc,
  yjit ? true,
  libDir ? "${lib.versions.majorMinor version}.0",
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;

in
final:
let
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
        final.runtime.zlib
        final.runtime.libyaml
        final.runtime.libffi
      ]
      || throw "Ruby runtime.libraries is derived; edit runtime.openssl, zlib, libyaml or libffi instead.";
    (outputs.rpaths {
      inherit (final.tools) python binutils patchelf;
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
    bash
    coreutils
    ;
  tools = {
    inherit
      rustc
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
      gnutar
      gzip
      python
      binutils
      patchelf
      ;
  };
  libraries = {
    inherit
      openssl
      zlib
      libyaml
      libffi
      ;
  };
  inherit libDir;
  gemPath = "lib/ruby/gems/${final.libDir}";
  environment = {
    tools = [
      final.tools.gnumake
      final.tools.sed
      final.tools.grep
      final.tools.gawk
      final.tools.diffutils
      final.tools.findutils
    ] ++ lib.optional final.tvp.jit.yjit final.tools.rustc;
    libraries = with final.libraries; [
      openssl
      zlib
      libyaml
      libffi
    ];
    # LC_ALL=C from the base overrides LANG; RDoc needs UTF-8 explicitly.
    overrides.values = {
      LANG = "C.UTF-8";
      LC_ALL = "C.UTF-8";
      CONFIG_SHELL = "${final.bash}/bin/bash";
      lt_cv_deplibs_check_method = "pass_all";
    };
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit (final.tools) gzip findutils;
      tar = final.tools.gnutar;
      compression = "gzip";
    })
    {
      name = "ruby.source-layout";
      # Match the canonical source placement: Ruby embeds assertion filenames.
      run = ''mv source "../ruby-${final.version}"'';
    }
    (steps.prepareAutotools {
      name = "ruby.prepare";
      bash = final.bash;
      inherit (final.tools) python;
      base = final.base;
      cwd = "../ruby-${final.version}";
    })
    (record "configure" ''
      # Preserve canonical bare tool assignments in installed RbConfig. The
      # explicit environment supplies precisely these selected tool binaries.
      test "$LC_ALL" = C.UTF-8
      test "$(${final.tools.sed}/bin/sed -n '1p' configure)" = '#!${final.bash}/bin/bash'
      ./configure --prefix="$out" --enable-shared \
        --with-openssl-dir=${lib.getDev final.libraries.openssl} --with-zlib-dir=${lib.getDev final.libraries.zlib} \
        ${if final.tvp.jit.yjit then "--enable-yjit" else "--disable-yjit"} \
        AR=ar AS=as CC=cc CXX=c++ LD=ld NM=nm \
        OBJCOPY=objcopy RANLIB=ranlib STRIP=strip
    '')
    (record "build" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (
      (record "check" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" test-basic'')
      // {
        enabled = final.tvp.features.doCheck;
      }
    )
    {
      name = "ruby.gem-home";
      run = ''mkdir -p "$out/${final.gemPath}"'';
    }
    (record "install" ''
      export GEM_HOME="$out/${final.gemPath}"
      ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
    '')
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
    (outputs.strip {
      inherit (final.tools) python binutils;
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
      inherit (final.tools) python binutils patchelf;
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
      "lib/libruby.so.${final.version}"
    ] [ final.runtime.zlib ])
    (lookup "openssl" [ "lib/ruby/${final.libDir}/x86_64-linux/openssl.so" ] [ final.runtime.openssl ])
    (lookup "zlib" [ "lib/ruby/${final.libDir}/x86_64-linux/zlib.so" ] [ final.runtime.zlib ])
    (lookup "yaml" [ "lib/ruby/${final.libDir}/x86_64-linux/psych.so" ] [ final.runtime.libyaml ])
    (lookup "ffi" [
      "lib/ruby/${final.libDir}/x86_64-linux/fiddle.so"
    ] [ final.runtime.libffi ])
    (outputs.shebangs {
      inherit (final.tools) python;
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
        final.tools.python
        final.tools.gzip
      ];
      run = ''${final.tools.python}/bin/python3 -B ${../compress-manuals.py} "$out" ${final.tools.gzip}/bin/gzip'';
    }
    (outputs.development {
      inherit (final.tools) python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      inherit (final.tools) python;
      paths = [
        "lib/libruby.so"
        "lib/libruby.so.3.4"
      ];
    })
    (outputs.checkPaths {
      inherit (final.tools) python binutils patchelf;
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
  development = output: {
    libraryDirectories = [ "${output}/lib" ];
    pkgconfig = [ "${output}/lib/pkgconfig" ];
    includeDirectories = [
      "include/ruby-${final.libDir}"
      "include/ruby-${final.libDir}/x86_64-linux"
    ];
  };
  buildEnvironment = import ../build-environment.nix { inherit lib; };

  tvp = {
    features = {
      enumerableSum = true;
      yamlSafeLoad = true;
      inherit doCheck;
    };
    jit = {
      inherit yjit;
    };
  };
  passthru = {
    version = final.version;
    libDir = final.libDir;
    gemPath = final.gemPath;
    libPath = "lib/ruby/${final.libDir}";
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

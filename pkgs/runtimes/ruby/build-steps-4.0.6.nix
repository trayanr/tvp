# Opt-in native recipe; the canonical 4.0 builder remains the control.
{
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
  steps = import ../../../lib/build-steps.nix;
  helpers = import ../../../lib/native-steps.nix { inherit lib; };
  output = import ../../../lib/native-output-steps.nix { inherit lib; };
  libraries = [
    openssl
    zlib
    libyaml
    libffi
  ];
  gemPath = "lib/ruby/gems/${libDir}";
  record = name: run: {
    name = "ruby.${name}";
    tools = [
      gnumake
      gnused
    ] ++ lib.optional (yjit || zjit) rustc;
    inherit libraries;
    env.LANG = "C.UTF-8";
    cwd = "../ruby-${version}";
    inherit run;
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
  plan = steps.sequence [
    (helpers.unpack {
      inherit src gzip;
      tar = gnutar;
      compression = "gzip";
    })
    {
      name = "ruby.source-layout";
      # Match the canonical source placement: Ruby embeds assertion filenames.
      run = ''mv source "../ruby-${version}"'';
    }
    (record "configure" ''
      # Retain configurePhase's selected shell/libtool corrections and tool
      # assignments: these also become part of installed RbConfig.
      set +u
      export lt_cv_deplibs_check_method=pass_all
      while IFS= read -r -d $'\0' script; do fixLibtool "$script"; done < <(find . -name ltmain.sh -print0)
      patchShebangs --build ./configure
      touch -r ./configure "$TMPDIR/configure-mtime"
      sed -i 's_/usr/bin/file_file_g' ./configure
      touch -r "$TMPDIR/configure-mtime" ./configure
      set -u
      ./configure --prefix="$out" --enable-shared \
        --with-openssl-dir=${lib.getDev openssl} --with-zlib-dir=${lib.getDev zlib} \
        ${if yjit then "--enable-yjit" else "--disable-yjit"} \
        ${if zjit then "--enable-zjit" else "--disable-zjit"} \
        AR="$AR" AS="$AS" CC="$CC" CXX="$CXX" LD="$LD" NM="$NM" \
        OBJCOPY="$OBJCOPY" RANLIB="$RANLIB" STRIP="$STRIP"
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
    (output.strip {
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
    (output.rpaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (output.shebangs {
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
    (output.checkSymlinks {
      inherit python;
      paths = [
        "lib/libruby.so"
        "lib/libruby.so.4.0"
      ];
    })
    (output.checkPaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  runtime.libraries = map lib.getLib libraries;
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

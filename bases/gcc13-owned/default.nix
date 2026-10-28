# The borrowed gcc13 base is the bootstrap parent. Intermediate stages are
# explicit so runtime ownership can be checked
# independently of the tools which performed the initial builds.
{
  pkgs,
  tvp,
  builtBy,
}:
let
  inherit (pkgs) lib;
  # The seed generation must not follow canonical packages through `default`.
  p = tvp.variants.gcc13;
  platform = tvp.lib.platforms.forStdenv builtBy.stdenv;
  mkStdenv = import ../stdenv {
    inherit lib platform;
    inherit (pkgs) config;
    nixpkgsPath = pkgs.path;
  };
  wrap = args: import ../wrappers ({ inherit platform; } // args);
  # Reusing a versioned recipe must not keep its parent's base metadata.
  rebuild =
    stage: package: args:
    (package.override args).overrideAttrs (old: {
      passthru = old.passthru // {
        tvp = (removeAttrs old.passthru.tvp [ "variant" ]) // {
          base = stage;
          canonical = false;
        };
      };
    });
  libc = p.glibc_2_39;
  firstWrappers = wrap {
    inherit lib libc;
    stdenv = builtBy.stdenv;
    gcc = p.gcc_13_3_0;
    binutils = p.binutils_2_42;
    bash = pkgs.bash;
    perl = p.perl_5_44_0;
    cRuntime = false;
  };
  libcStage = mkStdenv {
    name = "tvp-gcc13-libc-bootstrap";
    cc = firstWrappers.cc;
    inherit (builtBy.stdenv) initialPath shell;
  };
  # C-only bootstrap variants avoid retaining the parent's C++ runtime. Full
  # C++ bindings and gprofng are built with the resulting owned compiler below.
  bootstrapNcurses =
    (rebuild "gcc13-libc-bootstrap" p.ncurses_6_6 {
      stdenv = libcStage;
    }).overrideAttrs
      (old: {
        configureFlags = old.configureFlags ++ [
          "--without-cxx"
          "--without-cxx-binding"
        ];
        # This one bootstrap variant supplies C libraries before an owned shell
        # exists. Its shell config helper is restored by the full ncurses build.
        postInstall = ''rm -f "$out/bin/ncursesw6-config"'';
        passthru = old.passthru // {
          tvp = old.passthru.tvp // {
            features = old.passthru.tvp.features // {
              cxx = false;
            };
          };
        };
      });
  bootstrapBash = rebuild "gcc13-libc-bootstrap" p.bash_5_2_37 {
    stdenv = libcStage;
    ncurses = bootstrapNcurses;
  };
  shellWrappers = wrap {
    inherit lib libc;
    stdenv = libcStage;
    gcc = p.gcc_13_3_0;
    binutils = p.binutils_2_42;
    bash = bootstrapBash;
    perl = p.perl_5_44_0;
    cRuntime = false;
  };
  shellStage = mkStdenv {
    name = "tvp-gcc13-shell-bootstrap";
    cc = shellWrappers.cc;
    initialPath = map (
      tool: if tool.pname == "bash" then bootstrapBash else tool
    ) builtBy.stdenv.initialPath;
    shell = "${bootstrapBash}/bin/bash";
  };
  boot = rebuild "gcc13-shell-bootstrap";
  runtime = rec {
    gmp = boot p.gmp_6_3_0 {
      stdenv = shellStage;
      cxx = false;
    };
    mpfr =
      (boot p.mpfr_4_2_1 {
        stdenv = shellStage;
        inherit gmp;
      }).overrideAttrs
        {
          # Upstream's test executables link libquadmath. It is a test input from
          # the bootstrap compiler, not a dependency of installed libmpfr.
          preCheck = ''
            export LD_LIBRARY_PATH=${p.gcc_13_3_0}/lib
          '';
        };
    mpc = boot p.mpc_1_3_1 {
      stdenv = shellStage;
      inherit gmp mpfr;
    };
    isl = boot p.isl_0_20 {
      stdenv = shellStage;
      inherit gmp;
    };
    zlib = boot p.zlib_1_3_2 {
      stdenv = shellStage;
      mkTests = p.zlib_1_3_2.mkTests.override {
        pkgs = pkgs // {
          stdenv = shellStage;
        };
      };
    };
    xz = boot p.xz_5_8_3 { stdenv = shellStage; };
    zstd = boot p.zstd_1_5_6 {
      stdenv = shellStage;
      inherit zlib xz;
    };
    libxcrypt = boot p.libxcrypt_4_4_36 { stdenv = shellStage; };
  };
  bootstrapBinutils = boot p.binutils_2_42 {
    stdenv = shellStage;
    inherit (runtime) zlib zstd;
    gprofng = false;
  };
  bootstrapTools = rec {
    attr = boot p.attr_2_5_2 { stdenv = shellStage; };
    acl = boot p.acl_2_3_2 {
      stdenv = shellStage;
      inherit attr;
    };
    gnused = boot p.gnused_4_9 {
      stdenv = shellStage;
      inherit acl;
    };
  };
  gccStage = mkStdenv {
    name = "tvp-gcc13-tool-bootstrap";
    cc = shellWrappers.cc;
    initialPath = map (
      tool: if tool.pname == "gnused" then bootstrapTools.gnused else tool
    ) shellStage.initialPath;
    inherit (shellStage) shell;
  };
  gcc = rebuild "gcc13-tool-bootstrap" p.gcc_13_3_0 {
    stdenv = gccStage;
    binutils = bootstrapBinutils;
    glibc = libc;
    inherit (runtime)
      gmp
      mpfr
      mpc
      isl
      zlib
      zstd
      libxcrypt
      ;
  };
  compilerWrappers = wrap {
    inherit lib libc gcc;
    stdenv = shellStage;
    binutils = bootstrapBinutils;
    bash = bootstrapBash;
    perl = p.perl_5_44_0;
  };
  compilerStage = mkStdenv {
    name = "tvp-gcc13-compiler-bootstrap";
    cc = compilerWrappers.cc;
    inherit (shellStage) initialPath shell;
  };
  onCompiler = rebuild "gcc13-compiler-bootstrap";
  libraries = rec {
    inherit (runtime)
      zlib
      xz
      zstd
      libxcrypt
      ;
    gmp = onCompiler p.gmp_6_3_0 { stdenv = compilerStage; };
    mpfr = onCompiler p.mpfr_4_2_1 {
      stdenv = compilerStage;
      inherit gmp;
    };
    mpc = onCompiler p.mpc_1_3_1 {
      stdenv = compilerStage;
      inherit gmp mpfr;
    };
    isl = onCompiler p.isl_0_20 {
      stdenv = compilerStage;
      inherit gmp;
    };
    ncurses = onCompiler p.ncurses_6_6 { stdenv = compilerStage; };
    readline = onCompiler p.readline_8_3 {
      stdenv = compilerStage;
      inherit ncurses;
      mkTests = p.readline_8_3.mkTests.override {
        pkgs = pkgs // {
          stdenv = compilerStage;
          glibc = libc;
        };
      };
    };
    attr = onCompiler p.attr_2_5_2 { stdenv = compilerStage; };
    acl = onCompiler p.acl_2_3_2 {
      stdenv = compilerStage;
      inherit attr;
    };
    pcre2 = onCompiler p.pcre2_10_44 { stdenv = compilerStage; };
  };
  floor = {
    coreutils = onCompiler p.coreutils_9_5 {
      stdenv = compilerStage;
      inherit (libraries) gmp acl;
    };
    findutils = onCompiler p.findutils_4_10_0 {
      stdenv = compilerStage;
      coreutils = floor.coreutils;
    };
    diffutils = onCompiler p.diffutils_3_10 {
      stdenv = compilerStage;
      coreutils = floor.coreutils;
    };
    gnused = onCompiler p.gnused_4_9 {
      stdenv = compilerStage;
      inherit (libraries) acl;
    };
    gnugrep = onCompiler p.gnugrep_3_11 {
      stdenv = compilerStage;
      inherit (libraries) pcre2;
    };
    gawk = onCompiler p.gawk_5_2_2 {
      stdenv = compilerStage;
      inherit (libraries)
        gmp
        mpfr
        readline
        ncurses
        ;
    };
    gnutar = onCompiler p.gnutar_1_35 {
      stdenv = compilerStage;
      inherit (libraries) acl attr;
    };
    gzip = onCompiler p.gzip_1_13 {
      stdenv = compilerStage;
      gnugrep = floor.gnugrep;
    };
    bzip2 = onCompiler p.bzip2_1_0_8 { stdenv = compilerStage; };
    gnumake = onCompiler p.gnumake_4_4_1 { stdenv = compilerStage; };
    bash = onCompiler p.bash_5_2_37 {
      stdenv = compilerStage;
      inherit (libraries) ncurses;
    };
    patch = onCompiler p.patch_2_7_6 { stdenv = compilerStage; };
    inherit (runtime) xz;
    file = onCompiler p.file_5_45 {
      stdenv = compilerStage;
      inherit (runtime) zlib xz zstd;
      inherit (floor) bzip2;
    };
  };
  floorNames = [
    "coreutils"
    "findutils"
    "diffutils"
    "gnused"
    "gnugrep"
    "gawk"
    "gnutar"
    "gzip"
    "bzip2"
    "gnumake"
    "bash"
    "patch"
    "xz"
    "file"
  ];
  initialPath = map (name: floor.${name}) floorNames;
  floorStage = mkStdenv {
    name = "tvp-gcc13-floor-bootstrap";
    cc = compilerWrappers.cc;
    inherit initialPath;
    shell = "${floor.bash}/bin/bash";
  };
  # gprofng installs Perl programs, so Perl is a runtime dependency here.
  perl = rebuild "gcc13-floor-bootstrap" p.perl_5_44_0 { stdenv = floorStage; };
  binutils = rebuild "gcc13-floor-bootstrap" p.binutils_2_42 {
    stdenv = floorStage;
    inherit perl;
    inherit (runtime) zlib zstd;
  };
  libcTools = libc.mkTools {
    stdenv = floorStage;
    bash = floor.bash;
    inherit perl;
  };
  finalLibc = libc // {
    bin = libcTools;
  };
  wrappers = wrap {
    inherit
      lib
      gcc
      binutils
      ;
    stdenv = floorStage;
    libc = finalLibc;
    bash = floor.bash;
    inherit perl;
    wrapGprofng = true;
    supportMetadata = true;
  };
  stdenv = mkStdenv {
    name = "tvp-gcc13-owned-stdenv";
    cc = wrappers.cc;
    inherit initialPath;
    shell = "${floor.bash}/bin/bash";
  };
  consumerValidation = import ./tests/consumers.nix {
    inherit pkgs tvp stdenv;
    components = {
      inherit perl floor libraries;
      libc = finalLibc;
    };
  };
  buildToolValidation = import ./tests/build-tools.nix {
    inherit pkgs tvp stdenv;
    components = {
      inherit perl floor libraries;
      libc = finalLibc;
    };
  };
  autotoolsValidation = import ./tests/autotools.nix { inherit pkgs tvp; };
in
(tvp.lib.bases.mkBase {
  name = "gcc13-owned";
  cc = "13.3.0";
  binutils = "2.42";
  libc = "2.39";
  builtBy = builtBy.name;
  inherit stdenv;
  floor = floorNames;
})
// {
  mkExtraTests =
    base:
    import ./tests {
      inherit pkgs base;
      tvpLib = tvp.lib;
    };
  components = {
    inherit
      gcc
      binutils
      floor
      libraries
      perl
      ;
    libc = finalLibc;
  };
  consumerTests = consumerValidation.tests;
  consumerPackages = consumerValidation.packages;
  inherit buildToolValidation autotoolsValidation;
  ownership = {
    roots = [
      stdenv
      wrappers.cc
      wrappers.bintools
      libcTools
    ];
    allowedRuntimePaths =
      [
        stdenv
        wrappers.cc
        wrappers.bintools
        gcc
        binutils
        libc
        libcTools
        perl
        bootstrapBash
        bootstrapNcurses
        bootstrapBinutils
        compilerWrappers.cc
        compilerWrappers.bintools
        p."linux-headers_6_9"
      ]
      ++ lib.attrValues runtime
      ++ lib.attrValues bootstrapTools
      ++ lib.attrValues libraries
      ++ lib.attrValues floor
      ++ stdenv.defaultNativeBuildInputs;
  };
  bootstrap = {
    parent = builtBy.name;
    # Record the tools actually selected by production recipes, not a parallel
    # list of tools which is only exercised by validation builds.
    buildTools = {
      inherit (binutils.tvp.deps) pkg-config;
      inherit (gcc.tvp.deps) texinfo which;
      inherit (libc.tvp.deps) bison;
      python-minimal = libc.tvp.deps.python3Minimal;
    };
    inherit
      libcStage
      shellStage
      gccStage
      compilerStage
      floorStage
      ;
    inherit bootstrapNcurses bootstrapBash bootstrapBinutils;
    inherit bootstrapTools;
    inherit runtime;
  };
}

# Explicit provider roles for existing check/test dependency inventories.
{
  pkgs,
  tvp,
  legacyBases,
}:
{
  owned-jdk-source-stage = tvp.checks.owned-jdk-source-stage.support;
  owned-x11-extensions = tvp.checks.owned-x11-extensions.support // {
    package = tvp.packages.libxext;
    bash = tvp.packages.libxext.specification.bash;
    coreutils = tvp.packages.libxext.specification.coreutils;
  };
  owned-x11 = {
    package = tvp.packages.xorgproto;
    bash = tvp.packages.xorgproto.specification.bash;
    coreutils = tvp.packages.xorgproto.specification.coreutils;
  };
  build-step-runner = {
    inherit (tvp.packages)
      bash
      coreutils
      zlib
      libffi
      ;
    environment = legacyBases.gcc_16_2_0.stdenv;
    compiler = legacyBases.gcc_16_2_0.stdenv.cc;
    python = tvp.packages.python_3;
  };
  named-outputs =
    {
      inherit (tvp.packages) bash coreutils;
    }
    // pkgs.lib.listToAttrs (
      pkgs.lib.imap0 (
        i: p: pkgs.lib.nameValuePair "floor${toString i}" p
      ) legacyBases.gcc_16_2_0.stdenv.initialPath
    );
  reusable-output = {
    inherit (tvp.packages) bash;
    python = tvp.packages.python_3;
    binutils = tvp.packages.binutils_2;
    environment = legacyBases.gcc_16_2_0.stdenv;
    compiler = legacyBases.gcc_16_2_0.stdenv.cc;
  };
  ruby-build-steps = {
    inherit (tvp.packages) gzip;
    python = tvp.packages.python_3;
    binutils = tvp.packages.binutils_2;
    patchelf = tvp.packages.patchelf_0;
    environment = legacyBases.gcc_16_2_0.stdenv;
    compiler = legacyBases.gcc_16_2_0.stdenv.cc;
  };
  audit-contracts.python = tvp.packages.python_3;
  bootstrap-audit-contracts = {
    inherit (tvp.packages) bash coreutils;
    python = tvp.packages.python_3;
    environment = legacyBases.gcc_16_2_0.stdenv;
    compiler = legacyBases.gcc_16_2_0.stdenv.cc;
  };
  owned-mpc = {
    mpc = tvp.canonical.mpc_1_4_1;
    compatibleMpfr = tvp.packages.mpfr_4_2_1;
    bash = tvp.canonical.mpc_1_4_1.specification.base.shell;
    coreutils = tvp.canonical.mpc_1_4_1.specification.base.coreutils;
    inherit (tvp.packages) pkg-config;
    gnumake = tvp.canonical.mpc_1_4_1.tvp.deps.gnumake;
    patchelf = tvp.canonical.mpc_1_4_1.tvp.deps.patchelf;
    grep = tvp.canonical.mpc_1_4_1.tvp.deps.grep;
    compiler = tvp.canonical.mpc_1_4_1.specification.base.compiler;
  };
  owned-json-c = {
    json = tvp.packages.json-c_0;
    inherit (tvp.packages)
      bash
      coreutils
      ;
    cmake = tvp.canonical.json-c_0_19.tvp.deps.cmake;
    gnumake = tvp.canonical.json-c_0_19.tvp.deps.gnumake;
    pkg-config = tvp.canonical.json-c_0_19.specification.base.tools.pkg-config;
    patchelf = tvp.canonical.json-c_0_19.tvp.deps.patchelf;
    environment = tvp.canonical.json-c_0_19.compiler;
    compiler = tvp.canonical.json-c_0_19.tvp.cc;
  };
  owned-ruby = {
    ruby = tvp.canonical.ruby_4_0_6;
    compatibleZlib = tvp.packages.zlib_1_3_1;
    inherit (tvp.packages) bash coreutils;
    make = tvp.packages.gnumake;
    pkgConfig = tvp.packages.pkg-config;
    python = tvp.packages.python-build_3;
    sed = tvp.packages.gnused;
    environment = legacyBases.gcc_16_2_0.stdenv;
    compiler = legacyBases.gcc_16_2_0.stdenv.cc;
  };
  owned-zstd = {
    inherit (tvp.packages) bash coreutils;
    pkgConfig = tvp.packages.pkg-config;
    zstd = tvp.packages.zstd_1;
    compatibleZlib = tvp.packages.zlib_1_3_1;
    compatibleXz = tvp.packages.xz_5_6_4;
    environment = tvp.canonical.zstd_1_5_7.compiler;
    compiler = tvp.canonical.zstd_1_5_7.tvp.cc;
  };
  owned-fontconfig = {
    inherit (tvp.canonical.fontconfig_2_18_3.specification) bash coreutils;
    grep = tvp.canonical.fontconfig_2_18_3.specification.base.tools.grep;
    pkgConfig = tvp.canonical.fontconfig_2_18_3.specification.pkg-config;
    fontconfig = tvp.packages.fontconfig_2;
    compatibleExpat = pkgs.expat;
    compiler = tvp.canonical.fontconfig_2_18_3.compiler;
    binutils = tvp.canonical.fontconfig_2_18_3.compiler.bintools;
    libc = tvp.canonical.fontconfig_2_18_3.compiler.libc;
  };
  native-meson = {
    fontconfig = tvp.packages.fontconfig_2;
    inherit (tvp.packages)
      bash
      coreutils
      meson
      ninja
      pkg-config
      ;
    environment = legacyBases.gcc_16_2_0.stdenv;
    compiler = legacyBases.gcc_16_2_0.stdenv.cc;
  };
  dependency-inventory.python = tvp.packages.python_3;
  test-runner.python = tvp.packages.python_3;
  cli-interpreters.python = tvp.packages.python_3;
  cli-packaging = {
    inherit (tvp.packages) bash coreutils gnused;
    python = tvp.packages.python_3;
    shellcheck = pkgs.shellcheck-minimal;
  };
  cli-builders = {
    inherit (tvp.packages) bash coreutils;
    shellcheck = pkgs.shellcheck-minimal;
  };
  upstream-tracking = {
    inherit (tvp.packages)
      bash
      coreutils
      curl
      git
      gnugrep
      gnused
      ;
    jq = tvp.packages.jq;
  };
  cli-runtime = {
    bash = tvp.packages.bash;
    inherit (tvp.packages)
      coreutils
      curl
      git
      gnugrep
      gnused
      gawk
      ;
  };
  package-runtime-ownership.python = tvp.packages.python_3;
  package-runtime-ownership-latest.python = tvp.packages.python_3;
}

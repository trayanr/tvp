# GCC16 consumer generation; the libc, tool floor and construction stay pinned.
{
  pkgs,
  tvp,
  parent,
  compiler,
  inputs,
}:
let
  patchelf = parent.fixupTools.patchelf;
  components = parent.components // {
    gcc = compiler;
  };
  # Actual compiler runtime dependencies, including transitive MPC/MPFR and
  # binutils compression libraries. No store-wide ownership exemption.
  runtimeInputs = with inputs; [
    binutils_2_42
    gmp_6_3_0
    mpfr_4_2_1
    mpfr_4_2_2
    mpc_1_3_1
    isl_0_28
    zlib_1_3_2
    zstd_1_5_6
    xz_5_8_3
    libxcrypt_4_4_36
  ];
  responseExpander = import ../wrappers/expand-response-params {
    inherit (parent) stdenv;
  };
  wrappers = import ../wrappers {
    inherit (pkgs) lib;
    inherit (parent) platform stdenv;
    inherit (components)
      gcc
      binutils
      libc
      perl
      ;
    bash = components.floor.bash;
    coreutils = components.floor.coreutils;
    protocolRevision = 3;
    inherit responseExpander;
    wrapGprofng = true;
    supportMetadata = true;
  };
  mkStdenv = import ../stdenv {
    inherit (pkgs) lib config;
    inherit (parent) platform;
  };
  stdenv = mkStdenv {
    name = "tvp-gcc16-owned-stdenv";
    cc = wrappers.cc;
    inherit (parent.stdenv) initialPath shell;
    fixupInputs = [
      patchelf
      ../stdenv/hooks/shrink-rpaths-v3.sh
    ];
  };
in
(tvp.lib.bases.mkBase {
  name = "gcc16-owned";
  cc = "16.2.0";
  inherit (parent)
    binutils
    libc
    floor
    ;
  builtBy = "internal:${parent.name}";
  inherit stdenv;
})
// {
  inherit components runtimeInputs;
  fixupTools = {
    inherit patchelf responseExpander;
  };
  ownership = {
    roots = [ stdenv ];
    allowedRuntimePaths =
      parent.ownership.allowedRuntimePaths
      ++ [
        stdenv
        wrappers.cc
        wrappers.bintools
        patchelf
        responseExpander
        compiler
      ]
      ++ runtimeInputs
      ++ stdenv.defaultNativeBuildInputs;
  };
  mkExtraTests =
    base:
    (parent.mkExtraTests base)
    // (import ./tests.nix {
      inherit
        pkgs
        base
        parent
        compiler
        ;
      tvpLib = tvp.lib;
    });
}

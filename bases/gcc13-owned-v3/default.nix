# A consumer protocol revision, reusing the frozen v2 compiler and tool floor.
{
  pkgs,
  tvp,
  builtBy,
  previous,
  patchelf,
}:
let
  parent = builtBy;
  inherit (parent) components;
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
    name = "tvp-gcc13-owned-v3-stdenv";
    cc = wrappers.cc;
    inherit (parent.stdenv) initialPath shell;
    fixupInputs = [
      patchelf
      ../stdenv/hooks/shrink-rpaths-v3.sh
    ];
  };
in
(tvp.lib.bases.mkBase {
  name = "gcc13-owned-v3";
  inherit (parent)
    cc
    binutils
    libc
    floor
    ;
  builtBy = "internal:${parent.name}";
  inherit stdenv;
})
// {
  inherit components;
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
      ]
      ++ stdenv.defaultNativeBuildInputs;
  };
  mkExtraTests =
    base:
    (previous.mkExtraTests base)
    // (import ./tests {
      inherit pkgs base;
      tvpLib = tvp.lib;
    });
}

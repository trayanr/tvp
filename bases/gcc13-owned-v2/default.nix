{
  pkgs,
  tvp,
  builtBy,
  patchelf,
}:
let
  parent = builtBy;
  mkStdenv = import ../stdenv {
    inherit (pkgs) lib config;
    inherit (parent) platform;
  };
  stdenv = mkStdenv {
    name = "tvp-gcc13-owned-v2-stdenv";
    inherit (parent.stdenv) cc initialPath shell;
    fixupInputs = [
      patchelf
      ../stdenv/hooks/shrink-rpaths-v2.sh
    ];
  };
in
(tvp.lib.bases.mkBase {
  name = "gcc13-owned-v2";
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
  inherit (parent) components;
  fixupTools = {
    inherit patchelf;
  };
  ownership = {
    roots = [ stdenv ];
    allowedRuntimePaths =
      parent.ownership.allowedRuntimePaths
      ++ [
        stdenv
        patchelf
      ]
      ++ stdenv.defaultNativeBuildInputs;
  };
  mkExtraTests =
    base:
    import ./tests {
      inherit pkgs base;
      tvpLib = tvp.lib;
    };
}

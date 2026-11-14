# Historical construction recipe and declared-broken releases. No owned constructor.
{ pkgs, tvp }:
let
  definitions = tvp.lib.packages.mkDefs {
    "1.4.17" = {
      builder = ./build-1.4.17.nix;
      base = tvp.bases.default;
      deps = { };
    };
    "1.4.19" = {
      builder = ./build-1.4.17.nix;
      base = tvp.bases.default;
      deps = { };
      # Preserve the historical gnulib dialect choice exactly.
      opts.cStandard = "gnu17";
    };
    "1.4.21" = {
      builder = ./build-1.4.17.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };
in
{
  pname = "m4";
  infra = {
    inherit (pkgs) lib fetchurl;
  };
  versionTable = tvp.lib.packages.mkTable (import ./releases.nix { defs = definitions; });
  extraArgs.mkTests = pkgs.lib.makeOverridable (
    { pkgs }:
    m4:
    import ../tests/retained.nix {
      inherit m4;
      tvpLib = tvp.lib;
      pkgs = tvp.lib.tests.withBase {
        inherit pkgs;
        base.stdenv = m4.stdenv;
      };
    }
  ) { inherit pkgs; };
  packageMeta.upstream = {
    type = "directory-index";
    url = "https://mirrors.kernel.org/gnu/m4/";
    pattern = "m4-[0-9][^\"]*\\.tar\\.gz";
    normalise =
      file:
      if pkgs.lib.hasPrefix "m4-" file && pkgs.lib.hasSuffix ".tar.gz" file then
        pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "m4-" file)
      else
        null;
    include = version: builtins.match "[0-9].*" version != null;
  };
}

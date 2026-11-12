{
  pkgs,
  tvpLib,
  package,
}:
(import ./. {
  inherit pkgs tvpLib;
  tcl = package;
  pkg-config = package.specification.tools.pkgConfig;
})
// import ./native-contract-9.1.nix { inherit package; }
// pkgs.lib.optionalAttrs (package.tvp.features.doCheck or true) {
  upstream = import ./upstream.nix { inherit package; };
}

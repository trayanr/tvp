# Every version uses the same core/XS/embed suite. Split procedures add explicit
# final-prefix checks without forking behavior tests per version-start builder.
{
  pkgs,
  tvpLib,
  package,
}:
(import ./native-default.nix { inherit pkgs tvpLib package; })
// import ./ordinary-paths.nix { inherit package; }

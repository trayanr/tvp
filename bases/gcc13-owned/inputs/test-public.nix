# Historical base suites exercise public constructors as well as floor inputs.
# Replay their original public graph; a different-profile seed is not equivalent.
{
  pkgs,
  tvp,
  recipes,
}:
let
  historicalTvp = tvp // {
    packages = public;
    canonical = capturedCanonical;
  };
  universe = import ../../../pkgs {
    inherit pkgs;
    tvp = historicalTvp;
  };
  families =
    map
      (
        name:
        let
          recipe = universe.recipes.${name}.constructionRecipe;
          canonical = tvp.lib.packages.mkVersions recipe;
        in
        {
          inherit canonical;
          aliases = tvp.lib.packages.mkAliases {
            inherit canonical;
            inherit (recipe) pname versionTable;
          };
        }
      )
      [
        "coreutils"
        "findutils"
        "diffutils"
        "gnused"
        "gnutar"
        "gnumake"
        "m4"
        "which"
        "patch"
        "patchelf"
        "bzip2"
        "zlib"
        "xz"
        "attr"
        "acl"
        "libxcrypt"
        "pcre2"
        "ncurses"
        "readline"
        "gnugrep"
        "gawk"
        "perl"
        "openssl"
        "libffi"
        "gdbm"
        "mpdecimal"
        "tcl"
      ];
  # Exact-name historical baselines must close over the same retained providers.
  capturedCanonical =
    universe.canonical
    // tvp.lib.packages.merge (
      builtins.listToAttrs (
        map (f: {
          name = builtins.head (builtins.attrNames f.canonical);
          value = f.canonical;
        }) families
      )
    );
  public =
    universe.canonical
    // universe.aliases
    // tvp.lib.packages.merge (
      builtins.listToAttrs (
        map (f: {
          name = builtins.head (builtins.attrNames f.canonical);
          value = f.canonical // f.aliases;
        }) families
      )
    );
in
{
  inherit public;
  inherit (universe) recipes;
}

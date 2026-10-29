# Exact recipe selections used to construct the owned GCC 13 environment.
{
  pkgs,
  tvpLib,
  recipes,
  construction,
}:
tvpLib.packages.mergeVariants {
  perl = tvpLib.packages.mkVariants (
    recipes.perl
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."5.44.0" = { };
      };
    }
  );
  python-minimal = tvpLib.packages.mkVariants (
    recipes.python-minimal
    // {
      inherit pkgs;
      profiles = {
        gcc13 = {
          base = construction.bases.gcc13;
          versions."3.12.5" = {
            deps = {
              bash = construction.variants.gcc13.bash_5_2_37;
            };
          };
        };
      };
    }
  );
  bash = tvpLib.packages.mkVariants (
    recipes.bash
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."5.2.37" = {
          deps = {
            ncurses = construction.variants.gcc13.ncurses_6_6;
          };
        };
      };
    }
  );
}

{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.0.6" = {
      builder = ./build-3.0.6.nix;
      base = tvp.bases.default;
      deps = { };
      opts = {
        hardeningDisable = [ "format" ];
        archiveExt = "tar.gz";
        license = pkgs.lib.licenses.gpl2Plus;
      };
    };
    "3.1.8" = {
      opts.hardeningDisable = [ "format" ];
      builder = ./build-3.0.6.nix;
      base = tvp.bases.default;
      deps = { };
    };
    "4.0.2" = {
      builder = ./build-4.0.2.nix;
      base = tvp.bases.default;
      deps = {
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
      };
    };
    "4.1.4" = {
      builder = ./build-4.1.4.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6_3_0;
        mpfr = tvp.packages.mpfr_4_2_1;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.0.6";
      releases."3.0.6" = "sha256-q/J24Qx7hxMy0HvytlITOidBlnfRVzgwl7vRU+WKi/w=";
    }
    {
      def = defs."3.1.8";
      releases."3.1.8" = "sha256-Xbx7LEwyhxEzfCqs0JoSLHMTEiJi4/8DRZDwFAZ0ErQ=";
    }

    {
      def = defs."4.0.2";
      releases."4.0.2" = "sha256-IeHyjFG1Fg8KS/GnNcYQm0ajvWpD3oCOq8IcF7sCbRM=";
    }
    {
      def = defs."4.1.4";
      releases."5.4.1" = "sha256-B/b3NCt/6+QxP8LCVCrZPWT+IK2HFyABCfEFqCb1/Tc=";
      releases."5.3.2" = "sha256-+MNIZQnecFGSE4sA7ywAu73Q6Eww1cB9I/xzqdxMycw=";
      releases."5.1.1" = "sha256-2HYpOG6JS76hGl4AUV/JCdybcklSna2eajosdwhffqI=";
      releases."5.0.1" = "sha256-jk6G8E7XiWSLZvdXMpdDoNbftSlMO5G3VqR08c4Fp5Q=";
      releases."4.2.1" = "sha256-0RGXhedG1GqCCdKLLeQEpX+YOqSGcPTiJVMdO9wXVVE=";
      releases."4.1.4" = "sha256-U+GE4tD5De+SB4YFMYAkVjIr4JHHtI8j/cec2mWtwmY=";
      releases."5.2.2" = "sha256-PB/OFEa0y+4c0nO9fsZLyH2J9hU3RxzT4F4zqWWiUOk=";
    }
  ];
  pname = "gawk";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = tvp.bases.gcc13;
        versions."5.2.2" = {
          deps = {
            gmp = tvp.variants.gcc13.gmp_6_3_0;
            mpfr = tvp.variants.gcc13.mpfr_4_2_1;
            ncurses = tvp.variants.gcc13.ncurses_6_6;
            readline = tvp.variants.gcc13.readline_8_3;
          };
        };
      };
    }
  );

in
{
  inherit canonical variants;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}

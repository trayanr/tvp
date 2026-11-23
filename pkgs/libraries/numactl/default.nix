{ tvp, ... }:
let
  pname = "numactl";
  upstream = "https://github.com/numactl/numactl";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-0.5.nix;
      };
      releases = {
        "0.5" = "sha256-3M3H1X7LCoNa5cO5krGHCMhUFoFiN0s/PgwndOLbwW8=";
      };
    }
    {
      def = {
        builder = ./build-0.5.nix;
        opts.extraPrograms = [ "memhog" ];
      };
      releases = {
        "0.6" = "sha256-I062cr9/cgc09Da7Eg5xBARu88DWFjusaq3oPHyegQU=";
        "0.6.1" = "sha256-GLOzLGadR0iHqs7eI14y9DkJOFXJOFmkQOTq/dR7Txg=";
        "0.6.2" = "sha256-D7J6A0+5KZzubDzm6xj5u5mUA/R+MCc6XjiAaypfVvU=";
        "0.6.3" = "sha256-3n8HXx/3f1PZX8DSE0h0eNuImLOOef7X3YhLZIcxN9g=";
        "0.6.4" = "sha256-iM3nFZkozs+4yGtn2JtFNtD36XuuRleLItBQfCCgdqo=";
        "0.8" = "sha256-dDyhnyACZ1IzZgk+l0PSaDVj0LHL70sRugAq1L4TP8Y=";
        "0.9" = "sha256-QUjsgBLj5pajqQi+Yv6CY4BecwrIFi/TC1bu0LbZP6k=";
        "0.9.1" = "sha256-tMdgdzTlnj7vaBWWAGm5kITAM9aCDLGIGhc3Ohgv6qs=";
      };
    }
    {
      def = {
        builder = ./build-0.5.nix;
        opts.extraPrograms = [
          "memhog"
          "migratepages"
        ];
      };
      releases = {
        "0.9.2" = "sha256-XvzDsRF36f27jLfZ9S9+HDAOIx1GQ30tiW93ClirU9E=";
        "0.9.3" = "sha256-9fckUQBlRYWZQv+GSU/Pm9NrpHWOFCKZHvHJ4Lyshkw=";
        "0.9.6" = "sha256-RUWxP3GhOXvbY/6FEpkhNgrP67M3UFOVDHY8Q8YWPQU=";
        "0.9.7" = "sha256-CtbzKsaoxHVvqNGlSjAP2CPigAwPBrjItT8/Z0K5LSE=";
        "0.9.8" = "sha256-cHtqGPA+sPuxxPXOHrParV5rFduXLA/Hro6IA0miuMo=";
        "0.9.9" = "sha256-XcIT85zOsfDKMAKFdcTIncup76ZuQWTaNYJgRH4LNI8=";
        "0.9.10" = "sha256-sZmeyHbHJ41oSVNl3eja5ff2o4kXz8i4xmP81qTT02I=";
        "0.9.11" = "sha256-n+jowpr8HgZdw1l7KcVUaF1spDVzsSkzTskQtVT67PA=";
        "1.0" = "sha256-kCUbEwROQ2kLdwvpTM4aBfZifcWTPHLSopEHA0gvdOI=";
        "1.0.2" = "sha256-Moyool3G3tL4pOKBNPWHoTuVrt980NaDbCozpA7MeUE=";
      };
    }
    {
      def = {
        builder = ./build-0.5.nix;
        opts = {
          compression = "bzip2";
          extraPrograms = [
            "memhog"
            "migratepages"
          ];
        };
      };
      releases = {
        "1.0.1" = "sha256-id8ddv1llcicAD8dkYHl7BoODTh3DwPRGW2phYtXRjc=";
      };
    }
    {
      def = {
        builder = ./build-0.5.nix;
        opts = {
          compatibilityHeader = true;
          extraPrograms = [
            "memhog"
            "migratepages"
            "migspeed"
          ];
        };
      };
      releases = {
        "2.0.0" = "sha256-p/Oc4xjBEsR/ZvZthgzu8ZDE1tjoytNb0R3bGKzF8M0=";
      };
    }
    {
      def = {
        builder = ./build-0.5.nix;
        opts = {
          compatibilityHeader = true;
          staticLibrary = true;
          extraPrograms = [
            "memhog"
            "migratepages"
            "migspeed"
          ];
        };
      };
      releases = {
        "2.0.1" = "sha256-OVibnShhZhTdFvpw4S45w4OFRlmUkB2dUX5uigZzr/E=";
        "2.0.2" = "sha256-mmdayUJnxTcLYBblfNQ3IRpvX0Vqbeyx95c/YC4bRPE=";
        "2.0.3" = "sha256-nTrvDPToqWkfuILf1oPuq92C5B3ZAFDoKi1JtAGxHYY=";
        "2.0.4" = "sha256-z1fYF0qgeCvTwkMNYK+lKXlo22mw7wDq8gJyCL426Uw=";
        "2.0.5" = "sha256-r//MCiN+xxc3o/Ps2l4LTg7eXDqJSvfYX1QW+jX3tEw=";
        "2.0.6" = "sha256-yDbpYeJPqWhyii0rIFJjjl5YnL/YGEDsPRl/P35kcLs=";
        "2.0.7" = "sha256-Ch4jephknFzS23xoSv4zu4HSkLQGzwDQRpvbqaEbOe8=";
      };
    }
    {
      def = {
        builder = ./build-0.5.nix;
        opts = {
          compatibilityHeader = true;
          compiledNumastat = true;
          staticLibrary = true;
          extraPrograms = [
            "memhog"
            "migratepages"
            "migspeed"
          ];
        };
      };
      releases = {
        "2.0.8" = "sha256-L1u20dVVYjXsOx7UAJTVvCUC5brMIT0yQIjWP6Uxyeo=";
        "2.0.9" = "sha256-nKAz5sFMDybCA3mwz5KZQp/Vo1SnnDx4gP1B72n3dRw=";
      };
    }
    {
      def = {
        builder = ./build-2.0.10.nix;
        # This first Autotools release ships the build-system inputs only.
        deps = {
          autoconf = tvp.packages.autoconf_2;
          automake = tvp.packages.automake_1;
          libtool = tvp.packages.libtool_2;
        };
        opts.pkgconfig = false;
      };
      releases = {
        "2.0.10" = "sha256-29rI/nTxOy4oZLujUvFZerHTNFyMSF14BfWNZvQU22E=";
      };
    }
    {
      def = {
        builder = ./build-2.0.10.nix;
        opts.pkgconfig = false;
      };
      releases = {
        "2.0.11" = "sha256-RQwJEjX4ke6HSoZRsXnDD1ehORylxGczVHQLpl5SeGE=";
      };
    }
    {
      def = {
        builder = ./build-2.0.10.nix;
      };
      releases = {
        "2.0.12" = "sha256-VbvaNj9bMqvQV7b7tFUd1xMj9du2YzW6dYupPeKtpyk=";
        "2.0.13" = "sha256-mR4lS4Z+tZUaRNKuC/GZao7wIJ4CaRHvbD70yvb1jJo=";
        "2.0.14" = "sha256-gmvRSMG2Ix4ShOQqTbUQIHdHSEsRKu4l7WsQeHVrz/Y=";
        "2.0.16" = "sha256-GyQviTr5d6HTGvbOnWuNr90tjsPckgf3wtwNNEbnx8g=";
      };
    }
    {
      def = {
        builder = ./build-2.0.10.nix;
        opts.cliVersion = true;
      };
      releases = {
        "2.0.17" = "sha256-iCTd1Smm+TXcJnC7pvUvsPYF+fSOEXb2nWt+SKrYyyc=";
        "2.0.18" = "sha256-tPwJVjF2gFeZkteBW8Q9BTiWDcc6od2Mp+OAbjC8EnQ=";
        "2.0.19" = "sha256-8mcqA4HLWRlunCRr+LzEPVVovEV3AKaX8aHfdiua+IQ=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        let
          codec = if version == "1.0.1" then "bz2" else "gz";
        in
        "${upstream}/releases/download/v${version}/numactl-${version}.tar.${codec}";
      discovery = {
        type = "git-tags";
        url = "${upstream}.git";
        prefix = "v";
        # GitHub classifies the otherwise numeric 2.0.15 tag as a prerelease.
        include = version: version != "2.0.15" && builtins.match "[0-9]+([.][0-9]+)+" version != null;
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}

{ pkgs, tvp }:
{
  "8.0" = {
    builder = ./build-8.0.nix;
    sha256 = "sha256-4zn1GXFHjTafigU6MwoZB4GsuYZM9MVBBg8SB4lI5GE=";
    deps = {
      ncurses = tvp.packages.ncurses_6_6;
    };
  };

  "8.1.2" = {
    builder = ./build-8.0.nix;
    sha256 = "sha256-dYmiOBqEGeaGVKR2I859/LdWgVyP7nJrmPkL9mive8Y=";
    deps = {
      ncurses = tvp.packages.ncurses_6_6;
    };
  };

  "8.2" = {
    builder = ./build-8.0.nix;
    sha256 = "sha256-P+txcfFqhO6CyhijbXub4QmlLAT0kqBTMx19EJUAfDU=";
    deps = {
      ncurses = tvp.packages.ncurses_6_6;
    };
  };

  "8.2.13" = {
    builder = ./build-8.0.nix;
    sha256 = "sha256-Dlvk0pN+i9m3zWDUZyHOefiKM0Fd1owtc4+1kkY49lY=";
    deps = {
      ncurses = tvp.packages.ncurses_6_6;
    };
  };

  "8.3" = {
    builder = ./build-8.0.nix;
    sha256 = "sha256-/lODIERngozUle6NHTwDen66E4nCK8agQfYnl2+QYcw=";
    deps = {
      ncurses = tvp.packages.ncurses_6_6;
    };
  };

}

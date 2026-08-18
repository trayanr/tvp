{ pkgs, tvp }:
{
  "6.2" = {
    builder = ./build-6.2.nix;
    sha256 = "sha256-MDBuDHbg+fHw3ph88cgqXCHhzmVouSJ/faW3HL6obJ0=";
    deps = {
      pkg-config = tvp.packages."pkg-config_0_29_2";
    };
  };

  "6.3" = {
    builder = ./build-6.2.nix;
    sha256 = "sha256-l/xRrCsIXUzeMe9NLDEiwhq8IX6QkKQ6MPxewhaE4Fk=";
    deps = {
      pkg-config = tvp.packages."pkg-config_0_29_2";
    };
  };

  "6.4" = {
    builder = ./build-6.2.nix;
    sha256 = "sha256-aTEoPZrIfFBz8wtikMTHXyFjK7T8NgOsgQCBK+0kgVk=";
    deps = {

    };
  };

  "6.5" = {
    builder = ./build-6.2.nix;
    sha256 = "sha256-E22RvCaamleF5fnpgLx2q1dCj2BM4+WlqQzrx2eXHMY=";
    deps = {

    };
  };

  "6.6" = {
    builder = ./build-6.2.nix;
    sha256 = "sha256-NVtMu+2ICwOBoExGYXt2VuNiWF1S6c+Epn4gCbdJ/xE=";
    deps = {
      pkg-config = tvp.packages."pkg-config_0_29_2";
    };
  };

}

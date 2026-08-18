{ pkgs, tvp }:
{
  "5.28.3" = {
    builder = ./build-5.28.nix;
    # gcc 9 reports 9.5.0, so Configure's `1*` glob does not match and the
    # struct-return patch this builder would otherwise apply is unnecessary.
    base = tvp.bases.gcc9;
    sha256 = "sha256-r8nB1mFZeuFNnog8UHEJK+1z9gwxCbKUgj6gGspwURQ=";
    deps = {
      coreutils = pkgs.coreutils;
    };
  };

  "5.30.3" = {
    builder = ./build-5.34.nix;
    sha256 = "sha256-MuBMi7exrssnQqf3rA6rrBAPOCRzUqc61/oQTjnnQG8=";
    deps = {
      coreutils = pkgs.coreutils;
    };
  };

  "5.32.1" = {
    builder = ./build-5.34.nix;
    sha256 = "sha256-A7aTkBzYroByMbF4d5jPHy4LilYhjQe32kT3hKfK6yw=";
    deps = {
      coreutils = pkgs.coreutils;
    };
  };

  "5.34.3" = {
    builder = ./build-5.34.nix;
    sha256 = "sha256-WxL2KGMzKypfVBAq+c34wBCHfkvzKUkR7b1ZSyoejt4=";
    deps = {
      coreutils = pkgs.coreutils;
    };
  };

  "5.36.3" = {
    builder = ./build-5.44.nix;
    sha256 = "sha256-8qGtiBFjkaF2Ji3ULfxS7yKvtA9MDpgQ8V1WHm8ccmo=";
    deps = { };
  };

  "5.38.5" = {
    builder = ./build-5.44.nix;
    sha256 = "sha256-t2Z9P/MJBohSr3hTkQqszsJsg51xdAISG2ZKxwXge/4=";
    deps = { };
  };

  "5.40.5" = {
    builder = ./build-5.44.nix;
    sha256 = "sha256-Cdkmri0bJ3w7zmIFTEHaR8mBOA1xnEHPmAtnlFzFge0=";
    deps = { };
  };

  "5.42.3" = {
    builder = ./build-5.44.nix;
    sha256 = "sha256-ETd0CYWDe1zfFfDPq5Miedy0NS+RL+1vwUTotPCCNic=";
    deps = { };
  };

  "5.44.0" = {
    builder = ./build-5.44.nix;
    sha256 = "sha256-O4VQZrkkkctA6Gr/scpX0aOIqkPlG5HHgGoywvZflsM=";
    deps = { };
  };

}

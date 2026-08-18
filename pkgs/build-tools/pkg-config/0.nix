{ pkgs, tvp }:
{
  "0.27" = {
    builder = ./build-0.27.nix;
    sha256 = "sha256-eaa0PuZjPJ5swD6xcGNwu3qEUGWYRbeCQR+WnqumVqQ=";
    deps = {
      gettext = pkgs.gettext;
    };
  };

  "0.27.1" = {
    builder = ./build-0.27.1.nix;
    sha256 = "sha256-T2PQ3zA1EBsSlJJQ2lIxr0njw6/Nj7GFVPp8PLktjBc=";
    deps = { };
  };

  "0.28" = {
    builder = ./build-0.27.1.nix;
    sha256 = "sha256-a26zHG7EQhF0V4ZSx+FB/ari2rrRAh9CDYcTIGrB+EU=";
    deps = { };
  };

  "0.29" = {
    builder = ./build-0.27.1.nix;
    sha256 = "sha256-yFB3BdKhDGfzhdZsoqrjHoF3DMBzS0GR64xInoZKAGs=";
    deps = { };
  };

  "0.29.1" = {
    builder = ./build-0.27.1.nix;
    sha256 = "sha256-vrQ8ngZFVUab1DkNz9gDCxU24KoQPwjXq/eujKwMsAE=";
    deps = { };
  };

  "0.29.2" = {
    builder = ./build-0.29.2.nix;
    sha256 = "sha256-b8acAWiMlFilfrmhZkyaujcszaQgoCv0Qp/mEOfn1ZE=";
    deps = { };
  };
}

{ pkgs, tvp }:
{
  "4.0.0" = {
    builder = ./build-3.0.nix;
    sha256 = "sha256-wyz0mpWcTzRflgaYLdNufSj3xYsZwuJddWJNKz0veaw=";
    deps = { };
  };

  "4.0.1" = {
    builder = ./build-3.0.nix;
    sha256 = "sha256-LbPzoNbqS1nh8JSs4sjNU23/uHzcOQhMWvoeb3833Qk=";
    deps = { };
  };

}

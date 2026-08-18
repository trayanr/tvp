{ pkgs, tvp }:
{
  "2.12.10" = {
    builder = ./build-2.12.nix;
    sha256 = "sha256-w9jAw0qjkJj2ZXb+UZadsSpRALlWIz3FZQb3qGeb6ZU=";
    deps = {
      zlib = tvp.packages.zlib_1_3_2;
      xz = pkgs.xz;
    };
  };

  "2.13.9" = {
    builder = ./build-2.12.nix;
    sha256 = "sha256-osmue3cNo0hgBQwwn5AyIcZ4MMhuSn52BpK4A9+VFDo=";
    deps = {
      zlib = tvp.packages.zlib_1_3_2;
      xz = pkgs.xz;
    };
  };

  "2.14.6" = {
    builder = ./build-2.12.nix;
    sha256 = "sha256-fORYoK/+uD8LVfH0+eDlVzXb/Bqd4STuhvtKZrWXIDo=";
    deps = {
      zlib = tvp.packages.zlib_1_3_2;
      xz = pkgs.xz;
    };
  };

  "2.15.3" = {
    builder = ./build-2.12.nix;
    sha256 = "sha256-eCYqbnrBcNZSjr/i78zfIgGRpa9qbNYepKmppQQsegc=";
    deps = {
      zlib = tvp.packages.zlib_1_3_2;
      xz = pkgs.xz;
    };
  };

}

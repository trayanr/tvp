{ pkgs, tvp }:
{
  "2.69" = {
    builder = ./build-2.69.nix;
    sha256 = "sha256-lUvWmzke3BLWpKUaLdFHZUPaXGu/BalbWdwN1v1MKWk=";
    deps = {
      m4 = tvp.packages.m4_1_4_21;
      perl = tvp.packages.perl_5_44_0;
    };
  };

  "2.71" = {
    builder = ./build-2.69.nix;
    sha256 = "sha256-QxB1rQv1Ke8Ty0HpBCxUI4EQPoABVoYiK4qdSr70Khw=";
    deps = {
      m4 = tvp.packages.m4_1_4_21;
      perl = tvp.packages.perl_5_44_0;
    };
  };

  "2.72" = {
    builder = ./build-2.69.nix;
    sha256 = "sha256-r7GBp24e5ygy9lgcDt343wMrg+LgI573nr7cRGfZLW4=";
    deps = {
      m4 = tvp.packages.m4_1_4_21;
      perl = tvp.packages.perl_5_44_0;
    };
  };

  "2.73" = {
    builder = ./build-2.69.nix;
    sha256 = "sha256-JZ3fo73ceZz7gUicwPF9/fG9bRUF3aU8D0X/YNak+ac=";
    deps = {
      m4 = tvp.packages.m4_1_4_21;
      perl = tvp.packages.perl_5_44_0;
    };
  };

}

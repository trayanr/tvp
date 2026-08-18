# The 1.1.0 line pins perl 5.28.3 and names its base rather than inheriting the default.
#
# `Configure` there does `use File::Glob 'glob'`, and perl stopped exporting glob at 5.30.
# Upstream deleted the import at 1.1.0h; pinning a perl that still exports it covers the
# whole line instead, which is what let 1.1.0 drop its own builder and share 1.1.1's.
#
# `pbkdf2 = false` because `enc -pbkdf2` arrives in 1.1.1 — a capability, so it selects a
# test rather than forking the procedure.
{ pkgs, tvp }:
{
  "1.1.0" = {
    builder = ./../build-1.1.1.nix;
    base = tvp.bases.nixpkgs;
    sha256 = "sha256-9caf+awUcsgLho78HBwNjc/HRtKevlY94jZd1W29jII=";
    deps = {
      perl = tvp.packages.perl_5_28_3;
    };
    opts = {
      pbkdf2 = false;
    };
  };

  "1.1.0a" = {
    builder = ./../build-1.1.1.nix;
    base = tvp.bases.nixpkgs;
    sha256 = "sha256-wuaW40KWzeLJ7F3NrZ5PBCzXA5MlkdOVw4neSIMCRCs=";
    deps = {
      perl = tvp.packages.perl_5_28_3;
    };
    opts = {
      pbkdf2 = false;
    };
  };

  "1.1.0b" = {
    builder = ./../build-1.1.1.nix;
    base = tvp.bases.nixpkgs;
    sha256 = "sha256-pF3gcr+b5N6kNyMKrwNgAPDmjGpmWTHFfna1sDbO9vc=";
    deps = {
      perl = tvp.packages.perl_5_28_3;
    };
    opts = {
      pbkdf2 = false;
    };
  };

  "1.1.0c" = {
    builder = ./../build-1.1.1.nix;
    base = tvp.bases.nixpkgs;
    sha256 = "sha256-/ENkQaLgV1LTG05GEV64lwmiiu+W1P54ar6SQJsv1vU=";
    deps = {
      perl = tvp.packages.perl_5_28_3;
    };
    opts = {
      pbkdf2 = false;
    };
  };

  "1.1.0d" = {
    builder = ./../build-1.1.1.nix;
    base = tvp.bases.nixpkgs;
    sha256 = "sha256-fV67nol1ZUXBVv+cE88qpiFBk7AQpGijvHicPCj+YN8=";
    deps = {
      perl = tvp.packages.perl_5_28_3;
    };
    opts = {
      pbkdf2 = false;
    };
  };

  "1.1.0e" = {
    builder = ./../build-1.1.1.nix;
    base = tvp.bases.nixpkgs;
    sha256 = "sha256-V76GGJedgMkQcoz8mTab+XsqGr2PNmq2697ol1rTh0w=";
    deps = {
      perl = tvp.packages.perl_5_28_3;
    };
    opts = {
      pbkdf2 = false;
    };
  };

  "1.1.0f" = {
    builder = ./../build-1.1.1.nix;
    base = tvp.bases.nixpkgs;
    sha256 = "sha256-EvdG8/JJOy852n7PY9fuGcasnsak/NjCKdqKUiyxJ2U=";
    deps = {
      perl = tvp.packages.perl_5_28_3;
    };
    opts = {
      pbkdf2 = false;
    };
  };

  "1.1.0g" = {
    builder = ./../build-1.1.1.nix;
    base = tvp.bases.nixpkgs;
    sha256 = "sha256-3k1QEmfaOTEJBcttyMYSH3osrUWncH9234KP4bhQc68=";
    deps = {
      perl = tvp.packages.perl_5_28_3;
    };
    opts = {
      pbkdf2 = false;
    };
  };

  "1.1.0h" = {
    builder = ./../build-1.1.1.nix;
    base = tvp.bases.nixpkgs;
    sha256 = "sha256-WDVibN6emWVlhfx6qiMCpzp+E0C/jBT9Y1pixmgCpRc=";
    deps = {
      perl = tvp.packages.perl_5_28_3;
    };
    opts = {
      pbkdf2 = false;
    };
  };

  "1.1.0i" = {
    builder = ./../build-1.1.1.nix;
    base = tvp.bases.nixpkgs;
    sha256 = "sha256-67/IRKjIzA6l3BC4bJzpf0AYN/P6CMF7LNrcEYJTz5k=";
    deps = {
      perl = tvp.packages.perl_5_28_3;
    };
    opts = {
      pbkdf2 = false;
    };
  };

  "1.1.0j" = {
    builder = ./../build-1.1.1.nix;
    base = tvp.bases.nixpkgs;
    sha256 = "sha256-Mb7GwgPOGo6T1ZlPTtMExjzPB2dhGLZjTt3tEq0bMkY=";
    deps = {
      perl = tvp.packages.perl_5_28_3;
    };
    opts = {
      pbkdf2 = false;
    };
  };

  "1.1.0k" = {
    builder = ./../build-1.1.1.nix;
    base = tvp.bases.nixpkgs;
    sha256 = "sha256-76SWX093NXTWy9oc+HTbvkVascDU+QYRX4Z9MEREcLE=";
    deps = {
      perl = tvp.packages.perl_5_28_3;
    };
    opts = {
      pbkdf2 = false;
    };
  };

  "1.1.0l" = {
    builder = ./../build-1.1.1.nix;
    base = tvp.bases.nixpkgs;
    sha256 = "sha256-dKL3VsZP1zhqKRhNwDRPSDEZLWHcJIGpOkxd1yf0EUg=";
    deps = {
      perl = tvp.packages.perl_5_28_3;
    };
    opts = {
      pbkdf2 = false;
    };
  };

  "1.1.1" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-KDaHWg+JwD0P30g5QVEmE6UM+0Idb9lLn0HXJ51Yaj0=";
    deps = { };
  };

  "1.1.1a" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-/CATD4t8vS+5GLLxTi9CnhCcMd3Q+zj8XXHZ/+0/n0E=";
    deps = { };
  };

  "1.1.1b" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-XFV7AjIwQT37B1bzE3oT5tcmg4zNFDCIitFb+ytD6ks=";
    deps = { };
  };

  "1.1.1c" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-9vswea0VB2FU7alBP+1Ch31mjnBp2bhzltCAT9s/TJA=";
    deps = { };
  };

  "1.1.1d" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-HjqRvB+d/OAa8mAm+FbgZOq0yO4Kj0V7WuMLQLi3EfI=";
    deps = { };
  };

  "1.1.1e" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-aU9hrBHLUcm/c/VOdx/2AisDJ6Q7vfobLxneFmKm3L4=";
    deps = { };
  };

  "1.1.1f" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-GGxr/m7PunpbSMR/ihZz0POw5bouJWAt0jtimXXaPzU=";
    deps = { };
  };

  "1.1.1g" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-3bBHdPHjLwxJdR4htnIWrIeFLOsFa3UgmvJENABjbUY=";
    deps = { };
  };

  "1.1.1h" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-XJyod0vXsD5XhPJq6enm10nJ2iQ4VFB35rPXVaBlldk=";
    deps = { };
  };

  "1.1.1i" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-6L5qNf5B0QYDw8xjXpMontAL80t5Zxo6TeZPzuANUkI=";
    deps = { };
  };

  "1.1.1j" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-qvL8tXXN9kkbmKtIKav3ij3shAK4uB78jyPADUQ5gb8=";
    deps = { };
  };

  "1.1.1k" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-iSoIdbmHKs0Eqf3nmx+UMHXV6hYkFd4wR8Mn3zP7ruU=";
    deps = { };
  };

  "1.1.1l" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-C3o+XlnDSCf+DDp0t+yLrvMCuY+oAIjX+RU6oW+na9E=";
    deps = { };
  };

  "1.1.1m" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-+JGZvosjykX8fLnx2NPuZzEjGChq0DD1MWrKZGLbbJY=";
    deps = { };
  };

  "1.1.1n" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-QNzrUaT2pSdb3g5r8g70uRv8Mu1XwFUuLo4VRjNysXo=";
    deps = { };
  };

  "1.1.1o" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-k4SisFcN2ANYhBRkZ3EV33he25QccSEfdQdtcv5rQ48=";
    deps = { };
  };

  "1.1.1p" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-v2G2Kqpmx8djmUKpTeTJroKAwI8X1OrC5EZE2fyKzm8=";
    deps = { };
  };

  "1.1.1q" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-15Oc5hQCnN/wtsIPDi5XAxWKSJpyslB7i9Ub+Mj9EMo=";
    deps = { };
  };

  "1.1.1s" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-xawB52Dub/Dath1rK70wFGck0GPrMiGAxvGKb3Tktqo=";
    deps = { };
  };

  "1.1.1t" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-je6bJL2x3L8MPR6bAvuPa/IhZegH9Fret8lndTaFnTs=";
    deps = { };
  };

  "1.1.1u" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-4vjYS1I+7NBse+diaDA3AwD7zBU4a/UULXJ1j2lj68Y=";
    deps = { };
  };

  "1.1.1v" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-1ml+KHHncjhGBALpNi1H0YOCsV758karpse9eA04prA=";
    deps = { };
  };

  "1.1.1w" = {
    builder = ./../build-1.1.1.nix;
    sha256 = "sha256-zzCYlQy02FOtlcCEHx+cbT3BAtzPys1SHZOSUgi3asg=";
    deps = { };
  };

}

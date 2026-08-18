{ pkgs, tvp }:
{
  "3.0.0" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-We7fy0bCUhTJvTftYHgpe03wHQEiZ/6enu4x9hvHBTY=";
    deps = { };
  };

  "3.0.1" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-wxGthTNTvOeW7a0BqGLFCopYf2Ln4hAO9GWrU+ybBtE=";
    deps = { };
  };

  "3.0.2" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-mOkczq1NR1auPJzeXgkZGo5YbZ9NUIOOfsCdZBHf22M=";
    deps = { };
  };

  "3.0.3" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-7gB4rc7x3l8APGLIDMllJ3IWCcbzu0K3eV3zH4tVjAs=";
    deps = { };
  };

  # Found by the rsa test aborting with SIGABRT, not by reading an advisory.
  "3.0.4" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-KDGEPppmigq0eOcCCtY9LWXlH3KXdHLcc+/O+6/AwA8=";
    status = {
      level = "degraded";
      reason = "CVE-2022-2274: RSA corrupts memory on x86_64 CPUs with AVX512IFMA. The rsa test aborts, so it is not run here.";
      needs = "Nothing — upstream fixed it in 3.0.5. This release is preserved as it shipped.";
      knownTestFailures = [ "rsa" ];
    };
    deps = { };
  };

  "3.0.5" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-qn2Nm+9xrWUlxVuhHl9Dl4ic5Jwsk0nc6m0+TwsCSno=";
    deps = { };
  };

  "3.0.7" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-gwSdBComDmlvYkBqxcCL9wb9hDg/lFzyG9YentlcOW4=";
    deps = { };
  };

  "3.0.8" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
    deps = { };
  };

  "3.0.9" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-6xqwR4FHQ2D3fDGKuJ2MWgOrw45j1lpgPKu/GwCh3JA=";
    deps = { };
  };

  "3.0.10" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-F2HU9bE6ECi5tvPUuOF/6wztyTcPav5h1xk9LNzoMyM=";
    deps = { };
  };

  "3.0.11" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-s0JdO7SiIY0Gl+tB9/wM3t4BbtGcpJ0Wi3jo2UeIf1U=";
    deps = { };
  };

  "3.0.12" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-+Tyejt3l6RZhGd4xdV/Ie0qjSGNmL2fd/LoU0La2m2E=";
    deps = { };
  };

  "3.0.13" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-iFJXU/edO+wn0vp8ZqoLkrOqlJja/ZPXz6SzeAza4xM=";
    deps = { };
  };

  "3.0.14" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-7soDXU3U6E/CWEbZUtpil0hK+gZQpvhMaC453zpBI8o=";
    deps = { };
  };

  "3.0.15" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-I8Zm0O3yDxQkmz2PA2isrumrWFsJ4d6CEHxm4fPslTM=";
    deps = { };
  };

  "3.0.16" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-V+A8UP6rXTGxUq8rdk8QN5rs2O6S8WyYWYPOSpn374Y=";
    deps = { };
  };

  "3.0.17" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-39135OobV/86bb3msL3D8x21rJnn/dTq+eH7tuwtuM4=";
    deps = { };
  };

  "3.0.18" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-2Aw09c+QLczx8bXfXruG0DkuNwSeXXPfGzq65y5P/os=";
    deps = { };
  };

  "3.0.19" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-+lpBQ7iq4YvlPvLzyvKaLgdHQwuLx00y2IM1uUq2MHI=";
    deps = { };
  };

  "3.0.20" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-yAoB38cOzk3CEWiTLDdzkELUBNRszIGlmG3XUxTs2m8=";
    deps = { };
  };

  "3.0.21" = {
    builder = ./../build-3.0.nix;
    sha256 = "sha256-YX4pr45CH0ZklISkk35IxoXkf0ZIgWfJgviLxOwdUi8=";
    deps = { };
  };

}

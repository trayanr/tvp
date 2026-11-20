{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.0.1.nix;
      };
      releases = {
        "1.0.1" = "sha256-Q/WQmvPwo+pXbpiNgFBs+y/vDS/LBu/ngQhMWVk2cao=";
        "1.0.2" = "sha256-UX998nhTa/m5G7FBBPy0sTzns8eR0XQZX+wWGGIbJOY=";
      };
    }
    {
      def = {
        builder = ./build-1.0.1.nix;
        opts.versionFunction = true;
      };
      releases = {
        "1.0.4" = "sha256-5cJgzT2xNw+z4MGT6cvZ8SepvQVdYis/tVuCdH9uWyQ=";
        "1.0.5" = "sha256-eAS+jm7aKXmoJd4l2GNG3Wpy5eNjuUZ6fIoyZNwiFaw=";
        "1.0.7" = "sha256-1w7+BtqpCGYYd6llEri3b93b93f1M4Z1cUYrQCwdkQ8=";
      };
    }
    {
      def = {
        builder = ./build-1.0.1.nix;
        opts.versionFunction = true;
        patches = [
          {
            file = ./1.0.6-ldshared-delimiter.patch;
            reason = "LDSHARED contains commas in the linker's SONAME option.";
          }
        ];
      };
      releases."1.0.6" = "sha256-O2E0wqZo0NiMbhP3OfgS9tqzUBpbziRs9Eq7B7Ur3L0=";
    }
    {
      def = {
        builder = ./build-1.0.1.nix;
        opts = {
          versionFunction = true;
          compress2 = true;
        };
      };
      releases = {
        "1.0.8" = "sha256-oqaYLnVk98rM1VhPw21Y6h8SJQh/3klAUGiD7mSOTZ4=";
        "1.0.9" = "sha256-rwqo6zPh0KmmoW3Utx6zunkxpiEvd/CYUE491Srb454=";
        "1.1.0" = "sha256-i/7rXVMtlnUGZP74PlmacBmjqE7dEIyOrbER+TFMt2M=";
        "1.1.1" = "sha256-8mMDN2pAkoJaWS06YACD21lc2GJJ+HalZ5GK2sjdlL4=";
      };
    }
    {
      def = {
        builder = ./build-1.1.2.nix;
      };
      releases = {
        "1.1.2" = "sha256-T8oNqqWPo7C+XAVEPbdDVmegHUIYsNtFO4ec9rHfl7k=";
      };
    }
    {
      def = {
        builder = ./build-1.1.3.nix;
      };
      releases = {
        "1.1.3" = "sha256-yuWEe8DhzxE9P3DQN0ANo+R8Lit7HJawsIRHpfu5BvQ=";
        "1.1.4" = "sha256-nj6XMXT5kQ/VFTnvnOlMhqOUPU+Jf6uOmt9LGeaoKR4=";
      };
    }
    {
      def = {
        builder = ./build-1.1.3.nix;
        # Shared-only all target leaves examples pointing at libz.a.
        opts.linkExamplesAgainstShared = true;
      };
      releases = {
        "1.2.0" = "sha256-5OC0H5jJksH28mGZ2Svg85uTBqYpZe2DYRvrv1x87Y0=";
        "1.2.0.1" = "sha256-w0KbSulHdbNslZVC8PnISwYQQagWhR2AAcBnClYOCnk=";
      };
    }
    {
      def = {
        builder = ./build-1.1.3.nix;
      };
      releases = {
        "1.2.0.2" = "sha256-aR9OwwMPMMR9FkY1KqC06U51yDJTM/ZzxZ6uULK3fO8=";
        "1.2.0.3" = "sha256-iJbP854df6fdBBEgXdNvEwcrzTCUvrK122zgSMQIvwc=";
        "1.2.0.4" = "sha256-Z4s0LCcqJE73jvMukgHtkGxDhzYef7yKBCHQBUKZHH4=";
      };
    }
    {
      def = {
        builder = ./build-1.1.3.nix;
        # Upstream uses plain mkdir for man3 before creating its parents.
        opts.createManDir = true;
      };
      releases = {
        "1.2.0.5" = "sha256-PQGRSdtiRjqBgI0kVmf4RyKYBmy5U8BjpidvjXLq5xM=";
        "1.2.0.6" = "sha256-7ndFsMmJS25jnn9+1RVNDRkR8rpFZ1m/pP9oKXaxnCk=";
        "1.2.0.7" = "sha256-5sGFFqAuXWAIzHJTpeaFmW4SVl85eympTwR1nwMEykE=";
      };
    }
    {
      def = {
        builder = ./build-1.1.3.nix;
      };
      releases = {
        "1.2.0.8" = "sha256-RwOfiLjFD05c88Wz5mHy7YMrpbT+ztQWQcBwKCfzRX4=";
        "1.2.1" = "sha256-lN7VIEDundHHDMO58B2ig4A8KMEZSlpAZZ6M91RZkOM=";
        "1.2.1.1" = "sha256-zsLJazd7VJmbHEMo+vuN4uaSJr335IrjLp2oMwGLkQo=";
        "1.2.1.2" = "sha256-NmX4HlWYOquIQLjMf/8cN0vCGHqOORLHOY/VkZH1uo0=";
        "1.2.2" = "sha256-67b03tXZW5xJFcYLU5JuQmjE/wYHmk7hWxcU3xbWGIE=";
        "1.2.2.1" = "sha256-PN3gzVIx8vvrAlXUx/unpLSXSeoGfhK4c3amF7KXzJc=";
        "1.2.2.2" = "sha256-Lc2QpKNHAQ9mkeAR5q3XJ9P+CbehJvR71h9sSR7+qlk=";
        "1.2.2.3" = "sha256-RyRc3WAqLol5LeQ4GUnmnUSISDFaTKz0W67cbBp7O1g=";
        "1.2.2.4" = "sha256-hmF+mOT+Xiwv8m9HdHpkOAFsc7GYepAjiQSO5dKWv2M=";
      };
    }
    {
      def = {
        builder = ./build-1.2.3.nix;
      };
      releases = {
        "1.2.3" = "sha256-F5XH0GekMXQRP98DRHUy83PhxsV8CNYdnk6b5eJEsF4=";
      };
    }
    {
      def = {
        builder = ./build-1.2.3.nix;
        opts = {
          pkgConfig = true;
          versionScript = true;
        };
      };
      releases = {
        "1.2.3.1" = "sha256-YXYvvYfExMGZbD4MP7TIwUqFbVQDMENceHaWq4hGy6Y=";
      };
    }
    {
      def = {
        builder = ./build-1.2.3.nix;
        opts = {
          pkgConfig = true;
          versionScript = true;
        };
        patches = [
          {
            file = ./patches/1.2.3.2-installed-header-needs-largefile64.patch;
            reason = "configure emits installed off64_t without exposing _LARGEFILE64_SOURCE to consumers; upstream removes this header definition in 1.2.3.3.";
          }
        ];
      };
      releases = {
        "1.2.3.2" = "sha256-lgYZeSfb9SOCF/A3yR/9z/1TPBd5tJqwgjcpv2yTjys=";
      };
    }
    {
      def = {
        builder = ./build-1.2.3.3.nix;
      };
      releases = {
        "1.2.3.3" = "sha256-5EDywp7yYqhizl/gdzkm5Gngy+/cIS982610ChmxGhs=";
      };
    }
    {
      def = {
        builder = ./build-1.2.3.3.nix;
        patches = [
          {
            file = ./patches/1.2.3.4-shared-library-not-installed.patch;
            reason = "configure omits the shared library from LIBS, so the shared ELF and soname alias are not installed; upstream restores it in 1.2.3.5.";
          }
        ];
      };
      releases = {
        "1.2.3.4" = "sha256-tCyo5Y+BQz39tSqFt0rnub13UIyH8w1iA1XJHskmi7Y=";
      };
    }
    {
      def = {
        builder = ./build-1.2.3.3.nix;
      };
      releases = {
        "1.2.3.5" = "sha256-Pgh+4NpLOHXWc4QV5mw95c1I0o/lZvleq5EK5DzS9MU=";
        "1.2.3.6" = "sha256-QwfIS7gLt/MafZ3vT2MZzEz5bLIl6hb2pn2EOoulrWU=";
        "1.2.3.7" = "sha256-27sHta/rVzWDofBryjHSve9Nvmtp0tE6A6nNzqnmS+8=";
        "1.2.3.8" = "sha256-rCJ8VSFFDDsrHTBxhWeDNUNtIFIOn0vHuzBKkDcKFAQ=";
        "1.2.3.9" = "sha256-LpaQRxZpxqJfNHxz344U7kjvKZLImTNBH34zbsbHvlc=";
        "1.2.4" = "sha256-wCjB11WNoqqKSRVFoINJNcTTowrDqxjlRmPTb/fTxc0=";
        "1.2.4.1" = "sha256-y4lSUPuxqI/wRnFIecU5aXRPPvgjJx5j8b8GPPGOsJI=";
      };
    }
    {
      def = {
        builder = ./build-1.2.3.3.nix;
        # Shared linking consumes libz.a; 1.2.5.1 adds this dependency upstream.
        opts.sourceEdits = [
          {
            path = "Makefile.in";
            before = "$(SHAREDLIBV): $(PIC_OBJS)";
            after = "$(SHAREDLIBV): $(PIC_OBJS) $(STATICLIB)";
            count = 1;
          }
        ];
      };
      releases = {
        "1.2.4.2" = "sha256-rc1Yt74/cadJ+5Wtoq3SeZu07OBPc9IFiqQUVLWK7LA=";
        "1.2.4.3" = "sha256-NBbgTolU1judK5l3prN+0mvga/MWTsDBfFi/FXRhi8M=";
      };
    }
    {
      def = {
        builder = ./build-1.2.3.3.nix;
        # Shared linking consumes libz.a; 1.2.5.1 adds this dependency upstream.
        opts.sourceEdits = [
          {
            path = "Makefile.in";
            before = "$(SHAREDLIBV): $(PIC_OBJS)";
            after = "$(SHAREDLIBV): $(PIC_OBJS) $(STATICLIB)";
            count = 1;
          }
        ];
        opts.sharedLibDir = true;
      };
      releases = {
        "1.2.4.4" = "sha256-fFatR6zc5sEaqFdsKpI/R+C4uNqyME1aFc4HO65qKAA=";
      };
    }
    {
      def = {
        builder = ./build-1.2.3.3.nix;
        # Shared linking consumes libz.a; 1.2.5.1 adds this dependency upstream.
        opts.sourceEdits = [
          {
            path = "Makefile.in";
            before = "$(SHAREDLIBV): $(PIC_OBJS)";
            after = "$(SHAREDLIBV): $(PIC_OBJS) $(STATICLIB)";
            count = 1;
          }
        ];
      };
      releases = {
        "1.2.4.5" = "sha256-l8kdaxTLMbVPsNuDeMkRIKBInhVvTX9zRkBIwbdd5Rw=";
        "1.2.5" = "sha256-YGTlLlE/rLD7t5mMZBNAbPJTz7mGBj1o9HccK/ej+Vg=";
      };
    }
    {
      def = {
        builder = ./build-1.2.3.3.nix;
        patches = [
          {
            file = ./patches/1.2.5.1-version-map-parent.patch;
            reason = "New ZLIB_1.2.5.1 inherits nonexistent ZLIB_1.2.5; upstream 1.2.5.2 corrects the parent to ZLIB_1.2.3.5.";
          }
        ];
      };
      releases = {
        "1.2.5.1" = "sha256-wfJKZPgIUoKTzwS6CaLf+8PdZa1+vO5HNxJP+JI3Vto=";
      };
    }
    {
      def = {
        builder = ./build-1.2.3.3.nix;
      };
      releases = {
        "1.2.5.2" = "sha256-X4wRnmA5L45qQlwLR4DmVbfsdLYXWhSF09AlB9N6S1I=";
        "1.2.5.3" = "sha256-XUv21SvrGMB3MW2tk0tYLLVc7eLGz24GX1YPweqEYyw=";
        "1.2.6" = "sha256-ISNeCFUub+ugnqXo11CAWzORxi+4HHGiNcAETceophs=";
        "1.2.6.1" = "sha256-wRBKGeyPh5gXhDYQWjpRp+0+0JhGZPHwcYQz0/TxTQw=";
        "1.2.7" = "sha256-+pychjjvuMuO9eTdVFPkVXUeHFMLFZXu1Gbhvpt+JsU=";
        "1.2.7.1" = "sha256-unICRi2ByipqxgOPU4dwbUxkayrQ1oYJQ/d0Rt12Xug=";
      };
    }
    {
      def = {
        builder = ./build-1.2.3.3.nix;
        opts = {
          reportedVersion = "1.2.7.2-motley";
          libraryVersion = "1.2.7.2-motley";
        };
      };
      releases = {
        "1.2.7.2" = "sha256-amPHnkEIYMNFC7k38he3e6vWiR+7dyhm+QxpCSoM+/o=";
      };
    }
    {
      def = {
        builder = ./build-1.2.3.3.nix;
      };
      releases = {
        "1.2.7.3" = "sha256-9BY16Z5u/mS+oqF/uLF40aVm4JXbQ+gPfmF3OaskynM=";
        "1.2.8" = "sha256-NmWMt2ilTB1N7EPDEWwn7Yk+iLAuz8tE8hZvnAt/Kg0=";
        "1.2.9" = "sha256-c6swLvMe0edIldKvVvUvWFPyawNw8+8hlUNHrOxeqiE=";
      };
    }
    {
      def = {
        builder = ./build-1.2.10.nix;
      };
      releases = {
        "1.2.10" = "sha256-jX6faYzkh4e24cZ+a/955IcwPmYHfiXLl4SsiDWXgBc=";
        "1.2.11" = "sha256-w+Xp/dUATctUL+2l7k8P8HRGKLr47S3V1m+MoRl8saE=";
      };
    }
    {
      def = {
        builder = ./build-1.2.10.nix;
        # This configure alone omits assigning nonempty CC to lowercase cc.
        opts.bindLowercaseCc = true;
      };
      releases = {
        "1.2.12" = "sha256-kYRICFMuXOMWs8AQkpSTwCRPPTdZOv1t4E9xgh1RNtk=";
      };
    }
    {
      def = {
        builder = ./build-1.2.10.nix;
      };
      releases = {
        "1.2.13" = "sha256-s6JN6XqP28g1uYMxaVAQMLiXcDG8tUs7OsE3QPhGqzA=";
        "1.3" = "sha256-/wukwpIBPbwnUws6geH5qBPNOd4Byl4Pi/NVcC76WT4=";
        "1.3.1" = "sha256-mpOyt9/ax3zrpaVYpYDnRmfdb+3kWFuR7vtg8Dty3yM=";
        "1.3.2" = "sha256-uzKaCizQJ00FUZ1hxmfAYuBpkNcuEl7i36jeZPARnRY=";
      };
    }
    {
      def = {
        builder = ./build-0.8.nix;
        base = tvp.bases.gcc_4.full;
      };
      status = {
        level = "broken";
        reason = "gzio.c writes `*((Byte*)buf)++`, the cast-as-lvalue extension gcc removed at 3.4. The library is otherwise complete and installs by hand, since these releases ship no configure and no install target.";
        needs = "A gcc 3.3 or older base. Measured, not assumed: gcc 4.9 is the oldest stdenv nixpkgs offers and it rejects the construct, as do 9 and 13.";
        blocked = {
          base = "gcc<=3.3";
        };
      };
      releases = {
        "0.71" = "sha256-M7uIcAiI/wVxa3lKeQomt1UimP27PZpOR0TBTMTkgRA=";
        "0.79" = "sha256-9FYP1ulpDwsECg8diF0wP9V/EUzvYf1gkOILC2jhU1w=";
        "0.8" = "sha256-+20JiailWa6IF/3DO8jwTRqAt429iuywTzKKFnLrAfY=";
        "0.9" = "sha256-5tVSviDj2p3eZpOZYXziJnn12CgWNgiWIKunuu7TWsw=";
        "0.91" = "sha256-CQ/8n7n5V3Yd0jZTI+h7QrIOgf9SvJeKQG1paXWQBFc=";
        "0.92" = "sha256-72AbQ1BJEFmBGBldMpglFB8OrVpQYiiJIjyPj7eZzyk=";
        "0.93" = "sha256-7n8HT16e6l9Z/1E6vUn32QMJYVnqU4NgvdYGOPDEAd8=";
        "0.94" = "sha256-EdNAaK4TyzULkScsSrkj7mo8L4H9olWmwvur0ACj6NQ=";
        "0.95" = "sha256-fdNxiwRrPPTVkUtM+ZzivdQ2Q/TJYV5zbpqjAnvkYvc=";
        "0.99" = "sha256-hoT7ed5iJ/uBFqTd/46xbud4nk3YtMwf93wBeHWEx/Q=";
      };
    }
  ];
  pname = "zlib";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;

    source = tvp.lib.sources.directory {
      url = "https://zlib.net/fossils/";
      archive = "zlib-{version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/madler/zlib";

        normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;

        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(
            pkgs.lib.hasInfix "alpha" version
            || pkgs.lib.hasInfix "beta" version
            || pkgs.lib.hasInfix "rc" version
            || pkgs.lib.hasInfix "pre" version
          );

        unavailable = [
          {
            versions = [ "1.3.1.2" ];
            reason = "Tagged but never published as a release tarball: absent from zlib.net and from fossils/, which is upstream's own archive of everything it has shipped. Only the GitHub git-archive snapshot exists, and that is a different artifact.";
          }
        ];
      };
    };
    tests =
      args@{ package, context, ... }:
      if (package.tvp.features.libName or "z") == "gz" then
        import ./tests/historical-interface.nix args
      else
        import ./tests args;
    testDeps = {
      pkgConfig = tvp.packages.pkg-config;
      gzip = tvp.packages.gzip;
      runtimeShell = tvp.bases.gcc_16.seed.shell;
      sentinel = tvp.lib.tests.fixtures.sentinel;
      alternateSource = tvp.lib.tests.fixtures.alternateSource;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.zlib = family // {
    excludedVersions = pkgs.lib.filterAttrs (
      _: entry: (entry.status.level or "ok") == "broken"
    ) family.versionTable;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases {
    inherit pname canonical;
    versionTable = family.versionTable;
  };
}

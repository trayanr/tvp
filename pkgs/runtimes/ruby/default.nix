{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  # Upstream's OpenSSL bound (ext/openssl/extconf.rb) gains "< 3.0.0" at 2.7.5
  # and again at 3.0.3, then drops the upper limit entirely at 3.1. So 2.7 and
  # 3.0 pin 1.1.1w — the latest release their own bound admits — and 3.1 upwards
  # pin 3.5.7, the latest LTS line TVP owns.
  defs = tvpLib.packages.mkDefs {
    "2.4.0" = {
      builder = ./build-2.2.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        readline = tvp.packages.readline_8_3;
        zlib = tvp.packages.zlib_1_3_2;
        gdbm = tvp.packages.gdbm_1_26;
      };
    };

    # Ruby's OpenSSL extension gained 1.1 support at 2.4. Below that, ext/openssl
    # reaches into structs 1.1 made opaque, extconf fails, and the extension is
    # dropped -- without failing the build, which is what the openssl test is for.

    # ext/fiddle stopped shipping its own libffi below 2.2, so it has to be
    # named. 3.2 needs it again for the opposite reason.
    "2.1.2" = {
      builder = ./build-2.0.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_1_0_2u;
        readline = tvp.packages.readline_8_3;
        zlib = tvp.packages.zlib_1_3_2;
        gdbm = tvp.packages.gdbm_1_26;
        libffi = tvp.packages.libffi_3_8_0;
      };
    };

    # Ruby's ext/readline used the Function typedef, which readline gated behind
    # WANT_OBSOLETE_TYPEDEFS at 6.3. Fixed upstream at 2.1.2.
    "2.0.0-p0" = {
      builder = ./build-2.0.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_1_0_2u;
        readline = tvp.packages.readline_6_2;
        zlib = tvp.packages.zlib_1_3_2;
        gdbm = tvp.packages.gdbm_1_26;
        libffi = tvp.packages.libffi_3_8_0;
      };
    };
    "2.2.0" = {
      builder = ./build-2.2.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_1_0_2u;
        readline = tvp.packages.readline_8_3;
        zlib = tvp.packages.zlib_1_3_2;
        gdbm = tvp.packages.gdbm_1_26;
      };
    };
    "2.4.8" = {
      builder = ./build-2.2.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        readline = tvp.packages.readline_8_3;
        zlib = tvp.packages.zlib_1_3_2;
        gdbm = tvp.packages.gdbm_1_26;
      };
      patches = [
        {
          file = ./patches/rbinstall-gem-dir-umask.patch;
          reason = "2.4.8's tarball ships its bundled gems only as .gem files, and the .gem path creates each gem directory under rbinstall's own umask of 0222, so the first file written into it fails with EACCES. Every other 2.4 release also ships them unpacked and takes a path that chmods the directory itself.";
        }
      ];
    };
    "2.5.2" = {
      builder = ./build-2.2.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        readline = tvp.packages.readline_8_3;
        zlib = tvp.packages.zlib_1_3_2;
        gdbm = tvp.packages.gdbm_1_26;
      };
      opts = {
        restoreConfigScripts = true;
      };
    };
    "3.1.0" = {
      builder = ./build-3.1.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_3_5_7;
        readline = tvp.packages.readline_8_3;
        zlib = tvp.packages.zlib_1_3_2;
      };
    };

    "3.2.0" = {
      builder = ./build-3.2.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_3_5_7;
        readline = tvp.packages.readline_8_3;
        zlib = tvp.packages.zlib_1_3_2;
        libyaml = tvp.packages.libyaml_0_2_5;
        libffi = tvp.packages.libffi_3_8_0;
        rustc = tvp.packages.rustc_1_97_1;
      };
    };

    "3.3.0" = {
      builder = ./build-3.3.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        libyaml = tvp.packages.libyaml_0_2_5;
        libffi = tvp.packages.libffi_3_8_0;
        rustc = tvp.packages.rustc_1_97_1;
      };
    };

    # 3.4.0's tarball declares RUBY_PATCHLEVEL -1, marking it a development
    # build, so Ruby appends RUBY_ABI_VERSION to its lib directory. 3.4.1
    # restored patchlevel 0 and the suffix goes away again.
    "3.4.0" = {
      builder = ./build-3.3.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        libyaml = tvp.packages.libyaml_0_2_5;
        libffi = tvp.packages.libffi_3_8_0;
        rustc = tvp.packages.rustc_1_97_1;
      };
      opts = {
        libDir = "3.4.0+1";
      };
    };

    "4.0.0" = {
      builder = ./build-4.0.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        libyaml = tvp.packages.libyaml_0_2_5;
        libffi = tvp.packages.libffi_3_8_0;
        rustc = tvp.packages.rustc_1_97_1;
      };
    };
  };

  inherit (tvpLib.packages) merge mkTable;

  versionTable = merge {
    "2" = mkTable (import ./2.nix { inherit defs; });
    "3" = mkTable (import ./3.nix { inherit defs; });
    "4" = mkTable (import ./4.nix { inherit defs; });
  };
  pname = "ruby";

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests =
        ruby:
        import ./tests {
          inherit pkgs tvpLib ruby;
        };
    };

    # The tarball index rather than git tags: the tarball name is what the
    # source URL is derived from, and Ruby's tags use a different scheme
    # (v1_8_7_100 for what ships as ruby-1.8.7-p100.tar.gz).
    packageMeta = {
      upstream = {
        # One TSV listing every tarball back to 0.49, rather than one request per
        # minor directory. It also carries each sha256.
        type = "directory-index";
        url = "https://cache.ruby-lang.org/pub/ruby/index.txt";
        pattern = "ruby-[0-9][^[:space:]]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "ruby-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "ruby-" file)
          else
            null;

        # Patchlevel tarballs (1.8.7-p374) are real releases and stay.
        include =
          version:
          !(
            pkgs.lib.hasInfix "preview" version
            || pkgs.lib.hasInfix "-rc" version
            || pkgs.lib.hasInfix "beta" version
          );
      };
    };
  };

in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}

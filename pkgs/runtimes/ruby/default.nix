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
      # Keep configuration and extension callbacks in their supported dialect.
      opts.cStandard = "gnu17";
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer uses the pre-3 OpenSSL API (Ruby extconf upper bound or PHP RSA_SSLV23_PADDING); keep the 1.1 line.";
          } tvp.packages.openssl_1_1
        );
        readline = tvp.packages.readline_8;
        zlib = tvp.packages.zlib_1;
        gdbm = tvp.packages.gdbm_1;
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
      # ANYARGS callbacks require the pre-C23 unspecified-arguments semantics.
      opts.cStandard = "gnu17";
      # mkmf's headerless fallback intentionally probes undeclared functions.
      # GCC14 default-errors survive mkmf's Werror downgrade; 2.3 adds decls.
      opts.mkmfProbeFlags = [ "-Wno-error=implicit-function-declaration" ];
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer reaches OpenSSL structures made opaque in 1.1; use the 1.0 API line.";
          } tvp.packages.openssl_1_0
        );
        readline = tvp.packages.readline_8;
        zlib = tvp.packages.zlib_1;
        gdbm = tvp.packages.gdbm_1;
        libffi = tvp.packages.libffi_3;
      };
    };

    # Ruby's ext/readline used the Function typedef, which readline gated behind
    # WANT_OBSOLETE_TYPEDEFS at 6.3. Fixed upstream at 2.1.2.
    "2.0.0-p0" = {
      builder = ./build-2.0.nix;
      base = tvp.bases.default;
      # ANYARGS callbacks require the pre-C23 unspecified-arguments semantics.
      opts.cStandard = "gnu17";
      # mkmf's headerless fallback intentionally probes undeclared functions.
      # GCC14 default-errors survive mkmf's Werror downgrade; 2.3 adds decls.
      opts.mkmfProbeFlags = [ "-Wno-error=implicit-function-declaration" ];
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer reaches OpenSSL structures made opaque in 1.1; use the 1.0 API line.";
          } tvp.packages.openssl_1_0
        );
        readline = (
          tvp.lib.packages.withConstraint {
            reason = "Ruby 2.0 ext/readline casts to Function; readline 6.3 removed the obsolete typedef present in 6.2.";
          } tvp.packages.readline_6_2
        );
        zlib = tvp.packages.zlib_1;
        gdbm = tvp.packages.gdbm_1;
        libffi = tvp.packages.libffi_3;
      };
    };
    "2.2.0" = {
      builder = ./build-2.2.nix;
      base = tvp.bases.default;
      # ANYARGS callbacks require the pre-C23 unspecified-arguments semantics.
      opts.cStandard = "gnu17";
      # mkmf's headerless fallback intentionally probes undeclared functions.
      # GCC14 default-errors survive mkmf's Werror downgrade; 2.3 adds decls.
      opts.mkmfProbeFlags = [ "-Wno-error=implicit-function-declaration" ];
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer reaches OpenSSL structures made opaque in 1.1; use the 1.0 API line.";
          } tvp.packages.openssl_1_0
        );
        readline = tvp.packages.readline_8;
        zlib = tvp.packages.zlib_1;
        gdbm = tvp.packages.gdbm_1;
      };
    };
    "2.3.0" = {
      builder = ./build-2.2.nix;
      base = tvp.bases.default;
      # ANYARGS callbacks require the pre-C23 unspecified-arguments semantics.
      opts.cStandard = "gnu17";
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer reaches OpenSSL structures made opaque in 1.1; use the 1.0 API line.";
          } tvp.packages.openssl_1_0
        );
        readline = tvp.packages.readline_8;
        zlib = tvp.packages.zlib_1;
        gdbm = tvp.packages.gdbm_1;
      };
    };
    "2.4.8" = {
      builder = ./build-2.2.nix;
      base = tvp.bases.default;
      # Keep configuration and extension callbacks in their supported dialect.
      opts.cStandard = "gnu17";
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer uses the pre-3 OpenSSL API (Ruby extconf upper bound or PHP RSA_SSLV23_PADDING); keep the 1.1 line.";
          } tvp.packages.openssl_1_1
        );
        readline = tvp.packages.readline_8;
        zlib = tvp.packages.zlib_1;
        gdbm = tvp.packages.gdbm_1;
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
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer uses the pre-3 OpenSSL API (Ruby extconf upper bound or PHP RSA_SSLV23_PADDING); keep the 1.1 line.";
          } tvp.packages.openssl_1_1
        );
        readline = tvp.packages.readline_8;
        zlib = tvp.packages.zlib_1;
        gdbm = tvp.packages.gdbm_1;
      };
      # Actual native extension callbacks retain pre-C23 ANYARGS semantics.
      opts = {
        cStandard = "gnu17";
        restoreConfigScripts = true;
      };
    };
    "2.7.4" = {
      builder = ./build-2.7.4.nix;
      base = tvp.bases.default;
      # Keep configuration and extension callbacks in their supported dialect.
      opts.cStandard = "gnu17";
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer uses the pre-3 OpenSSL API (Ruby extconf upper bound or PHP RSA_SSLV23_PADDING); keep the 1.1 line.";
          } tvp.packages.openssl_1_1
        );
        readline = tvp.packages.readline_8;
        zlib = tvp.packages.zlib_1;
        gdbm = tvp.packages.gdbm_1;
      };
    };

    "2.6.0" = {
      builder = ./build-2.6.0.nix;
      base = tvp.bases.default;
      # Keep configuration and extension callbacks in their supported dialect.
      opts.cStandard = "gnu17";
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer uses the pre-3 OpenSSL API (Ruby extconf upper bound or PHP RSA_SSLV23_PADDING); keep the 1.1 line.";
          } tvp.packages.openssl_1_1
        );
        readline = tvp.packages.readline_8;
        zlib = tvp.packages.zlib_1;
        gdbm = tvp.packages.gdbm_1;
      };
    };
    "2.6.7" = {
      builder = ./build-2.6.0.nix;
      base = tvp.bases.default;
      # Keep configuration and extension callbacks in their supported dialect.
      opts.cStandard = "gnu17";
      # vm.c omits the existing mutex-destroy declaration only in this release.
      opts.compileFlags = [ "-Wno-error=implicit-function-declaration" ];
      deps = {
        openssl = (
          tvp.lib.packages.withConstraint {
            reason = "Consumer uses the pre-3 OpenSSL API (Ruby extconf upper bound or PHP RSA_SSLV23_PADDING); keep the 1.1 line.";
          } tvp.packages.openssl_1_1
        );
        readline = tvp.packages.readline_8;
        zlib = tvp.packages.zlib_1;
        gdbm = tvp.packages.gdbm_1;
      };
    };
    "3.1.0" = {
      builder = ./build-3.1.nix;
      base = tvp.bases.default;
      # Configure and native extensions must share a pre-C23 bool/ANYARGS dialect.
      opts.cStandard = "gnu17";
      # The old configure main() probe rejects __func__ with this warning.
      # 3.1.3 regenerates it with main(void). Preserve the remaining warning list.
      opts.extraWarnFlags = [ "-Wno-old-style-definition" ];
      deps = {
        openssl = tvp.packages.openssl_3;
        readline = tvp.packages.readline_8;
        zlib = tvp.packages.zlib_1;
      };
    };

    "3.1.3" = {
      builder = ./build-3.1.nix;
      base = tvp.bases.default;
      # Configure and native extensions must share a pre-C23 bool/ANYARGS dialect.
      opts.cStandard = "gnu17";
      deps = {
        openssl = tvp.packages.openssl_3;
        readline = tvp.packages.readline_8;
        zlib = tvp.packages.zlib_1;
      };
    };

    "3.2.0" = {
      builder = ./build-3.2.nix;
      base = tvp.bases.default;
      # Configure and native extensions must share a pre-C23 bool/ANYARGS dialect.
      opts.cStandard = "gnu17";
      deps = {
        openssl = tvp.packages.openssl_3;
        readline = tvp.packages.readline_8;
        zlib = tvp.packages.zlib_1;
        libyaml = tvp.packages.libyaml;
        libffi = tvp.packages.libffi_3;
        rustc = tvp.packages.rustc_1;
      };
    };

    "3.3.0" = {
      builder = ./build-3.3.nix;
      base = tvp.bases.default;
      # Configure and native extensions must share a pre-C23 bool/ANYARGS dialect.
      opts.cStandard = "gnu17";
      deps = {
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        libyaml = tvp.packages.libyaml;
        libffi = tvp.packages.libffi_3;
        rustc = tvp.packages.rustc_1;
      };
    };

    # 3.4.0's tarball declares RUBY_PATCHLEVEL -1, marking it a development
    # build, so Ruby appends RUBY_ABI_VERSION to its lib directory. 3.4.1
    # restored patchlevel 0 and the suffix goes away again.
    "3.4.0" = {
      builder = ./build-3.3.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        libyaml = tvp.packages.libyaml;
        libffi = tvp.packages.libffi_3;
        rustc = tvp.packages.rustc_1;
      };
      # Configure and native extensions must share a pre-C23 bool/ANYARGS dialect.
      opts = {
        cStandard = "gnu17";
        libDir = "3.4.0+1";
      };
    };

    "3.3.9" = {
      builder = ./build-3.3.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        libyaml = tvp.packages.libyaml;
        libffi = tvp.packages.libffi_3;
        rustc = tvp.packages.rustc_1;
      };
    };

    # 3.4.0's tarball declares RUBY_PATCHLEVEL -1, marking it a development
    # build, so Ruby appends RUBY_ABI_VERSION to its lib directory. 3.4.1
    # restored patchlevel 0 and the suffix goes away again.
    "4.0.0" = {
      builder = ./build-4.0.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_3;
        zlib = tvp.packages.zlib_1;
        libyaml = tvp.packages.libyaml;
        libffi = tvp.packages.libffi_3;
        rustc = tvp.packages.rustc_1;
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

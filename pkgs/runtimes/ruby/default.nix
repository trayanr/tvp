{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  # Upstream's OpenSSL bound (ext/openssl/extconf.rb) gains "< 3.0.0" at 2.7.5
  # and again at 3.0.3, then drops the upper limit entirely at 3.1. So 2.7 and
  # 3.0 pin 1.1.1w — the latest release their own bound admits — and 3.1 upwards
  # pin 3.5.7, the latest LTS line TVP owns.
  defs = {
    "2.6.0" = {
      builder = ./build-2.7.nix;
      base = tvp.bases.gcc13;
      deps = {
        openssl = tvp.packages.openssl_1_1_1w;
        readline = tvp.packages.readline_8_3;
        zlib = tvp.packages.zlib_1_3_2;
        gdbm = tvp.packages.gdbm_1_26;
      };
    };

    "3.1.0" = {
      builder = ./build-3.1.nix;
      base = tvp.bases.gcc13;
      deps = {
        openssl = tvp.packages.openssl_3_5_7;
        readline = tvp.packages.readline_8_3;
        zlib = tvp.packages.zlib_1_3_2;
      };
    };

    "3.2.0" = {
      builder = ./build-3.2.nix;
      base = tvp.bases.gcc13;
      deps = {
        openssl = tvp.packages.openssl_3_5_7;
        readline = tvp.packages.readline_8_3;
        zlib = tvp.packages.zlib_1_3_2;
        libyaml = pkgs.libyaml;
        libffi = pkgs.libffi;
        rustc = tvp.packages.rustc_1_97_1;
      };
    };

    "3.3.0" = {
      builder = ./build-3.3.nix;
      base = tvp.bases.gcc13;
      deps = {
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        libyaml = pkgs.libyaml;
        libffi = pkgs.libffi;
        rustc = tvp.packages.rustc_1_97_1;
      };
    };

    # 3.4.0's tarball declares RUBY_PATCHLEVEL -1, marking it a development
    # build, so Ruby appends RUBY_ABI_VERSION to its lib directory. 3.4.1
    # restored patchlevel 0 and the suffix goes away again.
    "3.4.0" = {
      builder = ./build-3.3.nix;
      base = tvp.bases.gcc13;
      deps = {
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        libyaml = pkgs.libyaml;
        libffi = pkgs.libffi;
        rustc = tvp.packages.rustc_1_97_1;
      };
      opts = {
        libDir = "3.4.0+1";
      };
    };

    "4.0.0" = {
      builder = ./build-4.0.nix;
      base = tvp.bases.gcc13;
      deps = {
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        libyaml = pkgs.libyaml;
        libffi = pkgs.libffi;
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
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    pname = "ruby";
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

  aliases = {
    ruby_2_7 = canonical.ruby_2_7_8;
    ruby_2 = canonical.ruby_2_7_8;

    ruby_3_0 = canonical.ruby_3_0_7;
    ruby_3_1 = canonical.ruby_3_1_7;
    ruby_3_2 = canonical.ruby_3_2_11;
    ruby_3_3 = canonical.ruby_3_3_12;
    ruby_3_4 = canonical.ruby_3_4_10;
    ruby_3 = canonical.ruby_3_4_10;

    ruby_4_0 = canonical.ruby_4_0_6;
    ruby_4 = canonical.ruby_4_0_6;

    # Not 4.0.6: that line is built with both JITs off, against upstream's
    # default, until TVP has a rustc new enough. 3.4.10 is the newest built the
    # way upstream builds it.
    ruby = canonical.ruby_3_4_10;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }

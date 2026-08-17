{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  # Upstream's OpenSSL bound (ext/openssl/extconf.rb) gains "< 3.0.0" at 2.7.5
  # and 3.0.3, then drops the upper limit entirely at 3.1. So 1.1.1w is the
  # latest compatible release only through 3.0; from 3.1 it is merely the newest
  # OpenSSL TVP owns, and the pin moves when TVP packages a 3.x.
  versionTable = tvpLib.packages.merge {
    "2" = import ./2.nix { inherit pkgs tvp; };
    "3" = import ./3 { inherit pkgs tvp; };
    "4" = import ./4.nix { inherit pkgs tvp; };
  };
  canonical = tvpLib.packages.mkVersions {
    inherit (pkgs) callPackage;
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
        type = "directory-index";
        url = "https://cache.ruby-lang.org/pub/ruby/";
        subdirPattern = "[0-9][^/\"]*";
        pattern = "ruby-[0-9][^\"]*\\.tar\\.gz";

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

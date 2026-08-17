# One suite, shared by every Ruby version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  ruby,
}:
let
  inherit (ruby.passthru.tvp) deps;

  # sha256("tvp"), first 16 hex characters.
  tvpDigest = "f6f6ead0bd85c312";
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = ruby;

  tests =
    {
      version = {
        script = ''
          ruby -e 'print RUBY_VERSION'
        '';
        expected = ruby.version;
      };

      smoke = {
        script = ''
          ruby ${./fixtures/smoke.rb}
        '';
        expected = "220";
      };

      stdlib = {
        script = ''
          ruby ${./fixtures/stdlib.rb}
        '';
        expected = "${tvpDigest}:6";
      };

      # runCommand is stdenvNoCC, and rbconfig records the compiler by bare name.
      compile = {
        script = ''
          mkdir -p ext && cd ext
          cp ${./fixtures/ext-extconf.rb} extconf.rb
          cp ${./fixtures/ext-tvp.c} tvp_ext.c
          ruby extconf.rb > /dev/null
          make > /dev/null
          ruby -I. -e 'require "tvp_ext"; print TvpExt.answer'
        '';
        expected = "42";
        extraInputs = [ pkgs.stdenv.cc ];
      };

      openssl = {
        script = ''
          ruby -e 'require "openssl"; print [OpenSSL::OPENSSL_VERSION.split[1], OpenSSL::Digest::SHA256.hexdigest("tvp")[0, 16]].join(" ")'
        '';
        expected = "${deps.openssl.version} ${tvpDigest}";
      };

      zlib = {
        script = ''
          ruby -e 'require "zlib"; s = "tvp" * 100; print(Zlib::Inflate.inflate(Zlib::Deflate.deflate(s)) == s ? "roundtrip-ok" : "MISMATCH")'
        '';
        expected = "roundtrip-ok";
      };

      # Two processes, so the value is proven to have been written.
      gdbm = {
        script = ''
          ruby -e 'require "gdbm"; GDBM.open("tvp.db") { |db| db["k"] = "v" }'
          ruby -e 'require "gdbm"; GDBM.open("tvp.db") { |db| print db["k"] }'
        '';
        expected = "v";
      };

      readline = {
        script = ''
          ruby -e 'require "readline"; print Readline.respond_to?(:readline) ? "readline-ok" : "MISSING"'
        '';
        expected = "readline-ok";
      };

      gems = {
        script = ''
          ruby -e 'require "rubygems"; print Gem.default_dir'
        '';
        expected = "${ruby}/${ruby.passthru.gemPath}";
      };
    }

    # ldd is glibc's; Darwin needs otool -L, as a separate test.
    // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      # Proves the declared OpenSSL is what is linked, not merely one reporting
      # the same version.
      openssl-linkage = {
        script = ''
          so=$(ruby -e 'require "openssl"; print $LOADED_FEATURES.grep(/openssl\.so$/).first')
          ldd "$so" | awk '/libssl\.so/ { print $3 }' | grep -q "^${deps.openssl.out}/" && printf linked
        '';
        expected = "linked";
        extraInputs = [ pkgs.glibc.bin ];
      };
    };
}

{ lib, stdenv, fetchurl, readline, zlib, gdbm, openssl }:

stdenv.mkDerivation rec {
  pname = "ruby";
  version = "2.7.0";
  # prefer builtins
  src = fetchurl {
    url = "https://cache.ruby-lang.org/pub/ruby/2.7/ruby-${version}.tar.gz";
    sha256 = "sha256-jJmqk7Xi8byEN9G7vv0nsT52lAJTMfdyRdDAaO8fjL4=";
  };

  buildInputs = [ openssl readline zlib gdbm ];

  configureFlags = [
    "--enable-shared"
    "--with-openssl-dir=${openssl.dev}"
    "--with-readline-dir=${readline.dev}"
    "--with-zlib-dir=${zlib.dev}"
    "--with-gdbm-dir=${gdbm}"
  ];

  preInstall = ''
	# Ruby installs gems here itself now.
	mkdir -pv "$out/${passthru.gemPath}"
	export GEM_HOME="$out/${passthru.gemPath}"
  '';

  postInstall = ''
    # Bundler tries to create this directory
    mkdir -p $out/nix-support
    cat > $out/nix-support/setup-hook <<EOF
    addGemPath() {
      addToSearchPath GEM_PATH \$1/${passthru.gemPath}
    }
    addRubyLibPath() {
      addToSearchPath RUBYLIB \$1/lib/ruby/site_ruby
      addToSearchPath RUBYLIB \$1/lib/ruby/site_ruby/${version}
      addToSearchPath RUBYLIB \$1/lib/ruby/site_ruby/${version}/${stdenv.targetPlatform.system}
    }

    addEnvHooks "$hostOffset" addGemPath
    addEnvHooks "$hostOffset" addRubyLibPath
    EOF
  '';

  meta = with lib; {
    description = "The Ruby programming language";
    homepage = "https://www.ruby-lang.org/";
    license = licenses.ruby;
    platforms = platforms.unix;
  };
  
  passthru = rec {
	inherit version;
	rubyEngine = "ruby";
	baseRuby = false;
	libPath = "lib/${rubyEngine}/${version}";
	gemPath = "lib/${rubyEngine}/gems/${version}";

	majorVersion = "2";
	minorVersion = "7";
	teenyVersion = "0";
	patchLevel = null;
  };
}

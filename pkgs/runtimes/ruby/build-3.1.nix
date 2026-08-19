# Serves 3.1 onwards. Upstream deleted ext/gdbm, ext/dbm and ext/sdbm at 3.1,
# so the gdbm argument goes away.
{
  lib,
  stdenv,
  fetchurl,

  version,
  sha256,

  openssl,
  readline,
  zlib,

  # Ruby's ABI directory, not the package version: every 2.7.x uses "2.7.0".
  # Overridden per version where upstream disagrees.
  libDir ? "${lib.versions.majorMinor version}.0",

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "ruby";
  inherit version;

  src = fetchurl {
    url = "https://cache.ruby-lang.org/pub/ruby/${lib.versions.majorMinor version}/ruby-${version}.tar.gz";
    inherit sha256;
  };

  buildInputs = [
    openssl
    readline
    zlib
  ];

  # getDev, not .dev, so a dependency need not be output-split.
  configureFlags = [
    "--enable-shared"
    "--with-openssl-dir=${lib.getDev openssl}"
    "--with-readline-dir=${lib.getDev readline}"
    "--with-zlib-dir=${lib.getDev zlib}"
  ];

  preInstall = ''
    # Ruby installs gems here itself now.
    mkdir -pv "$out/${finalAttrs.passthru.gemPath}"
    export GEM_HOME="$out/${finalAttrs.passthru.gemPath}"
  '';

  postInstall = ''
    # Bundler tries to create this directory
    mkdir -p $out/nix-support
    cat > $out/nix-support/setup-hook <<EOF
    addGemPath() {
      addToSearchPath GEM_PATH \$1/${finalAttrs.passthru.gemPath}
    }
    addRubyLibPath() {
      addToSearchPath RUBYLIB \$1/lib/ruby/site_ruby
      addToSearchPath RUBYLIB \$1/lib/ruby/site_ruby/${libDir}
      addToSearchPath RUBYLIB \$1/lib/ruby/site_ruby/${libDir}/${stdenv.targetPlatform.system}
    }

    addEnvHooks "$hostOffset" addGemPath
    addEnvHooks "$hostOffset" addRubyLibPath
    EOF
  '';

  meta = {
    description = "The Ruby programming language";
    homepage = "https://www.ruby-lang.org/";
    license = lib.licenses.ruby;
    platforms = lib.platforms.unix;
    mainProgram = "ruby";
  };

  passthru = {
    inherit version libDir;
    rubyEngine = "ruby";
    baseRuby = false;

    # Inlined into build scripts by consumers (buildRubyGem), so these reach
    # derivations despite living in passthru.
    libPath = "lib/ruby/${libDir}";
    gemPath = "lib/ruby/gems/${libDir}";

    majorVersion = lib.versions.major version;
    minorVersion = lib.versions.minor version;
    teenyVersion = lib.versions.patch version;
    patchLevel = null;

    # Language capability has nothing in the dependency graph to read, so the
    # builder states it and the suite guards on it.
    tvp.features = {
      enumerableSum = lib.versionAtLeast version "2.4";
      yamlSafeLoad = lib.versionAtLeast version "2.1";
    };

    tvp.deps = {
      inherit
        openssl
        readline
        zlib
        ;
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

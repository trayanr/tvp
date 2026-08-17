# Serves 3.2 onwards. Upstream stopped vendoring ext/psych/yaml and
# ext/fiddle/libffi at 3.2, so both become system dependencies, and YJIT was
# rewritten from C to Rust so it needs a toolchain 3.1 did not.
{
  lib,
  stdenv,
  fetchurl,

  version,
  sha256,

  openssl,
  readline,
  zlib,
  libyaml,
  libffi,
  rustc,

  # Upstream enables YJIT whenever a usable rustc is present, so true matches
  # the default build. Stated as a flag rather than left to detection: a
  # sandbox that happens to lack rustc must not silently ship a JIT-less Ruby.
  yjit ? true,

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
    libyaml
    libffi
  ];

  nativeBuildInputs = lib.optional yjit rustc;

  # getDev, not .dev, so a dependency need not be output-split.
  configureFlags = [
    "--enable-shared"
    "--with-openssl-dir=${lib.getDev openssl}"
    "--with-readline-dir=${lib.getDev readline}"
    "--with-zlib-dir=${lib.getDev zlib}"
    (if yjit then "--enable-yjit" else "--disable-yjit")
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

    tvp.deps = {
      inherit
        openssl
        readline
        zlib
        libyaml
        libffi
        ;
    } // lib.optionalAttrs yjit { inherit rustc; };

    tvp.jit = {
      inherit yjit;
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

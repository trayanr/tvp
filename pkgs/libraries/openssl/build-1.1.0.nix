# Serves 1.1.0.
#
# Configure imports `glob` from File::Glob, which Perl stopped exporting in 5.30.
# Upstream's own fix at 1.1.0h was to delete the import and use the builtin; the
# same deletion is applied here to the releases that predate it.
#
# `./config` shells out to /usr/bin/env to detect the host, which does not exist
# in the sandbox and is not a shebang, so patchShebangs cannot reach it.
# `./Configure` with an explicit target avoids host detection entirely.
{
  lib,
  stdenv,
  fetchurl,
  perl,

  version,
  sha256,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
let
  # An unlisted platform throws rather than silently falling back to ./config.
  targets = {
    x86_64-linux = "linux-x86_64";
    aarch64-linux = "linux-aarch64";
    i686-linux = "linux-x86";
    armv7l-linux = "linux-armv4 -march=armv7-a";
    powerpc64le-linux = "linux-ppc64le";
    riscv64-linux = "linux64-riscv64";
    x86_64-darwin = "darwin64-x86_64-cc";
    aarch64-darwin = "darwin64-arm64-cc";
  };

  inherit (stdenv.hostPlatform) system;

  target =
    targets.${system} or (throw "openssl ${version}: no Configure target for ${system}; add one here.");

  underscoreVersion = builtins.replaceStrings [ "." ] [ "_" ] version;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "openssl";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openssl/openssl/releases/download/OpenSSL_${underscoreVersion}/openssl-${version}.tar.gz";
    inherit sha256;
  };

  nativeBuildInputs = [ perl ];

  postPatch = ''
    sed -i "/'File::Glob' => qw\/glob\//d" Configure test/build.info
    patchShebangs Configure
  '';

  configureScript = "./Configure ${target}";

  configureFlags = [
    "shared"
    "--libdir=lib"
    "--openssldir=etc/ssl"
  ];

  installTargets = [ "install_sw" ];

  # Parallel building is not reliable in OpenSSL
  enableParallelBuilding = false;

  meta = {
    description = "A cryptographic library that implements the SSL and TLS protocols";
    homepage = "https://www.openssl.org/";
    license = lib.licenses.openssl;
    platforms = lib.platforms.unix;
    mainProgram = "openssl";
  };

  passthru = {
    inherit version;
    tvp.deps = { };

    tvp.features = {
      sha256 = true;
      pbkdf2 = false;
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})

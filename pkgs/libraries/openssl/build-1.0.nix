# Serves 0.9 through 1.0.
#
# `Configure` here opens with the `eval 'exec perl'` trick rather than a shebang,
# so patchShebangs has nothing to rewrite and perl must be named explicitly.
# `--libdir` does not exist before 1.1.0, and this generation needs an explicit
# `make depend` before the build.
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
    i686-linux = "linux-elf";
    armv7l-linux = "linux-armv4";
    powerpc64le-linux = "linux-ppc64le";
    x86_64-darwin = "darwin64-x86_64-cc";
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
    patchShebangs Configure
  '';

  configureScript = "perl ./Configure ${target}";

  configureFlags = [
    "shared"
    "--openssldir=etc/ssl"
  ];

  preBuild = ''
    make depend
  '';

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

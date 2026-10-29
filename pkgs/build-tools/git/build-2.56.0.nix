{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  patchelf,
  bash,
  perl,
  python,
  curl,
  openssl,
  zlib,
  expat,
  pcre2,
  rustc,
  cargo,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "git";
  inherit version;
  src = fetchurl {
    url = "https://www.kernel.org/pub/software/scm/git/git-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    rustc
    cargo
    pkg-config
    patchelf
    perl
    python
  ];
  buildInputs = [
    curl
    openssl
    zlib
    expat
    pcre2
  ];
  preConfigure = ''
    export CARGO_HOME="$TMPDIR/cargo-home" CARGO_NET_OFFLINE=true
    export PKG_CONFIG_PATH='${curl}/lib/pkgconfig:${openssl}/lib/pkgconfig:${zlib}/lib/pkgconfig:${expat}/lib/pkgconfig:${pcre2}/lib/pkgconfig'
    patchShebangs t
  '';
  configureFlags = [
    "--with-curl=${curl}"
    "--with-openssl=${openssl}"
    "--with-expat=${expat}"
    "--with-zlib=${zlib}"
  ];
  makeFlags = [
    "SHELL_PATH=${bash}/bin/bash"
    "PERL_PATH=${perl}/bin/perl"
    "PYTHON_PATH=${python}/bin/python3"
    "CURL_CONFIG=${curl}/bin/curl-config"
    "NO_GETTEXT=YesPlease"
    "NO_TCLTK=YesPlease"
    "USE_LIBPCRE2=YesPlease"
  ];
  enableParallelBuilding = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cd t
    ${bash}/bin/bash t0000-basic.sh --verbose-log
    # t0001-init requires chmod g+s, which Nix's syscall filter forbids.
    # The complete unchanged fixture was also validated on the native host.
    ${bash}/bin/bash t0008-ignores.sh --verbose-log
    ${bash}/bin/bash t1300-config.sh --verbose-log
    cd ..
    runHook postCheck
  '';
  postFixup = ''
    while IFS= read -r -d "" binary; do
      if isELF "$binary"; then patchelf --shrink-rpath "$binary"; fi
    done < <(find "$out/bin" "$out/libexec" -type f -print0)
  '';
  meta = {
    description = "Git version control system with owned HTTP transport and PCRE2";
    homepage = "https://git-scm.com/";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "git";
  };
  passthru = {
    tvp.deps = {
      inherit
        rustc
        cargo
        pkg-config
        patchelf
        bash
        perl
        python
        curl
        openssl
        zlib
        expat
        pcre2
        ;
    };
    tvp.features = {
      http = true;
      pcre2 = true;
      gui = false;
      gettext = false;
      manpages = false;
      bundledSshClient = false;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

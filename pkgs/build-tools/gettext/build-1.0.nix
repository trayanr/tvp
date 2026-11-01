# Gettext 1.0 introduces spit: require its native JSON-C/shared-curl backend.
{
  lib,
  stdenv,
  fetchurl,
  version,
  sha256,
  mkTests,
  bash,
  pkg-config,
  json-c,
  curl,
  ncurses,
  libxml2,
  acl,
  attr,
  perl,
  python,
  jdk,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gettext";
  inherit version;
  src = fetchurl {
    urls = [
      "https://mirrors.kernel.org/gnu/gettext/gettext-${version}.tar.xz"
      "https://ftp.gnu.org/gnu/gettext/gettext-${version}.tar.xz"
    ];
    inherit sha256;
  };
  nativeBuildInputs = [
    pkg-config
    perl
    python
    jdk
  ];
  buildInputs = [
    bash
    json-c
    curl
    ncurses
    libxml2
    acl
    attr
  ];
  postPatch = ''
    # Installed shell helpers must work without a caller-provided tool PATH.
    substituteInPlace gettext-runtime/src/gettext.sh.in \
      --replace-fail '  gettext ' '  '"$out"'/bin/gettext ' \
      --replace-fail '  ngettext ' '  '"$out"'/bin/ngettext ' \
      --replace-fail 'envsubst ' '"'"$out"'/bin/envsubst" '
    # Generated config headers embed the shell for msgexec/spit --postprocess.
    substituteInPlace gettext-tools/config.h.in \
      --replace-fail 'define BOURNE_SHELL "/bin/sh"' 'define BOURNE_SHELL "${bash}/bin/bash"'
    # The owned Ncurses profile provides the wide library. Its terminfo API is
    # unchanged; search that name while retaining upstream's link probes.
    # Patch the release-generated configure without requiring autoreconf.
    substituteInPlace libtextstyle/configure \
      --replace-fail "names_next_round='ncurses '" "names_next_round='ncursesw '"
    patchShebangs .
  '';
  configureFlags = [
    "--with-libxml2-prefix=${libxml2}"
    "--with-libncurses-prefix=${ncurses}"
  ];
  postConfigure = ''
    grep -q '^am__append_1 = spit$' gettext-tools/src/Makefile || {
      echo 'Gettext requires native spit with JSON-C and shared curl' >&2; exit 1;
    }
    grep -q '^#define HAVE_TERMINFO 1$' libtextstyle/config.h || {
      echo 'Gettext styling requires owned Ncurses terminfo support' >&2; exit 1;
    }
    grep '^LIBTERMINFO = ' libtextstyle/Makefile \
      | grep -F '${ncurses}/lib/libncursesw.so' || exit 1
  '';
  enableParallelBuilding = true;
  # Upstream shell fixtures share temporary paths; run the shipped suite serially.
  doCheck = true;
  enableParallelChecking = false;
  meta = {
    description = "GNU translation tools, text styling and native machine translation frontend";
    homepage = "https://www.gnu.org/software/gettext/";
    license = [
      lib.licenses.gpl3Plus
      lib.licenses.lgpl21Plus
    ];
    platforms = lib.platforms.unix;
    mainProgram = "gettext";
  };
  passthru = {
    tvp.cc = stdenv.cc;
    tvp.deps = {
      inherit
        bash
        pkg-config
        json-c
        curl
        ncurses
        libxml2
        acl
        attr
        perl
        python
        jdk
        ;
    };
    tvp.features = {
      nls = true;
      nativeSpit = true;
      xml = true;
      styling = true;
      java = true;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})

# curl 8.7 uses the OpenSSL 3 API and exports link flags in Libs.private.
{
  tvp,
  lib,
  base,
  src,
  version,
  openssl,
  zlib,
  zstd,
  brotli,
  nghttp2,
  openldap,
  krb5,
  ca-certificates,
  manualSources ? null,
  doCheck ? true,
}:

final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = name: steps.command { environment = final.environment; } "curl.${name}";
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  elfPaths = [
    "bin/curl"
    "lib/${final.installedInterface.libraryFile}"
  ];
  preparePlan = [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
  ]
  ++ lib.optional (final.manualSources != null) (
    steps.command
      {
        environment.tools = [
          tools.gnutar
          tools.gzip
        ];
      }
      "curl.restore-manual-sources"
      ''
        tar -xzf ${final.manualSources} --strip-components=1 --skip-old-files --wildcards '*/docs/libcurl/*.md'
        # The 8.7.0 release shipped a stub. Use the upstream generation rule.
        rm src/tool_hugehelp.c
      ''
  )
  ++ [
    (steps.prepareAutotools { name = "curl.prepare"; })
    (steps.shebangs {
      name = "curl.documentation-scripts";
      paths = [ "scripts/cd2nroff" ];
      names = [ "perl" ];
      interpreter = "${tools.perl}/bin/perl";
    })
  ];
  buildPlan = [
    # The optional providers below the CA configuration are absent in TVP.
    # Keep curl's threaded resolver and native NTLM support.
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      export PERL=${tools.perl}/bin/perl
      ./configure --prefix="$out" --enable-option-checking=fatal \
        --enable-shared --disable-static --disable-dependency-tracking \
        --enable-docs --enable-manual --enable-threaded-resolver \
        --with-openssl=${final.openssl} --with-zlib=${final.zlib} --with-zstd=${final.zstd} \
        --with-brotli=${final.brotli} --with-nghttp2=${final.nghttp2} \
        --enable-ldap --enable-ldaps --with-gssapi=${final.krb5} \
        --with-ca-bundle=${final.ca-certificates}/etc/ssl/certs/ca-bundle.crt --without-ca-path \
        --disable-ares --without-libpsl --without-libidn2 --without-libgsasl \
        --without-libssh2 --without-libssh --without-wolfssh --without-librtmp \
        --disable-ntlm-wb \
        --without-openssl-quic --without-ngtcp2 --without-nghttp3 --without-quiche --without-msh3
    '')
    (command "build" make)
  ];
in
{
  pname = "curl";
  inherit (tools) bash coreutils;
  inherit
    base
    src
    version
    openssl
    zlib
    zstd
    brotli
    nghttp2
    openldap
    krb5
    ca-certificates
    manualSources
    doCheck
    ;

  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      tools.pkg-config
      tools.perl
    ];
    libraries = [
      final.openssl
      final.zlib
      final.zstd
      final.brotli
      final.nghttp2
      final.openldap
      final.krb5
    ];
    # Keep Autoconf's pre-C23 function probes usable with the current GNU base.
    overrides.values.CFLAGS = "-O2 -std=gnu17";
  };
  runtime.libraries = final.environment.libraries;
  installedInterface = {
    soname = "libcurl.so.4";
    libraryFile = "libcurl.so.4.8.0";
  };

  plan = steps.sequence (
    preparePlan
    ++ buildPlan
    ++ [
      (command "install" ''
        ${make} install
        mkdir -p "$out/nix-support"
        cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
        test -f "$out/lib/${final.installedInterface.libraryFile}"
        test ! -e "$out/lib/libcurl.a"
      '')
      (steps.split "curl.finalize")
      (outputs.copyArtifacts { })
      (outputs.relocateText {
        paths = [
          "bin/curl-config"
          "lib/pkgconfig/libcurl.pc"
          "lib/libcurl.la"
        ];
      })
      (outputs.shebangs {
        paths = [ "bin/curl-config" ];
        names = [ "sh" ];
        interpreter = "${final.bash}/bin/bash";
      })
      (outputs.strip { paths = elfPaths; })
      (outputs.libtool { paths = [ "lib" ]; })
      (outputs.rpaths {
        paths = elfPaths;
        libraries = final.runtime.libraries;
      })
      (outputs.development { libraries = final.environment.libraries; })
      (outputs.checkSymlinks {
        paths = [
          "lib/libcurl.so"
          "lib/${final.installedInterface.soname}"
        ];
      })
      (outputs.checkPaths { paths = elfPaths; })
    ]
  );
  upstreamPlan = steps.sequence (
    preparePlan
    ++ [
      (steps.shebangs {
        name = "curl.upstream-shell-scripts";
        paths = [ "tests" ];
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${final.bash}/bin/bash";
      })
      (steps.shebangs {
        name = "curl.upstream-perl-scripts";
        paths = [ "tests" ];
        names = [ "perl" ];
        interpreter = "${tools.perl}/bin/perl";
      })
    ]
    ++ buildPlan
  );
  upstreamCheck =
    (command "check" ''
      status=0
      ${make} -C tests test TFLAGS='1 2 3 4 5 6 7 8 9 10' > upstream-tests.log 2>&1 || status=$?
      cat upstream-tests.log
      printf '%s\n' "$status" > upstream-tests.status
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
    };
  tvp.features = {
    doCheck = final.doCheck;
    tls = true;
    http2 = true;
    http3 = false;
    idn = false;
    publicSuffixList = false;
    ssh = false;
    ldap = true;
    ldaps = true;
    gssapi = true;
    brotli = true;
    shared = true;
    static = false;
    gzip = true;
    zstd = true;
  };
  meta = {
    description = "URL transfer client and library with TLS, HTTP/2 and compression";
    homepage = "https://curl.se/";
    license = lib.licenses.curl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "curl";
  };
}

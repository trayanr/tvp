# Independent ordinary native Curl 8.23.0 procedure. Preserve the realized
# default-base shared-only profile explicitly. Installation produces A;
# installed metadata and runtime library repair happen in F.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnumake,
  gnutar,
  gzip,
  gnused,
  gnugrep,
  gawk,
  diffutils,
  findutils,
  pkg-config,
  patchelf,
  perl,
  python,
  openssl,
  zlib,
  zstd,
  nghttp2,
  ca-certificates,
  binutils,
  configureOptions,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "curl.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  elfPaths = [
    "bin/curl"
    "lib/libcurl.so.4.8.0"
  ];
in
{
  pname = "curl";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      gnumake
      gnused
      gnugrep
      gawk
      diffutils
      findutils
      pkg-config
      perl
      python
      openssl
    ];
    libraries = [
      openssl
      zlib
      zstd
      nghttp2
    ];
  };
  runtime.libraries = [
    openssl
    zlib
    zstd
    nghttp2
  ];
  artifactPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      inherit python;
      bash = final.bash;
      base = final.base;
      name = "curl.prepare";
    })
    (steps.shebangs {
      name = "curl.shell-scripts";
      inherit python;
      paths = [
        "scripts"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (steps.shebangs {
      name = "curl.perl-scripts";
      inherit python;
      paths = [
        "scripts"
      ];
      names = [ "perl" ];
      interpreter = "${perl}/bin/perl";
    })
    (steps.shebangs {
      name = "curl.python-scripts";
      inherit python;
      paths = [
        "scripts"
      ];
      names = [
        "python"
        "python3"
      ];
      interpreter = "${python}/bin/python3";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      export PERL=${perl}/bin/perl PYTHON=${python}/bin/python3
      ./configure --prefix="$out" --enable-shared --disable-static --disable-dependency-tracking \
        --with-openssl=${openssl} --with-zlib=${zlib} --with-zstd=${zstd} --with-nghttp2=${nghttp2} \
        --with-ca-bundle=${ca-certificates}/etc/ssl/certs/ca-bundle.crt --without-ca-path \
        ${lib.escapeShellArgs configureOptions}
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      test -f "$out/lib/libcurl.so.4.8.0"
      test ! -e "$out/lib/libcurl.a"
    '')
  ];
  inherit doCheck;
  upstreamPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      inherit python;
      bash = final.bash;
      base = final.base;
      name = "curl.prepare";
    })
    (steps.shebangs {
      name = "curl.shell-scripts";
      inherit python;
      paths = [
        "scripts"
        "tests"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (steps.shebangs {
      name = "curl.perl-scripts";
      inherit python;
      paths = [
        "scripts"
        "tests"
      ];
      names = [ "perl" ];
      interpreter = "${perl}/bin/perl";
    })
    (steps.shebangs {
      name = "curl.python-scripts";
      inherit python;
      paths = [
        "scripts"
        "tests"
      ];
      names = [
        "python"
        "python3"
      ];
      interpreter = "${python}/bin/python3";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      export PERL=${perl}/bin/perl PYTHON=${python}/bin/python3
      ./configure --prefix="$out" --enable-shared --disable-static --disable-dependency-tracking \
        --with-openssl=${openssl} --with-zlib=${zlib} --with-zstd=${zstd} --with-nghttp2=${nghttp2} \
        --with-ca-bundle=${ca-certificates}/etc/ssl/certs/ca-bundle.crt --without-ca-path \
        ${lib.escapeShellArgs configureOptions}
    '')
    (command "build" make)
  ];
  upstreamCheck =
    (
      (command "check" ''
        status=0
        ${make} -C tests test TFLAGS='1 2 3 4 5 6 7 8 9 10' > upstream-tests.log 2>&1 || status=$?
        cat upstream-tests.log
        printf '%s\n' "$status" > upstream-tests.status
        exit "$status"
      '')
      // {
        enabled = final.doCheck;
      }
    );
  plan = steps.sequence (final.artifactPlan ++ [
    (steps.split "curl.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (outputs.relocateText {
      inherit python;
      paths = ["bin/curl-config" "lib/pkgconfig" "lib/libcurl.la"];
    })
    (outputs.shebangs {
      inherit python;
      paths = [ "bin/curl-config" ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.libtool {
      inherit python;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    # libcurl.pc Requires.private names all four even in the shared-only profile.
    (outputs.development {
      inherit python;
      libraries = [
        zlib
        zstd
        openssl
        nghttp2
      ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libcurl.so"
        "lib/libcurl.so.4"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ]);
  tvp.features = {
    inherit doCheck;
    tls = true;
    http2 = true;
    http3 = false;
    idn = false;
    publicSuffixList = false;
    ssh = false;
    brotli = false;
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

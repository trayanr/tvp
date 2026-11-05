# Private musl-host prerequisites. Command origins and adaptations are recorded
# per file in prerequisite-sources.json; no nixpkgs scope or stdenv is imported.
{ scope }:
let
  inherit (scope)
    bash
    binutils
    fetchurl
    lib
    ;
  cc = scope.gcc-latest;
  shell = "${bash}/bin/bash";
  tools = [
    cc
    binutils
    scope.gnumake-musl
    scope.gnused
    scope.gnugrep
    scope.gawk
    scope.diffutils
    scope.findutils
    scope.gnutar-latest
    scope.xz
    scope.gnupatch
  ];
  run =
    name: attrs: command:
    bash.runCommand name ({ nativeBuildInputs = tools; } // attrs) ''
      export CC=${cc}/bin/gcc CXX=${cc}/bin/g++ AR=${binutils}/bin/ar
      export RANLIB=${binutils}/bin/ranlib STRIP=${binutils}/bin/strip
      export LC_ALL=C TZ=UTC
      ${command}
    '';
  configure = flags: ''
    ${shell} ./configure --prefix=$out \
      --build=x86_64-unknown-linux-musl --host=x86_64-unknown-linux-musl \
      --disable-dependency-tracking ${flags}
  '';
  # Native suites are evidence, including true failures/skips. Functional
  # contracts below are separate gates, not replacements for these suites.
  check = ''
    mkdir -p "$checks"
    set +e
    make -j "$NIX_BUILD_CORES" SHELL=${shell} check > "$checks/make-check.log" 2>&1
    status=$?
    set -e
    printf '%s\n' "$status" > "$checks/exit-code"
    find . \( -name test-suite.log -o -name testsuite.log \) \
      -exec cp --parents '{}' "$checks" \;
  '';
  linuxSrc = fetchurl {
    url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.9.tar.xz";
    hash = "sha256-JPoB+5icej4oRT8Rd5kWhxN2bhGcU4HawwEV8Y8mgUk=";
  };
  m4Src = fetchurl {
    url = "mirror://gnu/m4/m4-1.4.21.tar.xz";
    hash = "sha256-8lxqtRVIpzp1VYdC+wMeBiXWSF/l+RVZSdZIaiQIq2Y=";
  };
  bisonSrc = fetchurl {
    url = "mirror://gnu/bison/bison-3.8.2.tar.xz";
    hash = "sha256-m7oCFMz38QecXVkhAEUie89hlRmEDr+oDNOEnP9aW/I=";
  };
  pythonSrc = fetchurl {
    url = "https://www.python.org/ftp/python/3.12.5/Python-3.12.5.tar.xz";
    hash = "sha256-+oouEsXmILCfU+ZbzYdVDS5aHi4Ev4upkdzFUROHY5c=";
  };
  grepSrc = fetchurl {
    url = "mirror://gnu/grep/grep-3.12.tar.xz";
    hash = "sha256-JkmyfA6Q5jLq3NdXvgbG6aT0jZQd5R58D4P/dkCKB7k=";
  };
  disabledModules = [
    "_bz2"
    "_crypt"
    "_ctypes"
    "_curses"
    "_curses_panel"
    "_dbm"
    "_gdbm"
    "_hashlib"
    "_lzma"
    "_sqlite3"
    "_ssl"
    "_tkinter"
    "_uuid"
    "nis"
    "readline"
    "zlib"
  ];
in
rec {
  linux-headers = run "tvp-bootstrap-linux-headers-6.9" { } ''
    tar xf ${linuxSrc}
    cd linux-6.9
    make -j "$NIX_BUILD_CORES" V=1 headers ARCH=x86 \
      CC=${cc}/bin/gcc HOSTCC=${cc}/bin/gcc \
      CONFIG_SHELL=${shell} SHELL=${shell}
    mkdir -p "$out/include" "$out/share/licenses/linux-headers"
    cp -pr usr/include/. "$out/include/"
    find "$out/include" -type f ! -name '*.h' -delete
    cp -pr COPYING LICENSES "$out/share/licenses/linux-headers/"
  '';
  build-m4 =
    run "tvp-bootstrap-build-m4-1.4.21"
      {
        outputs = [
          "out"
          "checks"
        ];
      }
      ''
        tar xf ${m4Src}
        cd m4-1.4.21
        export CFLAGS="-O2 -I${linux-headers}/include"
        ${configure "--with-syscmd-shell=${shell}"}
        make -j "$NIX_BUILD_CORES" SHELL=${shell}
        ${check}
        make -j "$NIX_BUILD_CORES" SHELL=${shell} install
        mkdir -p "$out/share/licenses/m4"
        cp COPYING "$out/share/licenses/m4/"
      '';
  build-bison =
    run "tvp-bootstrap-build-bison-3.8.2"
      {
        nativeBuildInputs = tools ++ [ build-m4 ];
        outputs = [
          "out"
          "checks"
        ];
      }
      ''
        tar xf ${bisonSrc}
        cd bison-3.8.2
        # Release generated parser/configure timestamps remain intact after unpack.
        # yacc must work with an empty PATH, as must Bison's M4 discovery.
        sed -i -e '1c#!${shell}' src/yacc.in
        export M4=${build-m4}/bin/m4
        ${configure "--disable-nls"}
        make -j "$NIX_BUILD_CORES" SHELL=${shell}
        ${check}
        make -j "$NIX_BUILD_CORES" SHELL=${shell} install
        mkdir -p "$out/share/licenses/bison"
        cp COPYING "$out/share/licenses/bison/"
      '';
  build-python = run "tvp-bootstrap-build-python-3.12.5" { } ''
    tar xf ${pythonSrc}
    cd Python-3.12.5
    patch -p1 -i ${./recipes/build-python/subprocess-shell.patch}
    sed -i 's|@TVP_SHELL@|${shell}|g' Lib/subprocess.py
    # Make hardcodes /bin/sh -e, including install recipes: bind both invocations.
    # Installed python-config is independently executable and needs this shell.
    sed -i -e '1c#!${shell}' \
      -e 's|dirname |${scope.coreutils-musl}/bin/dirname |g' \
      -e 's|which readlink|command -v ${scope.coreutils-musl}/bin/readlink|' \
      -e 's|readlink -f|${scope.coreutils-musl}/bin/readlink -f|g' \
      -e 's#| sed #| ${scope.gnused}/bin/sed #g' Misc/python-config.sh.in
    sed -i 's|^SHELL=.*|SHELL= ${shell} -e|' Makefile.pre.in
    printf '%s\n' '*disabled*' ${lib.concatStringsSep " " disabledModules} > Modules/Setup.local
    ${shell} ./configure --prefix="$out" \
      --build=x86_64-unknown-linux-musl --host=x86_64-unknown-linux-musl \
      --without-ensurepip --without-readline --disable-test-modules --with-platlibdir=lib
    make -j "$NIX_BUILD_CORES" SHELL=${shell}
    make -j "$NIX_BUILD_CORES" SHELL=${shell} \
      "COMPILEALL_OPTS=-j$NIX_BUILD_CORES" install
    # Bind executable Python entrypoints (including stdlib utility scripts).
    find "$out" -type f -name '*.py' -exec sed -i '1s|^#!.*|#!'"$out"'/bin/python3|' '{}' +
    sed -i '1c#!'"$out"'/bin/python3' "$out/bin/idle3.12" "$out/bin/pydoc3.12"
    # These development helpers are retained as owned entrypoints. The vendored
    # macOS download maintenance script is outside this Linux build profile.
    rm "$out/lib/python3.12/ctypes/macholib/fetch_macholib"
    for script in "$out"/lib/python3.12/config-*/install-sh "$out"/lib/python3.12/config-*/makesetup; do
      sed -i -e '1c#!${shell}' \
        -e '2i export PATH=${
          lib.makeBinPath [
            bash
            scope.coreutils-musl
            scope.gnused
            scope.gnugrep
            scope.diffutils
            binutils
          ]
        }' "$script"
    done
    mkdir -p "$out/share/licenses/python"
    cp LICENSE "$out/share/licenses/python/"
  '';
  build-grep =
    run "tvp-bootstrap-build-grep-3.12"
      {
        outputs = [
          "out"
          "checks"
        ];
      }
      ''
        tar xf ${grepSrc}
        cd grep-3.12
        # Generated egrep/fgrep must preserve argv and use this grep without PATH.
        sed -i '1c#!${shell}' src/egrep.sh
        ${configure "--disable-nls"}
        make -j "$NIX_BUILD_CORES" SHELL=${shell}
        ${check}
        make -j "$NIX_BUILD_CORES" SHELL=${shell} install
        mkdir -p "$out/share/licenses/grep"
        cp COPYING "$out/share/licenses/grep/"
            sed -i "s|exec grep |exec $out/bin/grep |" "$out/bin/egrep" "$out/bin/fgrep"
      '';
}

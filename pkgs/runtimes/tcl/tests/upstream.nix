# Native upstream validation against F, with a private tcltest executable linked
# to F's installed core/stubs. No build tree or test receipt enters production.
{ package }:
let
  s = package.specification;
  tools = s.tools;
in
package.testContext.mkTest {
  inherit package;
  name = "upstream";
  tools = s.environment.tools ++ [
    tools.gnutar
    tools.gzip
    tools.patch
    s.testPython
  ];
  libraries = [ package ];
  script = ''
    export HOME="$TMPDIR" LOGNAME=builder TERM=xterm TZ=UTC LANG=C.UTF-8 LC_ALL=C.UTF-8
    export TVP_TEST_SHELL=${s.testShell}/bin/bash TVP_TEST_ENV=${s.coreutils}/bin/env
    export CONFIG_SHELL=${s.testShell}/bin/bash SHELL=${s.testShell}/bin/bash
    ${tools.gnutar}/bin/tar -xzf ${s.testSource}
    cd tcl${package.version}
    ${builtins.concatStringsSep "\n" (
      map (p: "${tools.patch}/bin/patch --batch --fuzz=0 -p1 < ${p} >&2") s.testPatches
    )}
    cd unix
    ${s.testShell}/bin/bash ./configure --prefix=${package} --enable-threads --enable-shared \
      ${
        if package.version == "9.1.0" then "--disable-zipfs" else ""
      } --with-zlib=${s.libraries.zlib} > configure.log 2>&1 || { cat configure.log >&2; exit 1; }
    ${s.testPython}/bin/python3 -B ${s.testPrepare} ${package}
    mapfile -t libraries < fixture-libraries
    old=(); for library in "''${libraries[@]}"; do old+=(-o "$library"); done
    ${tools.gnumake}/bin/make "''${old[@]}" -j"$NIX_BUILD_CORES" SHELL=${s.testShell}/bin/bash tcltest > fixture-build.log 2>&1 || { cat fixture-build.log >&2; exit 1; }
    ${s.testPython}/bin/python3 -B ${s.testRunner} ${package} ${s.testShell}/bin/bash \
      ${s.coreutils}/bin/timeout ${s.testPython}/bin/python3 \
      ${
        if package.version == "9.1.0" then
          ../native/package-results-9.1.py
        else
          ../native/package-results.py
      } \
      ${../native/client-probe.c}
  '';
  expected = s.upstreamExpected;
}

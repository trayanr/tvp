# Private native utility wave; no catalogue/base integration or compiler rebuild.
{ scope, gnu }:
let
  pins = builtins.fromJSON (builtins.readFile ./gnu-tool-floor-sources.json);
  sources = builtins.mapAttrs (_: pin: scope.fetchurl { inherit (pin) url hash; }) pins.archives;
  shell = "${gnu.gnu-bash}/bin/bash";
  cc = gnu.gnu-gcc;
  tools = with scope; [
    coreutils-musl
    gnumake-musl
    gnused
    build-grep
    gawk
    diffutils
    findutils
    gnutar-latest
    gzip
    bzip2
    xz
  ];
  run =
    name: extra: command:
    scope.derivationWithMeta {
      name = "tvp-bootstrap-gnu-${name}";
      outputs = [
        "out"
        "evidence"
      ];
      builder = shell;
      args = [
        "-e"
        "-c"
        ''exec "$SHELL" -e "$buildCommandPath"''
      ];
      passAsFile = [ "buildCommand" ];
      SHELL = shell;
      buildCommand = ''
        export NIX_BUILD_CORES=''${NIX_BUILD_CORES:-1}
        if (( NIX_BUILD_CORES <= 0 )); then NIX_BUILD_CORES=$(nproc); fi
        export SHELL=${shell} CONFIG_SHELL=${shell} MAKESHELL=${shell}
        export CC=${cc}/bin/gcc CXX=${cc}/bin/g++
        export AR=${gnu.gnu-binutils}/bin/ar RANLIB=${gnu.gnu-binutils}/bin/ranlib
        export NM=${gnu.gnu-binutils}/bin/nm STRIP=${gnu.gnu-binutils}/bin/strip
        export CFLAGS=-O2 CXXFLAGS=-O2 LC_ALL=C
        mkdir -p "$evidence"
        ${command}
      '';
      PATH = scope.lib.makeBinPath (
        extra
        ++ [
          gnu.gnu-bash
          gnu.gnu-binutils
          cc
        ]
        ++ tools
      );
      inherit shell;
    };
  prepare = ''
    ${scope.build-python}/bin/python3 -B ${./gnu-tool-floor-prepare.py} ${shell}
  '';
  configure = flags: ''
    ${shell} ./configure --prefix="$out" --disable-nls --disable-dependency-tracking ${flags} > "$evidence/configure.log" 2>&1 || { cat "$evidence/configure.log"; exit 1; }
    cp config.log "$evidence/"
    make -j "$NIX_BUILD_CORES" SHELL=${shell} > "$evidence/build.log" 2>&1 || { tail -100 "$evidence/build.log"; exit 1; }
  '';
  check = ''
    status=0
    make -j "$NIX_BUILD_CORES" SHELL=${shell} check > "$evidence/make-check.log" 2>&1 || status=$?
    printf '%s\n' "$status" > "$evidence/make-check.status"
    # Raw status is evidence, never silently promoted to supported conformance.
    find . -name test-suite.log -exec cp --parents '{}' "$evidence" \;
  '';
  install = licenses: ''
    make -j "$NIX_BUILD_CORES" SHELL=${shell} install > "$evidence/install.log" 2>&1 || { tail -100 "$evidence/install.log"; exit 1; }
    find "$out" -type f -name '*.la' -delete
    ${scope.build-python}/bin/python3 -B ${./gnu-tool-floor-finalize.py} "$out" "$STRIP"
    mkdir -p "$out/share/licenses"
    cp ${licenses} "$out/share/licenses/"
  '';
in
rec {
  gnu-attr = run "attr-2.6.0" [ ] ''
    tar xf ${sources.attr}; cd attr-2.6.0
    ${prepare}
    ${configure "--enable-shared --enable-static"}
    ${check}
    ${install "doc/COPYING*"}
  '';
  gnu-acl = run "acl-2.4.0" [ ] ''
    tar xf ${sources.acl}; cd acl-2.4.0
    ${prepare}
    export CPPFLAGS=-I${gnu-attr}/include
    export LDFLAGS=-L${gnu-attr}/lib
    ${configure "--enable-shared --enable-static"}
    ${check}
    ${install "doc/COPYING*"}
  '';
  gnu-coreutils = run "coreutils-9.5" [ ] ''
    tar xf ${sources.coreutils}; cd coreutils-9.5
    ${prepare}
    export CPPFLAGS='-I${gnu-acl}/include -I${gnu-attr}/include -I${gnu.gnu-gmp}/include'
    export LDFLAGS='-L${gnu-acl}/lib -L${gnu-attr}/lib -L${gnu.gnu-gmp}/lib'
    export FORCE_UNSAFE_CONFIGURE=1
    ${configure "--with-gmp --enable-acl --without-selinux"}
    grep '^#define USE_ACL 1' lib/config.h
    grep '^#define HAVE_GMP_H 1' lib/config.h
    ${check}
    ${install "COPYING"}
  '';
  gnu-make = run "make-4.4.1" [ ] ''
    tar xf ${sources.make}; cd make-4.4.1
    ${prepare}
    ${scope.build-python}/bin/python3 -B ${../pkgs/build-tools/gnumake/owned/prepare.py} ${shell}
    # Keep Make's built-in CXX available to later environments through PATH.
    export CXX=c++
    ${configure "--without-guile"}
    ${check}
    ${install "COPYING"}
  '';
  gnu-findutils = run "findutils-4.11.0" [ gnu-coreutils ] ''
    tar xf ${sources.findutils}; cd findutils-4.11.0
    ${prepare}
    ${configure ""}
    ${check}
    ${install "COPYING"}
    # This private construction profile needs find/xargs, not a locate service.
    rm -f "$out/bin/locate" "$out/bin/updatedb"
    rm -rf "$out/libexec" "$out/var"
  '';
  gnu-diffutils = run "diffutils-3.12" [ gnu-coreutils ] ''
    tar xf ${sources.diffutils}; cd diffutils-3.12
    ${prepare}
    ${configure ""}
    ${check}
    ${install "COPYING"}
  '';
}

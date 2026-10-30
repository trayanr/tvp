{
  pkgs,
  tvpLib,
  base,
}:
let
  inherit (base) stdenv;
  simple =
    args:
    stdenv.mkDerivation (
      {
        dontUnpack = true;
        dontConfigure = true;
        dontBuild = true;
      }
      // args
    );
  test =
    name: script:
    tvpLib.bases.mkBaseTest {
      inherit base name script;
      expected = "ok";
    };
  debug = simple {
    name = "tvp-v3-separate-debug";
    separateDebugInfo = true;
    installPhase = ''
      mkdir -p "$out/bin"
      cc ${../../tests/fixtures/libc.c} -o "$out/bin/program"
    '';
  };
  hardening =
    structured: disable:
    simple {
      name = "tvp-v3-hardening-${
        if structured then "structured" else "flat"
      }-${builtins.concatStringsSep "-" disable}";
      __structuredAttrs = structured;
      hardeningDisable = disable;
      installPhase = ''
        mkdir -p "$out"
        # This must be an exported scalar even when the computed array was empty.
        env | grep '^NIX_HARDENING_ENABLE=' > "$out/environment"
        cc -O2 -E -dM -x c /dev/null > "$out/macros"
      '';
    };
  allFlat = hardening false [ "all" ];
  allStructured = hardening true [ "all" ];
  selectiveFlat = hardening false [
    "pic"
    "format"
  ];
  selectiveStructured = hardening true [
    "pic"
    "format"
  ];
  escape = simple {
    name = "tvp-v3-store-symlink-escape";
    installPhase = ''mkdir -p "$out"; ln -s /tmp "$out/escape"'';
  };
  origin = simple {
    name = "tvp-v3-origin";
    installPhase = ''
      mkdir -p "$out/bin" "$out/lib"
      printf 'int value(void) { return 42; }\n' > lib.c
      printf 'extern int value(void); int main(void) { return value() != 42; }\n' > main.c
      cc -shared lib.c -o "$out/lib/liborigin.so"
      cc main.c -L"$out/lib" -lorigin '-Wl,-rpath,$ORIGIN/../lib' -o "$out/bin/program"
    '';
  };
in
{
  hardening-protocol = test "hardening-protocol" ''
    for result in ${allFlat} ${allStructured}; do
      grep -qx 'NIX_HARDENING_ENABLE=' "$result/environment"
      if grep -Eq '^#define (__PIC__|_FORTIFY_SOURCE) ' "$result/macros"; then exit 1; fi
    done
    for result in ${selectiveFlat} ${selectiveStructured}; do
      grep -q '^#define _FORTIFY_SOURCE 2$' "$result/macros"
      if grep -q '^#define __PIC__ ' "$result/macros"; then exit 1; fi
      if grep -Eq '\b(pic|format)\b' "$result/environment"; then exit 1; fi
    done
    env -u NIX_HARDENING_ENABLE cc -O2 -E -dM -x c /dev/null > macros
    grep -q '^#define __PIC__ 2$' macros
    grep -q '^#define _FORTIFY_SOURCE 2$' macros
    echo ok
  '';
  fortify-order = test "fortify-order" ''
    fortify() {
      cc "$@" -E -dM -x c /dev/null > macros
      grep -q '^#define __OPTIMIZE__ 1$' macros
      grep -q '^#define _FORTIFY_SOURCE 2$' macros
    }
    for opt in -O -O1 -O2 -O3 -Og -Os -Oz -Ofast; do fortify "$opt"; done
    NIX_CFLAGS_COMPILE=-O2 fortify
    NIX_CFLAGS_COMPILE=$'-O0\n-O2' fortify
    printf '%s\n' -O2 > optimize.rsp
    fortify @optimize.rsp
    NIX_CFLAGS_COMPILE=-O0 fortify @optimize.rsp
    for mode in direct env response; do
      case "$mode" in
        direct) cc -O2 -O0 -E -dM -x c /dev/null > macros ;;
        env) NIX_CFLAGS_COMPILE=-O2 cc -O0 -E -dM -x c /dev/null > macros ;;
        response) cc @optimize.rsp -O0 -E -dM -x c /dev/null > macros ;;
      esac
      if grep -Eq '^#define (__OPTIMIZE__|_FORTIFY_SOURCE) ' macros; then exit 1; fi
    done
    cc -O2 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1 -E -dM -x c /dev/null > macros
    grep -q '^#define _FORTIFY_SOURCE 1$' macros
    echo ok
  '';
  response-modes = test "response-modes" ''
    mkdir 'directory with spaces'
    cp ${../../tests/fixtures/libc.c} 'directory with spaces/main file.c'
    printf '%s\n' '-static-pie "directory with spaces/main file.c" -o "static pie"' > 'inner file.rsp'
    printf '%s\n' '@"inner file.rsp"' > outer.rsp
    # Match the original direct/response reproduction without RPATH flags.
    # The frozen libc also crashes raw GCC static PIEs with an explicit RPATH.
    for hardening in 'pic' 'pic pie'; do
      NIX_LDFLAGS= NIX_HARDENING_ENABLE="$hardening" cc @outer.rsp
      if readelf -l 'static pie' | grep -q INTERP; then exit 1; fi
      test "$(./'static pie')" = 45
      NIX_LDFLAGS= NIX_HARDENING_ENABLE="$hardening" cc -static-pie 'directory with spaces/main file.c' -o direct
      test "$(./direct)" = 45
    done
    printf 'int value = 42; int get(void) { return value; }\n' > shared.c
    printf '%s\n' '-shared shared.c -o library.so' > shared.rsp
    NIX_HARDENING_ENABLE='pic pie' cc @shared.rsp
    cc -c -fPIC shared.c -o shared.o
    printf '%s\n' '-r shared.o -o partial.o' > reloc.rsp
    NIX_SET_BUILD_ID=1 NIX_HARDENING_ENABLE='pic pie' cc @reloc.rsp
    readelf -h partial.o | grep -q REL
    if readelf -n partial.o | grep -q 'Build ID'; then exit 1; fi
    # User compile flags still override hardening.
    NIX_HARDENING_ENABLE='pic pie' cc -fno-pie -fno-PIC -E -dM -x c /dev/null > macros
    if grep -q '^#define __PIC__ ' macros; then exit 1; fi
    echo ok
  '';
  response-grammar = test "response-grammar" ''
    # Compare the classifier's expansion against actual GCC's response parser,
    # including empty arguments, escapes, nested files, and malformed EOF.
    helper=${base.fixupTools.responseExpander}/bin/expand-response-params
    for contents in '-DVALUE="a b"' "-DVALUE='a b'" '-DVALUE=a\ b' '-DVALUE="unterminated' '-DVALUE=trailing\'; do
      printf '%s' "$contents" > grammar.rsp
      "$helper" @grammar.rsp > expanded
      mapfile -d "" -t args < expanded
      cc @grammar.rsp -E -dM -x c /dev/null > gcc.macros
      cc "''${args[@]}" -E -dM -x c /dev/null > expanded.macros
      diff -u gcc.macros expanded.macros
    done
    printf '%s\n' '""' > empty.rsp
    "$helper" @empty.rsp > expanded
    mapfile -d "" -t args < expanded
    test "''${#args[@]}" = 1
    test "''${args[0]}" = ""
    if cc @empty.rsp -c -x c /dev/null -o empty.o > /dev/null 2>&1; then exit 1; fi
    if cc @missing.rsp -c -x c /dev/null -o missing.o > /dev/null 2>&1; then exit 1; fi
    printf '@cycle.rsp\n' > cycle.rsp
    if cc @cycle.rsp -E -x c /dev/null > /dev/null 2> error; then exit 1; fi
    grep -q 'cyclic response file' error
    if cc @/dev/stdin -E -x c /dev/null < grammar.rsp > /dev/null 2> error; then exit 1; fi
    grep -q 'regular files' error
    # Both depth and total expansion are bounded, and helper errors stop GCC.
    for i in $(seq 0 64); do printf '@depth%s.rsp\n' "$((i + 1))" > "depth$i.rsp"; done
    printf '%s\n' -O2 > depth65.rsp
    if cc @depth0.rsp -E -x c /dev/null > /dev/null 2> error; then exit 1; fi
    grep -q 'nesting exceeds' error
    head -c 16777217 /dev/zero | tr '\0' ' ' > large.rsp
    if cc @large.rsp -E -x c /dev/null > /dev/null 2> error; then exit 1; fi
    grep -q 'exceeds 16 MiB' error
    # Errors writing helper output propagate too.
    if "$helper" @grammar.rsp > /dev/full 2>/dev/null; then exit 1; fi
    echo ok
  '';
  debug-info = test "debug-info" ''
    program=${debug}/bin/program
    id=$(readelf -n "$program" | sed -n 's/.*Build ID: //p')
    test "''${#id}" = 40
    info=${debug.debug}/lib/debug/.build-id/''${id:0:2}/''${id:2}.debug
    test -s "$info"
    readelf -S "$info" | grep -q '\.debug_info'
    if readelf -S "$program" | grep -q '\.debug_info'; then exit 1; fi
    test "$("$program")" = 45
    echo ok
  '';
  build-id-protocol = test "build-id-protocol" ''
    cc -c -g -fPIC ${../../tests/fixtures/libc.c} -o main.o
    for linker in cc ld; do
      if [[ "$linker" = cc ]]; then args=(main.o); else args=(-shared main.o); fi
      for request in unset 0 1 yes; do
        unset NIX_SET_BUILD_ID
        if [[ "$request" != unset ]]; then export NIX_SET_BUILD_ID=$request; fi
        "$linker" "''${args[@]}" -o program
        if [[ "$request" = 1 ]]; then
          readelf -n program | grep -q 'Build ID:'
        elif readelf -n program | grep -q 'Build ID:'; then exit 1; fi
      done
      NIX_SET_BUILD_ID=1 NIX_BUILD_ID_STYLE=md5 "$linker" "''${args[@]}" -o program
      id=$(readelf -n program | sed -n 's/.*Build ID: //p')
      test "''${#id}" = 32
    done
    printf '%s\n' '-r main.o -o partial.o' > ld.rsp
    NIX_SET_BUILD_ID=1 ld @ld.rsp
    if readelf -n partial.o | grep -q 'Build ID:'; then exit 1; fi
    echo ok
  '';
  runtime-paths = test "runtime-paths" ''
    ${origin}/bin/program
    patchelf --print-rpath ${origin}/bin/program | grep -Fq '$ORIGIN/../lib'
    mkdir -p fixup/bin
    cp ${origin}/bin/program fixup/bin/program
    chmod u+w fixup/bin/program
    prefix=$PWD/fixup
    source ${../../stdenv/hooks/shrink-rpaths-v3.sh}
    for bad in /nix/store/../../tmp ${escape}/escape; do
      runtimeLibraryPaths=("$bad")
      if tvpShrinkRpaths 2> error; then exit 1; fi
      grep -q 'outside the store' error
      if patchelf --print-rpath fixup/bin/program | grep -Fq "$bad"; then exit 1; fi
    done
    runtimeLibraryPaths=(${origin}/lib/../lib)
    tvpShrinkRpaths
    patchelf --print-rpath fixup/bin/program | grep -Fq '${origin}/lib'
    runtimeLibraryPaths=(/nix/store/../../tmp)
    dontShrinkRpaths=1 tvpShrinkRpaths
    echo ok
  '';
}

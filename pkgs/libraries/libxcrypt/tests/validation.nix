{
  pkgs,
  package,
  baseline,
}:
let
  recorded =
    name: inputs: script:
    pkgs.runCommand "libxcrypt-${package.version}-${name}"
      {
        nativeBuildInputs = inputs;
        passthru = {
          inherit package;
          testName = name;
        };
      }
      ''
        set -euo pipefail
        mkdir -p "$out"
        exec > >(tee "$out/results.log") 2>&1
        ${script}
      '';
in
{
  api = recorded "api" [ package.tvp.cc ] (
    if !pkgs.stdenv.hostPlatform.isLinux then
      ''
        echo 'SKIP exact-library API probe: requires Linux ELF libcrypt.so.1'
      ''
    else
      ''
        cc -Wall -Wextra -Werror -I${package}/include ${./fixtures}/api.c \
          -L${package}/lib -Wl,-rpath,${package}/lib -lcrypt -ldl -o api
        ./api ${package}/lib/libcrypt.so.1 ${package.version}
      ''
  );
  abi =
    recorded "abi"
      [
        package.tvp.cc
        pkgs.pkg-config
        pkgs.binutils
      ]
      (
        if !pkgs.stdenv.hostPlatform.isLinux then
          ''
            echo 'SKIP ELF ABI probe: requires Linux ELF artifacts'
          ''
        else
          ''
            export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
            test "$(pkg-config --modversion libxcrypt)" = ${package.version}
            test "$(pkg-config --variable=prefix libxcrypt)" = ${package}
            test "$(pkg-config --variable=includedir libxcrypt)" = ${package}/include
            test "$(pkg-config --variable=libdir libxcrypt)" = ${package}/lib
            pkg-config --cflags --libs libxcrypt | tee "$out/pkg-config.log"
            cc -Wall -Wextra -Werror $(pkg-config --cflags libxcrypt) ${./fixtures/crypt.c} \
              $(pkg-config --libs libxcrypt) -Wl,-rpath,${package}/lib -o consumer
            test "$(./consumer)" = ok
            for name in libxcrypt.so libowcrypt.so libowcrypt.so.1; do
              test -L ${package}/lib/$name
              test "$(readlink -f ${package}/lib/$name)" = "$(readlink -f ${package}/lib/libcrypt.so.1)"
              printf 'PASS compatibility link %s -> %s\n' "$name" "$(readlink ${package}/lib/$name)"
            done
            test -f ${package}/include/xcrypt.h
            printf '%s\n' '#include <xcrypt.h>' 'int main(void) { return !xcrypt("abc", "$6$salt$"); }' > compat.c
            cc -I${package}/include compat.c -L${package}/lib -Wl,-rpath,${package}/lib -lxcrypt -o compat
            ./compat
            readelf -d ${package}/lib/libcrypt.so.1 > "$out/dynamic.log"
            grep -F 'Library soname: [libcrypt.so.1]' "$out/dynamic.log"
            readelf --version-info ${package}/lib/libcrypt.so.1 > "$out/versions.log"
            readelf --dyn-syms --wide ${package}/lib/libcrypt.so.1 > "$out/symbols.log"
            for node in XCRYPT_2.0 XCRYPT_4.3 XCRYPT_4.4; do
              grep -F "Name: $node" "$out/versions.log"
            done
            # Compare actual defined ELF names WITH versions; undefined libc helpers
            # and ABS version-label symbols are not public function exports.
            for pair in 'baseline ${baseline}' 'candidate ${package}'; do
              set -- $pair
              readelf --dyn-syms --wide "$2/lib/libcrypt.so.1" \
                | awk '$4 == "FUNC" && $5 == "GLOBAL" && $7 != "UND" {print $8}' \
                | sort -u > "$out/$1.exports"
            done
            diff -u "$out/baseline.exports" "$out/candidate.exports"
            # Link once against 4.4.36, then use the new SONAME with its original
            # symbol-version requirements and header layout, without relinking.
            cc -I${baseline}/include ${./fixtures}/api.c -L${baseline}/lib \
              -Wl,--enable-new-dtags,-rpath,${baseline}/lib -lcrypt -ldl -o old-consumer
            readelf --version-info old-consumer > "$out/consumer-versions.log"
            LD_LIBRARY_PATH=${package}/lib ./old-consumer ${package}/lib/libcrypt.so.1 ${package.version}
            LD_DEBUG=libs LD_LIBRARY_PATH=${package}/lib ./consumer 2> "$out/loader.log"
            grep -F '${package}/lib/libcrypt.so.1' "$out/loader.log"
            echo 'PASS ELF SONAME/versioned exports and unchanged 4.4.36 consumer'
            echo 'PASS crypt.h/pkg-config consumer and compatibility links'
          ''
      );
}

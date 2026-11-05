# Opt-in native capability/purity probes; ordinary CI does not build this chain.
{ scope }:
let
  inherit (scope) bash musl binutils;
  raw = scope.gcc-latest-unwrapped;
  wrapped = scope.gcc-latest;
  runtime = "${scope.gcc16-libgcc}/lib/gcc/x86_64-unknown-linux-musl/16.2.0";
  cxx = scope.gcc16-libstdcxx;
  path = scope.lib.makeBinPath [
    bash
    scope.coreutils-musl
    binutils
    scope.gnugrep
  ];
in
{
  gcc16 =
    bash.runCommand "tvp-bootstrap-gcc16-cxx20"
      {
        nativeBuildInputs = [
          binutils
          scope.gnugrep
        ];
        outputs = [
          "out"
          "evidence"
        ];
      }
      ''
        mkdir -p $out/bin $evidence
        env -i PATH=${path} SHELL=${bash}/bin/bash ${bash}/bin/bash -eux -c '
          test "$(${wrapped}/bin/gcc -dumpfullversion)" = 16.2.0
          test "$(${wrapped}/bin/g++ -dumpmachine)" = x86_64-unknown-linux-musl
          for tag in raw wrapper; do
            cc=(${wrapped}/bin/gcc)
            cxx=(${wrapped}/bin/g++)
            if test "$tag" = raw; then
              # The compiler stage intentionally omits target libraries. Explicit split
              # runtime and header selection is required for every raw link probe.
              cc=(${raw}/bin/gcc -B${musl}/lib -B${runtime}/ -static-libgcc)
              cxx=(${raw}/bin/g++ -B${musl}/lib -B${runtime}/ -B${cxx}/lib/ \
                -I${cxx}/include/c++/16.2.0/x86_64-unknown-linux-musl \
                -I${cxx}/include/c++/16.2.0 -static-libgcc)
            fi
            "''${cc[@]}" -std=c11 -static ${./consumer.c} -o '"$out"'/bin/$tag-c
            '"$out"'/bin/$tag-c
            "''${cc[@]}" -std=c11 -c ${./consumer-abi.c} -o abi.o
            for standard in 14 20; do
              source=${./consumer14.cc}
              if test "$standard" = 20; then source=${./consumer20.cc}; fi
              for mode in static dynamic; do
                flags=(-static)
                if test "$mode" = dynamic; then flags=(-static-libstdc++ -static-libgcc); fi
                "''${cxx[@]}" -std=c++$standard -O2 "''${flags[@]}" "$source" abi.o \
                  -o '"$out"'/bin/$tag-cxx$standard-$mode
                '"$out"'/bin/$tag-cxx$standard-$mode
              done
            done
            "''${cxx[@]}" -dumpspecs > '"$evidence"'/$tag.specs
            "''${cxx[@]}" -print-search-dirs > '"$evidence"'/$tag.search-dirs
            if grep -E "(^|:)/(usr/)?lib(/|:)" '"$evidence"'/$tag.search-dirs; then exit 1; fi
            if grep -E "ld-linux|/usr/lib|/lib64/" '"$evidence"'/$tag.specs; then exit 1; fi
            for tool in as ld; do
              selected=$("''${cxx[@]}" -print-prog-name=$tool)
              test "$selected" = ${binutils}/bin/$tool
              printf "%s\n" "$selected" >> '"$evidence"'/$tag.tools
            done
            test "$("''${cxx[@]}" -print-file-name=libgcc.a)" = ${runtime}/libgcc.a
            test "$("''${cxx[@]}" -print-file-name=libstdc++.a)" = ${cxx}/lib/libstdc++.a
            "''${cxx[@]}" -std=c++20 -E -v ${./consumer20.cc} \
              > /dev/null 2> '"$evidence"'/$tag.includes
            grep -F ${musl}/include '"$evidence"'/$tag.includes
            grep -F ${cxx}/include/c++/16.2.0 '"$evidence"'/$tag.includes
          done
          # Actual wrapper links retain caller argv boundaries and comma paths in env -i,
          # including an empty or hostile NIX_STORE. Offline argv contracts cover -B too.
          mkdir -p '"$out"'/lib,comma
          for store in empty hostile; do
            value=""
            if test "$store" = hostile; then value=/hostile; fi
            for language in c cxx; do
              compiler=${wrapped}/bin/gcc
              source=${./consumer.c}
              flags=()
              if test "$language" = cxx; then
                compiler=${wrapped}/bin/g++
                source=${./consumer14.cc}
                flags=(-std=c++14 abi.o)
              fi
              env NIX_STORE="$value" "$compiler" -static -L '"$out"'/lib,comma \
                "''${flags[@]}" "$source" -o comma-$language-$store
              ./comma-$language-$store
              env NIX_STORE="$value" "$compiler" -static-libgcc -static-libstdc++ \
                -L'"$out"'/lib,comma "''${flags[@]}" "$source" -o '"$out"'/bin/comma-$language-$store
              '"$out"'/bin/comma-$language-$store
            done
          done
          ${wrapped}/bin/gcc -v
          ${wrapped}/bin/g++ -v
        '
        for binary in $out/bin/*; do
          readelf -h -l -d "$binary" > $evidence/$(basename "$binary").elf
        done
        for tag in raw wrapper; do
          for binary in $tag-c $tag-cxx14-static $tag-cxx20-static; do
            if grep -E 'INTERP|NEEDED|RPATH|RUNPATH' $evidence/$binary.elf; then exit 1; fi
          done
          for standard in 14 20; do
            file=$evidence/$tag-cxx$standard-dynamic.elf
            grep -F '${musl}/lib/libc.so' "$file"
            grep -E 'NEEDED.*\[libc.so\]' "$file"
            if grep -E 'NEEDED.*(libstdc\+\+|libgcc_s)' "$file"; then exit 1; fi
          done
        done
        if grep -E '(RPATH|RUNPATH).*(${scope.gcc10-unwrapped}|${scope.gcc10}|${cxx})' $evidence/*.elf; then exit 1; fi
        for file in $evidence/comma-*.elf; do
          grep -F "$out/lib,comma" "$file"
        done
      '';
}

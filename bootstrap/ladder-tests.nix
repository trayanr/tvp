{ scope }:
let
  inherit (scope)
    bash
    coreutils-musl
    gcc46-cxx
    musl
    binutils
    ;
  tools = with scope; [
    coreutils-musl
    binutils
    gnumake-musl
    gnupatch
    gnused
    gnugrep
    gawk
    gnutar-musl
    gzip
    xz
    diffutils
    findutils
  ];
  path = scope.lib.makeBinPath (
    [
      bash
      gcc46-cxx
    ]
    ++ tools
  );
in
{
  cxx =
    bash.runCommand "tvp-bootstrap-cxx-runtime"
      {
        nativeBuildInputs = tools;
        outputs = [
          "out"
          "evidence"
        ];
      }
      ''
        mkdir -p $out/bin $evidence
        # Every compilation, link and execution below runs with an empty environment
        # plus these explicit owned tool, header and library directories.
        env -i PATH=${path} SHELL=${bash}/bin/bash \
          C_INCLUDE_PATH=${musl}/include CPLUS_INCLUDE_PATH=${musl}/include \
          LIBRARY_PATH=${musl}/lib \
          ${bash}/bin/bash -eux -c '
            ${gcc46-cxx}/bin/gcc -B${binutils}/bin/ -c ${./consumer-abi.c} -o abi.o
            ${gcc46-cxx}/bin/g++ -B${binutils}/bin/ -std=c++98 -O2 \
              -static -o '"$out"'/bin/static ${./consumer.cc} abi.o
            '"$out"'/bin/static
            ${gcc46-cxx}/bin/g++ -B${binutils}/bin/ -std=c++98 -O2 \
              -static-libstdc++ -static-libgcc \
              -Wl,-dynamic-linker,${musl}/lib/libc.so \
              -o '"$out"'/bin/dynamic ${./consumer.cc} abi.o
            '"$out"'/bin/dynamic
          '
        readelf -h -l -d $out/bin/static > $evidence/static.elf
        readelf -h -l -d $out/bin/dynamic > $evidence/dynamic.elf
        if grep -q INTERP $evidence/static.elf; then exit 1; fi
        if grep -q NEEDED $evidence/static.elf; then exit 1; fi
        grep -F '${musl}/lib/libc.so' $evidence/dynamic.elf
        grep -F 'libc.so' $evidence/dynamic.elf
        if grep -E 'NEEDED.*(libstdc\+\+|libgcc_s)' $evidence/dynamic.elf; then exit 1; fi
        ${gcc46-cxx}/bin/g++ -dumpspecs > $evidence/specs
        ${gcc46-cxx}/bin/g++ -print-search-dirs > $evidence/search-dirs
        if grep -E '(^|:)/(usr/)?lib(/|:)' $evidence/search-dirs; then exit 1; fi
        if grep -E 'ld-linux|/usr/lib|/lib64/' $evidence/specs; then exit 1; fi
        test "$(${gcc46-cxx}/bin/g++ -print-prog-name=as)" = ${binutils}/bin/as
        test "$(${gcc46-cxx}/bin/g++ -print-prog-name=ld)" = ${binutils}/bin/ld
        test -f $(${gcc46-cxx}/bin/g++ -print-file-name=libstdc++.a)
      '';
  tools = bash.runCommand "tvp-bootstrap-tool-functions" { nativeBuildInputs = tools; } ''
    mkdir -p $out
    printf 'beta\nalpha\n' > input
    sed 's/beta/gamma/' input | grep gamma
    awk '{ n += length($0) } END { if (n != 9) exit 1 }' input
    sort input > sorted
    printf 'alpha\nbeta\n' > expected
    cmp sorted expected
    diff sorted expected
    printf '%s\n' '--- input' '+++ input' '@@ -1,2 +1,2 @@' '-beta' '+gamma' ' alpha' > change
    patch -p0 < change
    grep gamma input
    tar cf data.tar input
    gzip -c data.tar > data.tar.gz
    gzip -dc data.tar.gz > roundtrip.tar
    cmp data.tar roundtrip.tar
    xz -c data.tar > data.tar.xz
    xz -dc data.tar.xz > roundtrip.tar
    cmp data.tar roundtrip.tar
    mkdir extracted
    (cd extracted; tar xf ../data.tar)
    cmp input extracted/input
    find extracted -type f | grep input
    printf 'all:\n\t@test "$$BASH_VERSION" != ""\n\t@printf "owned shell\\n"\n' > Makefile
    make SHELL=${bash}/bin/bash > $out/make-shell
    env -i ${bash}/bin/bash -c 'test "$BASH_VERSION" != ""'
    printf 'tool functions: PASS\n' > $out/result
  '';
  transitions = scope.bash_2_05.runCommand "tvp-bootstrap-transition-checks" { } ''
    echo ${scope.tinycc-musl-intermediate.compiler.tests.hello-world}
    echo ${scope.tinycc-musl.compiler.tests.hello-world}
    echo ${scope.gcc46.tests.get-version}
    echo ${scope.musl.tests.hello-world}
    echo ${scope.gcc46-cxx.tests.hello-world}
    mkdir $out
  '';
  libc = bash.runCommand "tvp-bootstrap-gcc-musl-functions" { nativeBuildInputs = tools; } ''
    mkdir -p $out/bin
    env -i PATH=${path} C_INCLUDE_PATH=${musl}/include LIBRARY_PATH=${musl}/lib \
      ${gcc46-cxx}/bin/gcc -static -fno-builtin -o $out/bin/libc ${./libc-probe.c} -lm
    env -i PATH=${bash}/bin $out/bin/libc
  '';
  stage-comparison =
    bash.runCommand "tvp-bootstrap-tinycc-stage-comparison" { nativeBuildInputs = tools; }
      ''
        mkdir $out
        ${scope.tinycc-musl-intermediate.compiler}/bin/tcc -v -c ${./consumer-abi.c} -o first.o
        ${scope.tinycc-musl.compiler}/bin/tcc -v -c ${./consumer-abi.c} -o second.o
        sha256sum first.o second.o > $out/objects.sha256
        if cmp first.o second.o; then echo match > $out/objects; else echo differ > $out/objects; fi
        sha256sum ${scope.tinycc-musl-intermediate.compiler}/bin/tcc \
          ${scope.tinycc-musl.compiler}/bin/tcc > $out/compilers.sha256
        if cmp ${scope.tinycc-musl-intermediate.compiler}/bin/tcc ${scope.tinycc-musl.compiler}/bin/tcc; then
          echo match > $out/compilers
        else
          echo differ > $out/compilers
        fi
        # A bounded adjacent-stage comparison, never a fixed-point or DDC proof.
      '';
}

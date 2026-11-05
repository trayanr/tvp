# Explicitly opt-in compiler/runtime checks; never part of ordinary CI realization.
{ scope }:
let
  inherit (scope)
    bash
    musl
    binutils
    gcc10
    gcc10-unwrapped
    ;
  tools = with scope; [
    coreutils-musl
    binutils
    gnused
    gnugrep
    diffutils
    gnutar-latest
    gzip
    bzip2
    xz
  ];
  path = scope.lib.makeBinPath (
    [
      bash
      gcc10
    ]
    ++ tools
  );
in
{
  gcc10-archives = bash.runCommand "tvp-bootstrap-gcc10-archives" { nativeBuildInputs = tools; } ''
    mkdir -p $out original
    printf '#!${bash}/bin/bash\nprintf "archive executable\\n"\n' > original/probe
    chmod 755 original/probe
    touch -t 200101020304.05 original/probe
    bzip2 -c original/probe > probe.bz2
    bzip2 -dc probe.bz2 > roundtrip
    cmp original/probe roundtrip
    for compression in z j J; do
      tar c''${compression}f archive.tar original
      mkdir extracted
      (cd extracted; tar xf ../archive.tar)
      cmp original/probe extracted/original/probe
      test "$(stat -c %a extracted/original/probe)" = 755
      test "$(stat -c %Y extracted/original/probe)" = "$(stat -c %Y original/probe)"
      env -i extracted/original/probe
      rm -rf extracted
    done
    printf 'bzip2 roundtrip; tar gzip/bzip2/xz data/mode/mtime/execution: PASS\n' > $out/result
  '';
  gcc10 =
    bash.runCommand "tvp-bootstrap-gcc10-cxx14"
      {
        nativeBuildInputs = tools;
        outputs = [
          "out"
          "evidence"
        ];
      }
      ''
        mkdir -p $out/bin $evidence
        env -i PATH=${path} SHELL=${bash}/bin/bash \
          ${bash}/bin/bash -eux -c '
            for compiler in ${gcc10} ${gcc10-unwrapped}; do
              tag=raw
              if test "$compiler" = ${gcc10}; then tag=wrapper; fi
              "$compiler/bin/gcc" -std=c11 -static ${./consumer.c} -o '"$out"'/bin/$tag-c
              '"$out"'/bin/$tag-c
              "$compiler/bin/gcc" -std=c11 -c ${./consumer-abi.c} -o abi.o
              "$compiler/bin/g++" -std=c++14 -O2 -static ${./consumer14.cc} abi.o -o '"$out"'/bin/$tag-static
              '"$out"'/bin/$tag-static
              "$compiler/bin/g++" -std=c++14 -O2 -static-libstdc++ -static-libgcc \
                ${./consumer14.cc} abi.o -o '"$out"'/bin/$tag-dynamic
              '"$out"'/bin/$tag-dynamic
              "$compiler/bin/g++" -dumpspecs > '"$evidence"'/$tag.specs
              "$compiler/bin/g++" -print-search-dirs > '"$evidence"'/$tag.search-dirs
              if grep -E "(^|:)/(usr/)?lib(/|:)" '"$evidence"'/$tag.search-dirs; then exit 1; fi
              if grep -E "ld-linux|/usr/lib|/lib64/" '"$evidence"'/$tag.specs; then exit 1; fi
              for tool in as ld; do
                selected=$("$compiler/bin/g++" -print-prog-name=$tool)
                test "$selected" = ${binutils}/bin/$tool
                printf "%s\n" "$selected" >> '"$evidence"'/$tag.tools
              done
              for library in libstdc++.a libgcc.a; do
                selected=$("$compiler/bin/g++" -print-file-name=$library)
                case "$selected" in ${gcc10-unwrapped}/*) ;; *) exit 1;; esac
                test -f "$selected"
                printf "%s\n" "$selected" >> '"$evidence"'/$tag.libraries
              done
            done
            # The libtool version-only special case must not add linker arguments.
            ${gcc10}/bin/gcc -v
            ${gcc10}/bin/g++ -v
          '
        for binary in $out/bin/*; do
          readelf -h -l -d "$binary" > $evidence/$(basename "$binary").elf
        done
        for tag in raw wrapper; do
          for mode in c static; do
            if grep -E 'INTERP|NEEDED|RPATH|RUNPATH' $evidence/$tag-$mode.elf; then exit 1; fi
          done
          grep -F '${musl}/lib/libc.so' $evidence/$tag-dynamic.elf
          grep -E 'NEEDED.*\[libc.so\]' $evidence/$tag-dynamic.elf
          if grep -E 'NEEDED.*(libstdc\+\+|libgcc_s)' $evidence/$tag-dynamic.elf; then exit 1; fi
          if grep -E '(RPATH|RUNPATH).*${gcc10-unwrapped}' $evidence/$tag-dynamic.elf; then exit 1; fi
        done
      '';
}

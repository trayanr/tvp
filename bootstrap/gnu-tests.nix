{ scope, gnu }:
let
  inherit (scope) bash;
  cc = gnu.gnu-gcc;
  raw = gnu.gnu-gcc-unwrapped;
  binutils = gnu.gnu-binutils;
in
bash.runCommand "tvp-bootstrap-gnu-checkpoint-contracts"
  {
    outputs = [
      "out"
      "evidence"
    ];
    nativeBuildInputs = [
      scope.coreutils-musl
      binutils
    ];
  }
  ''
        mkdir -p "$out/bin" "$evidence" "space , arguments"
        env -i ${gnu.gnu-bash}/bin/bash --noprofile --norc -c 'test -n "$PWD"; pwd' \
        > "$evidence/gnu-shell-cwd" 2> "$evidence/gnu-shell-stderr"
      test ! -s "$evidence/gnu-shell-stderr"
      cp ${./gnu-probe.c} "space , arguments/probe.c"
        cp ${./consumer-abi.c} consumer-abi.c
    cp ${./consumer14.cc} consumer14.cc
    cp ${./consumer20.cc} consumer20.cc
    cp ${./gnu-plugin.cc} gnu-plugin.cc
    cp ${./gnu-unwind.cc} gnu-unwind.cc
    cp ${./gnu-cancel.c} gnu-cancel.c
    for driver in ${cc} ${raw}; do
          name=wrapped
          test "$driver" != ${raw} || name=raw
          env -i "$driver/bin/gcc" -v > "$evidence/$name-version" 2>&1
          env -i "$driver/bin/gcc" -dumpspecs > "$evidence/$name-specs"
          env -i "$driver/bin/gcc" -print-search-dirs > "$evidence/$name-search"
          env -i "$driver/bin/gcc" -O2 "space , arguments/probe.c" -pthread -lm -o "$out/bin/$name-dynamic"
          env -i "$out/bin/$name-dynamic" > "$evidence/$name-dynamic"
          env -i "$driver/bin/gcc" -O2 -static "space , arguments/probe.c" -pthread -lm -o "$out/bin/$name-static"
          env -i "$out/bin/$name-static" > "$evidence/$name-static"
          env -i "$driver/bin/gcc" -O2 -fPIE -pie "space , arguments/probe.c" -pthread -lm -o "$out/bin/$name-pie"
          env -i "$out/bin/$name-pie" > "$evidence/$name-pie"
      ${binutils}/bin/readelf -h "$out/bin/$name-pie" | ${scope.build-grep}/bin/grep 'Type:.*DYN'
      ${binutils}/bin/readelf -h "$out/bin/$name-static" | ${scope.build-grep}/bin/grep 'Type:.*EXEC'
      ${binutils}/bin/readelf -h "$out/bin/$name-dynamic" | ${scope.build-grep}/bin/grep 'Type:.*EXEC'
      if ${binutils}/bin/readelf -l "$out/bin/$name-static" | ${scope.build-grep}/bin/grep INTERP; then
        echo 'static GNU probe has an interpreter' >&2; exit 1
      fi
          env -i "$driver/bin/gcc" -c consumer-abi.c -o abi.o
          env -i "$driver/bin/g++" -std=c++14 consumer14.cc abi.o -o "$out/bin/$name-cxx14"
          env -i "$out/bin/$name-cxx14" > "$evidence/$name-cxx14"
          env -i "$driver/bin/g++" -std=c++20 consumer20.cc -o "$out/bin/$name-cxx20"
          env -i "$out/bin/$name-cxx20" > "$evidence/$name-cxx20"
          env -i "$driver/bin/g++" -std=c++14 -shared -fPIC gnu-plugin.cc -o "$out/lib$name-plugin.so"
          env -i "$driver/bin/g++" -std=c++14 gnu-unwind.cc -pthread -ldl -o "$out/bin/$name-unwind"
          env -i "$out/bin/$name-unwind" "$out/lib$name-plugin.so" > "$evidence/$name-unwind"
          env -i "$driver/bin/g++" -std=c++14 -static consumer14.cc abi.o -o "$out/bin/$name-cxx14-static"
        env -i "$out/bin/$name-cxx14-static" > "$evidence/$name-cxx14-static"
      env -i "$driver/bin/gcc" gnu-cancel.c -pthread -o "$out/bin/$name-cancel-c"
      env -i "$out/bin/$name-cancel-c" > "$evidence/$name-cancel-c"
      ${binutils}/bin/readelf -d "$out/bin/$name-cancel-c" > "$evidence/$name-cancel-c-needed"
      if ${scope.build-grep}/bin/grep '(NEEDED).*libgcc_s' "$evidence/$name-cancel-c-needed"; then
        echo 'C-only probe must load its own unwinder' >&2; exit 1
      fi
      env -i "$driver/bin/gcc" -static gnu-cancel.c -pthread -o "$out/bin/$name-cancel-c-static"
      env -i "$out/bin/$name-cancel-c-static" > "$evidence/$name-cancel-c-static"
        for file in "$out/bin/$name-"*; do
            ${binutils}/bin/readelf -h -l -d "$file" > "$evidence/$(basename "$file").elf"
          done
        done
        for mode in -m32 -mx32 -mmusl -mbionic -muclibc; do
          status=0
          env -i ${cc}/bin/gcc "$mode" -c ${./gnu-probe.c} -o rejected.o > "$evidence/rejected-$mode" 2>&1 || status=$?
          test "$status" = 64
        done
        # Store handling cannot be redirected by an empty or counterfeit NIX_STORE.
        env -i NIX_STORE= ${cc}/bin/gcc "space , arguments/probe.c" -o "$out/bin/nix-store-empty"
        env -i "$out/bin/nix-store-empty" > "$evidence/nix-store-empty"
        env -i NIX_STORE=/tmp ${cc}/bin/gcc "space , arguments/probe.c" -o "$out/bin/nix-store-foreign"
        env -i "$out/bin/nix-store-foreign" > "$evidence/nix-store-foreign"
        mkdir -p "$out/space ,lib"
      printf '%s\n' 'int answer(void) { return 42; }' > library.c
      printf '%s\n' 'extern int answer(void); int main(void) { return answer()!=42; }' > caller.c
      env -i ${cc}/bin/gcc -shared -fPIC library.c -o "$out/space ,lib/libanswer.so"
      env -i NIX_STORE= ${cc}/bin/gcc caller.c -L "$out/space ,lib" -lanswer -o "$out/bin/comma-rpath"
      env -i "$out/bin/comma-rpath"
      ${binutils}/bin/readelf -d "$out/bin/comma-rpath" > "$evidence/comma-rpath.elf"
  ''

# Owned adapter over the complete native compiler and its newly built runtimes.
{
  bootstrap ? import ./. { },
  libc,
  compiler,
  make,
}:
let
  b = bootstrap;
  shell = "${b.gnu-bash}/bin/bash";
  coreutils = b.gnu-tool-floor.gnu-coreutils;
  composition = import ./source-base.nix { inherit bootstrap; };
  driver = make (
    { compiler, libc }:
    let
      rt = "${compiler}/lib/gcc/x86_64-unknown-linux-gnu/${compiler.version}";
      rawPrefix = rt;
      cxx = "${compiler}/include/c++/${compiler.version}";
    in
    {
      pname = "source-full-gnu-driver";
      version = compiler.version;
      src = null;
      passthru = {
        bintools = b.gnu-binutils;
        inherit libc;
        libcTools = [ ];
        defaultHardeningFlags = [ ];
        runtimeDirectories = [
          "${libc}/lib"
          rt
          "${compiler}/lib"
        ];
      };
      inherit (composition) base bash coreutils;
      plan = [
        {
          name = "driver.install";
          tools = [ b.gnused ];
          run = ''
            mkdir -p "$out/bin" "$out/include" "$out/target" "$out/selected/bin"
            # Intrinsic and runtime headers belong to this full compiler build.
            for header in ${rawPrefix}/include/*; do
              test -e "$header"
              ln -s "$header" "$out/include/"
            done
            for file in ${rt}/* ${compiler}/lib/* ${libc}/lib/*; do
              test -f "$file" || continue
              ln -sf "$file" "$out/target/$(basename "$file")"
            done
            # Start from the entire installed GCC spec set, retaining upstream mode,
            # startup, library suppression, pthread, PIE, shared and rdynamic semantics.
            ${b.gnused}/bin/sed \
              -e 's|%D|-L${compiler}/lib -L${rt} -L${libc}/lib|g' \
              ${compiler.artifact}/nix-support/production/builtin.specs > rebound.specs
            ${b.gnused}/bin/sed \
              -e '/^\*link:$/ { n; s|^|--sysroot=${libc} --disable-new-dtags -rpath ${compiler}/lib -rpath ${rt} -rpath ${libc}/lib -rpath-link ${compiler}/lib -rpath-link ${libc}/lib |; }' \
              -e '/^\*cpp:$/ { n; s|$| %{!nostdinc:-nostdinc -idirafter '"$out"'/include -idirafter ${libc}/include}|; }' \
              -e '/^\*cc1plus:$/ { n; s|^|%{!nostdinc:%{!nostdinc++:-isystem ${cxx} -isystem ${cxx}/x86_64-unknown-linux-gnu -isystem ${cxx}/backward}} |; }' \
              rebound.specs > "$out/target/specs"
            for tool in gcc g++ cpp; do
              cat > "$out/selected/bin/$tool" <<EOF2
            #!${shell}
            export GCC_EXEC_PREFIX=$out/target/
            exec ${compiler}/bin/$tool -B${rawPrefix}/ -B${compiler}/libexec/gcc/x86_64-unknown-linux-gnu/${compiler.version}/ --sysroot=${libc} -B$out/target/ -specs=$out/target/specs "\$@"
            EOF2
              chmod +x "$out/selected/bin/$tool"
            done
            # Reuse PR73 operand/response/NIX ordering. Add the native ABI rejection and
            # effective-specs query: GCC itself dumps builtins even with -specs selected.
            # Other query branches enter the permanently configured selected driver.
            ${b.gnused}/bin/sed \
              -e 's/-m32|-mx32/-m16|-m32|-mx32/g' \
              -e 's/this reduced GNU checkpoint/this native GNU driver/g; s/this checkpoint/this native driver/g; s/GNU checkpoint ABI mode/native GNU ABI mode/g; s/checkpoint limit/native driver limit/g' \
              -e 's/mode=link operand=0 query=0/mode=link operand=0 query=0 query_specs=0/' \
              -e '/--version|--help/i\        -dumpspecs) query=1; query_specs=1;;' \
              -e 's|query) exec @compiler@|query) if (( query_specs )); then exec ${coreutils}/bin/cat '"$out"'/target/specs; fi; exec @compiler@|' \
              -e 's|@bash@|${shell}|g' \
              -e 's|@tools@|${b.gnu-binutils}/bin:${b.gnu-bash}/bin:${coreutils}/bin|g' \
              -e 's|@compiler@|'"$out"'/selected/bin|g' \
              ${./gnu-environment-wrapper.sh} > "$out/bin/gcc"
            chmod +x "$out/bin/gcc"
            for name in g++ cpp cc c++ x86_64-unknown-linux-gnu-gcc x86_64-unknown-linux-gnu-g++ x86_64-unknown-linux-gnu-cpp; do
              ln -s gcc "$out/bin/$name"
            done
          '';
        }
      ];
    }
  ) { inherit compiler libc; };
in
driver

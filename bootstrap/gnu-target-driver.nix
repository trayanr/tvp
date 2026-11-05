# New target configuration over the unchanged, prior-GNU-hosted raw compiler.
{
  bootstrap ? import ./. { },
  profile ? import ./gnu-target-profile.nix { inherit bootstrap; },
}:
let
  b = bootstrap;
  inherit (profile) libc libgcc libstdcxx;
  compiler = b.gnu-gcc-unwrapped;
  oldRt = "${b.gnu-libgcc}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0";
  rt = "${libgcc}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0";
  rawPrefix = "${compiler}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0";
  cxx = "${libstdcxx}/include/c++/16.2.0";
  shell = "${b.gnu-bash}/bin/bash";
  coreutils = b.gnu-tool-floor.gnu-coreutils;
  driver = b.bash.runCommand "tvp-capability-gnu-target-driver" { } ''
    mkdir -p "$out/bin" "$out/include" "$out/target" "$out/selected/bin"
    # Preserve only genuine compiler intrinsic headers. Runtime header symlinks
    # installed by native-compiler.nix must be rebound to this generation.
    for header in ${rawPrefix}/include/*; do
      if [ ! -L "$header" ]; then ln -s "$header" "$out/include/"; fi
    done
    for header in ${rt}/include/* ${libgcc}/include/*; do
      test -f "$header"
      ln -sf "$header" "$out/include/"
    done
    for file in ${rt}/* ${libstdcxx}/lib/* ${libc}/lib/*; do
      test -f "$file" || continue
      ln -s "$file" "$out/target/$(basename "$file")"
    done
    # Start from the entire installed GCC spec set, retaining upstream mode,
    # startup, library suppression, pthread, PIE, shared and rdynamic semantics.
    ${b.gnused}/bin/sed \
      -e 's|${b.gnu-libc}|${libc}|g' \
      -e 's|${oldRt}|${rt}|g' \
      -e 's|${b.gnu-libstdcxx}|${libstdcxx}|g' \
      -e 's|%D|-L${libstdcxx}/lib -L${rt} -L${libc}/lib|g' \
      ${rawPrefix}/specs > rebound.specs
    ${b.gnused}/bin/sed \
      -e '/^\*link:$/ { n; s|^|--sysroot=${libc} |; }' \
      -e '/^\*cpp:$/ { n; s|$| %{!nostdinc:-nostdinc -idirafter '"$out"'/include -idirafter ${libc}/include}|; }' \
      -e '/^\*cc1plus:$/ { n; s|^|%{!nostdinc:%{!nostdinc++:-isystem ${cxx} -isystem ${cxx}/x86_64-unknown-linux-gnu -isystem ${cxx}/backward}} |; }' \
      rebound.specs > "$out/target/specs"
    for tool in gcc g++ cpp; do
      cat > "$out/selected/bin/$tool" <<EOF2
    #!${shell}
    export GCC_EXEC_PREFIX=$out/target/
    exec ${compiler}/bin/$tool -B${compiler}/libexec/gcc/x86_64-unknown-linux-gnu/16.2.0/ --sysroot=${libc} -B$out/target/ -specs=$out/target/specs "\$@"
    EOF2
      chmod +x "$out/selected/bin/$tool"
    done
    # Reuse PR73 operand/response/NIX ordering. Add the native ABI rejection and
    # effective-specs query: GCC itself dumps builtins even with -specs selected.
    # Other query branches enter the permanently configured selected driver.
    ${b.gnused}/bin/sed \
      -e 's/-m32|-mx32/-m16|-m32|-mx32/g' \
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
in
driver
// {
  bintools = b.gnu-binutils;
  inherit libc;
  libcTools = [ ];
  defaultHardeningFlags = [ ];
  runtimeDirectories = [
    "${libc}/lib"
    rt
    "${libstdcxx}/lib"
  ];
}

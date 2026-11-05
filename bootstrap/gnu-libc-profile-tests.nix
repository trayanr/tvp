# Explicit C consumer linking only; the old compiler's defaults are unchanged.
{
  bootstrap ? import ./. { },
  profile ? import ./gnu-libc-profile.nix { inherit bootstrap; },
}:
let
  b = bootstrap;
  libc = profile.libc;
  shell = "${b.gnu-bash}/bin/sh";
  loader = "${libc}/lib/ld-linux-x86-64.so.2";
in
b.bash.runCommand "tvp-bootstrap-gnu-libc-capability-contracts"
  {
    outputs = [
      "out"
      "evidence"
    ];
    nativeBuildInputs = [
      b.binutils
      b.build-python
    ];
  }
  ''
    mkdir -p "$out/bin" "$evidence"
    cc=${b.gnu-gcc-unwrapped}/bin/gcc
    # Override sysroot and startup objects for this probe only. -B also chooses
    # the matching new crti/crtn; gcc's own crtbegin/end remain unchanged.
    # The raw native compiler intentionally embeds prior runtime search paths.
    # Replace only this probe's link specs, never the installed compiler specs.
    printf '%s\n' '*link:' \
      '--sysroot=${libc} -m elf_x86_64 %{static:-static;:-dynamic-linker ${loader} -rpath ${libc}/lib}' \
      "" '*link_libgcc:' '-L${b.gnu-libgcc}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0 %D' "" \
      > profile.specs
    cp profile.specs "$evidence/"
    common=(-specs=$PWD/profile.specs --sysroot=${libc} -B${libc}/lib/ -O2 -g0 -static-libgcc
      '-DPROFILE_LIBC="${libc}"' '-DPROFILE_SHELL="${shell}"')
    env -i "$cc" "''${common[@]}" -v -Wl,-t,-t \
      -Wl,--dynamic-linker,${loader} -Wl,-rpath,${libc}/lib \
      ${./gnu-libc-probe.c} -o "$out/bin/dynamic" > "$evidence/dynamic-link.log" 2>&1
    env -i "$cc" "''${common[@]}" -DSTATIC_PROBE -static -no-pie -v -Wl,-t,-t \
      ${./gnu-libc-probe.c} -o "$out/bin/static" > "$evidence/static-link.log" 2>&1
    ${b.build-python}/bin/python3 -B ${./gnu-libc-profile-checks.py} \
      ${libc} ${b.gnu-libc} ${shell} "$out" "$evidence" ${b.binutils}/bin/readelf
  ''

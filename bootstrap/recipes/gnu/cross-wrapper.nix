# M-hosted construction driver with explicit G target inputs. Not GNU native.
{
  scope,
  cross,
  libc,
  runtime,
  cxxRuntime ? null,
}:
let
  inherit (scope) bash lib;
  rt =
    if runtime ? version then
      "${runtime}/lib/gcc/x86_64-unknown-linux-gnu/${runtime.version}"
    else
      "${runtime}/lib";
in
bash.runCommand "tvp-bootstrap-gnu-construction-driver" { } ''
    mkdir -p "$out/bin"
    for tool in gcc g++ cpp; do
      cat > "$out/bin/$tool" <<EOF2
  #!${bash}/bin/bash
  exec ${cross}/bin/x86_64-unknown-linux-gnu-$tool --sysroot=${libc} \\
    -B${scope.binutils}/bin/ -B${libc}/lib/ -B${rt}/ \\
    -Wl,--dynamic-linker=${libc}/lib/ld-linux-x86-64.so.2 \\
    -Wl,--disable-new-dtags,-rpath,${libc}/lib ${
      lib.optionalString (runtime ? version) "-Wl,-rpath,${rt}"
    } \\
    ${
      lib.optionalString (cxxRuntime != null)
        "-isystem ${cxxRuntime}/include/c++/16.2.0 -isystem ${cxxRuntime}/include/c++/16.2.0/x86_64-unknown-linux-gnu -L${cxxRuntime}/lib -Wl,-rpath,${cxxRuntime}/lib"
    } "\$@"
  EOF2
      chmod +x "$out/bin/$tool"
      ln -s "$tool" "$out/bin/x86_64-unknown-linux-gnu-$tool"
    done
    ln -s gcc "$out/bin/cc"
    ln -s g++ "$out/bin/c++"
''

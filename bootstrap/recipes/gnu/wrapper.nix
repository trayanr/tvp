{
  scope,
  compiler,
  shell,
  binutils,
  libc,
  runtime,
  cxxRuntime,
}:
let
  inherit (scope) bash;
in
bash.runCommand "tvp-bootstrap-gnu-gcc-wrapper-16.2.0" { } ''
  mkdir -p "$out/bin"
  for tool in gcc g++ cpp; do
    ${scope.gnused}/bin/sed \
      -e 's|@bash@|${shell}/bin/bash|g' \
      -e 's|@tools@|${binutils}/bin:${shell}/bin|g' \
      -e "s|@compiler@|${compiler}/bin/$tool|g" \
      ${./wrapper.sh} > "$out/bin/$tool"
    chmod +x "$out/bin/$tool"
    ln -s "$tool" "$out/bin/x86_64-unknown-linux-gnu-$tool"
  done
  ln -s gcc "$out/bin/cc"
  ln -s g++ "$out/bin/c++"
''

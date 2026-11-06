# Exact GCC fallback protocol: lock the inherited stdout open-file description.
{
  base,
  bash,
  coreutils,
  source,
  perl,
}:
final: {
  pname = "libgomp-flock";
  version = "16.2.0";
  src = source;
  inherit base bash coreutils;
  plan = [
    {
      name = "flock.install";
      tools = [ coreutils ];
      run = ''
          mkdir -p "$out/bin" "$out/share/libgomp-flock"
          { printf '#!${perl}/bin/perl\n'; tail -n +2 ${final.src}/libgomp/testsuite/flock; } > "$out/bin/flock"
          chmod +x "$out/bin/flock"
          cp ${final.src}/libgomp/testsuite/flock "$out/share/libgomp-flock/upstream"
        chmod a-x "$out/share/libgomp-flock/upstream"
      '';
    }
  ];
  meta.platforms = [ "x86_64-linux" ];
}

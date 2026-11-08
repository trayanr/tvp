# ctypes' raw-ld discovery test needs the same libc sysroot as the selected CC.
# A declared test-only tool; production Python/compiler behavior stays unchanged.
{
  builder,
  base,
  bash,
  coreutils,
}:
builder {
  recipe =
    {
      base,
      bash,
      coreutils,
    }:
    {
      pname = "python-test-sysroot-linker";
      version = "1";
      src = null;
      inherit base bash coreutils;
      plan = [
        {
          name = "linker.install";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/ld" <<'SH'
            #!${bash}/bin/bash
            exec ${base.compiler.bintools}/bin/ld --sysroot=${base.compiler.libc} "$@"
            SH
            chmod +x "$out/bin/ld"
          '';
        }
      ];
    };
  args = {
    inherit base bash coreutils;
  };
  dependencyNames = [
    "bash"
    "coreutils"
  ];
  metadata.kind = "python-test-support";
  selection.kind = "python-test-support";
  mkTests = _: { };
}

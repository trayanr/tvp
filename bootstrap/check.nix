{ tvp }:
tvp.builder {
  recipe =
    {
      base,
      bash,
      coreutils,
      python,
    }:
    {
      pname = "tvp-bootstrap-audit-contracts";
      version = "1";
      inherit base bash coreutils;
      plan = [
        {
          name = "audit.contracts";
          tools = [ python ];
          run = ''
            ${python}/bin/python3 -B ${./test_audit.py} ${./audit.py} > "$out"
            ${python}/bin/python3 -B ${./test_runtime_audit.py} ${./runtime-audit.py} >> "$out"
            ${python}/bin/python3 -B ${./test_gnu_runtime_audit.py} ${./gnu-runtime-audit.py} >> "$out"
            ${python}/bin/python3 -B ${./test_wrapper.py} ${bash}/bin/bash ${./recipes/gcc} >> "$out"
          '';
        }
      ];
    };
  args = {
    base = tvp.bases.default;
    inherit (tvp.packages) bash coreutils;
    python = tvp.packages.python_3;
  };
  dependencyNames = [ "python" ];
  metadata = { };
  selection.kind = "fixture";
  mkTests = _: { };
}

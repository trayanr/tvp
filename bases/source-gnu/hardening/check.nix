{ tvp }:
let
  candidate = import ../. { };
  inherit (candidate) builder tools base;
  pilots = import ./pilots.nix { inherit tvp candidate; };
  contracts = import ./contracts.nix { inherit candidate pilots; };
in
builder {
  args = { };
  dependencyNames = [ ];
  metadata = { };
  selection.kind = "source-gnu-consumer-hardening-check";
  mkTests = _: { };
  recipe =
    { }:
    {
      pname = "source-gnu-consumer-hardening-check";
      version = "1";
      src = null;
      inherit base;
      inherit (tools) bash coreutils;
      passthru = {
        inherit pilots contracts;
      };
      plan = [
        {
          name = "hardening.controls";
          tools = [ tools.python ];
          run = ''
            mkdir -p "$out"
            printf '%s\n' '${builtins.toJSON contracts}' > "$out/contracts.json"
            ${tools.python}/bin/python3 ${./test-adapter.py} ${./adapter.py} ${pilots.base.compiler} ${base.compiler} ${base.compiler.bintools}/bin/readelf "$out/artifacts" ${pilots.base.compiler.bintools} > "$out/controls.log" 2>&1
            cat "$out/controls.log"
          '';
        }
      ];
    };
}

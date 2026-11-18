{ ownedCLI, python3 }:
ownedCLI.python {
  name = "tvp-provenance";
  inherit python3;
  entrypoint = "provenance.py";
  systemVariable = "TVP_PROVENANCE_SYSTEM";
  files = {
    "provenance.py" = ./provenance.py;
    "recursive.py" = ./dependencies/recursive.py;
    "flake" = builtins.toFile "tvp-provenance-flake" "path:${../.}";
  };
}

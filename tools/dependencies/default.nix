{ ownedCLI, python3 }:
ownedCLI.python {
  name = "tvp-dependencies";
  inherit python3;
  files = {
    "report.py" = ./report.py;
    "recursive.py" = ./recursive.py;
  };
  entrypoint = "report.py";
  systemVariable = "TVP_DEPENDENCIES_SYSTEM";
}

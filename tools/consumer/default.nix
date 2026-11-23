{ ownedCLI, python3 }:
ownedCLI.python {
  name = "tvp";
  inherit python3;
  files = {
    "cli.py" = ./cli.py;
    "report.py" = ./report.py;
  };
  entrypoint = "cli.py";
  systemVariable = "TVP_CONSUMER_SYSTEM";
}

{ ownedCLI, python3 }:
ownedCLI.python {
  name = "tvp";
  inherit python3;
  files = {
    "cli.py" = ./cli.py;
    "report.py" = ./report.py;
    "audit.py" = ./audit.py;
    "audit_grype.py" = ./audit_grype.py;
    "audit_osv.py" = ./audit_osv.py;
  };
  entrypoint = "cli.py";
  systemVariable = "TVP_CONSUMER_SYSTEM";
}

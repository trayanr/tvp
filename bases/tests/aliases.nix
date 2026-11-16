# Pure selector checks: no compiler providers or derivations are evaluated.
{ lib }:
let
  aliases = import ../aliases.nix;
  select =
    versions:
    aliases {
      pname = "gcc";
      inherit versions;
    };
  current = select {
    "4.8.5" = "4.8.5";
    "4.9.4" = "4.9.4";
    "9.5.0" = "9.5.0";
    "13.3.0" = "13.3.0";
    "16.2.0" = "16.2.0";
  };
  advanced = select {
    "4.9.4" = "older";
    "4.10.0" = "newer";
    "9.9.0" = "older";
    "9.10.0" = "newer";
    "16.2.0" = "older";
    "16.2.1" = "newer";
  };
  lazy = select {
    "4.8.5" = throw "an unselected family was forced";
    "4.9.4" = {
      full = "selected";
      seed = throw "an unused stage was forced";
    };
    "16.2.0" = throw "an unrelated major was forced";
  };
  results = {
    majorNames =
      builtins.attrNames current == [
        "gcc_13"
        "gcc_16"
        "gcc_4"
        "gcc_9"
      ];
    gcc4Latest = current.gcc_4 == "4.9.4";
    gcc9Latest = current.gcc_9 == "9.5.0";
    gcc13Latest = current.gcc_13 == "13.3.0";
    gcc16Latest = current.gcc_16 == "16.2.0";
    numericMinor = advanced.gcc_4 == "newer" && advanced.gcc_9 == "newer";
    patchAdvances = advanced.gcc_16 == "newer";
    majorOnly = !(current ? gcc_4_9);
    lazySelection = lazy.gcc_4.full == "selected";
    empty = select { } == { };
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "TVP base alias contracts: ${lib.concatStringsSep ", " failed}";
results

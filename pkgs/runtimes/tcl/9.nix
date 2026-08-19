{ defs }:
[
  {
    def = defs."9.0.0";
    status = {
      level = "degraded";
      capability = "zipfsImage";
      reason = "Built with --disable-zipfs, so the script library installs as ordinary files and `info library` names a directory rather than //zipfs:/tcl_library. The zipfs command itself is present and working — mkzip, mount and list all succeed — so what is off is the self-contained interpreter, not the feature.";
      needs = "More than a bootstrap interpreter. Handing configure a TCLSH_NATIVE from a packaged Tcl 9 does get it to report `building with zipfs... yes`, but the resulting tree puts the scripts under lib/tcl9/9.0 with no image built and none mounted, and the interpreter then cannot find init.tcl at all.";
      blocked = {
        package = "tclsh9 (bootstrap)";
      };
    };
    releases = {
      "9.0.4" = "sha256-0K7UkjC8AqZcHgIp5l80WQpLA37EDVRvMlc7Rn91Ueo=";
      "9.0.3" = "sha256-JTe6DIYRLIyVP3wJ0z8TTdRcD7OnHy1/dpH9MB0sM6Y=";
      "9.0.2" = "sha256-4HTGqNm6LN35FLqXtmd6VS16UqPKECkkOJoFzLJJtSA=";
      "9.0.1" = "sha256-pysWB9ejmcdRSMgPzerYjtM3GimIQYHyAPIgDN7jO7w=";
      "9.0.0" = "sha256-O/2m267o6bHurMFRG04YoHqR3/gtmVTNuccp2Lyku7c=";
    };
  }
]

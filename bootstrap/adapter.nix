# Small pure adapter for the attributed early recipes; no package-set input.
{ system }:
let
  concatStringsSep = builtins.concatStringsSep;
  helpers = rec {
    optional = condition: value: if condition then [ value ] else [ ];
    concatMapStringsSep =
      separator: f: values:
      concatStringsSep separator (map f values);
    inherit concatStringsSep;
    makeBinPath = values: concatMapStringsSep ":" (value: "${value}/bin") values;
    removePrefix =
      prefix: value:
      let
        n = builtins.stringLength prefix;
      in
      if builtins.substring 0 n value == prefix then
        builtins.substring n (builtins.stringLength value - n) value
      else
        value;
    strings = helpers;
    licenses = {
      gpl3Plus = "GPL-3.0-or-later";
      lgpl3Plus = "LGPL-3.0-or-later";
      lgpl21Only = "LGPL-2.1-only";
      mit = "MIT";
    };
    teams.minimal-bootstrap = "upstream minimal-bootstrap contributors";
    platforms.all = [ system ];
    platforms.unix = [ system ];
  };
  derivationWithMeta =
    attrs:
    let
      passthru = attrs.passthru or { };
      drv = builtins.derivation (
        {
          inherit system;
          name = attrs.name or "${attrs.pname}-${attrs.version}";
          # Kaem must not use its built-in host PATH fallback.
          PATH = "";
          preferLocalBuild = true;
          allowSubstitutes = false;
        }
        // builtins.removeAttrs attrs [
          "meta"
          "passthru"
        ]
      );
    in
    drv
    // {
      meta = attrs.meta or { };
    }
    // passthru
    // (
      if passthru ? tests then
        {
          tests = builtins.mapAttrs (_: test: test drv) passthru.tests;
        }
      else
        { }
    );
in
{
  lib = helpers;
  inherit derivationWithMeta;
}

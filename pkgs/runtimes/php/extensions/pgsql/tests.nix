{ tvp }:
{
  package,
  lib,
  context,
}:
let
  runtime = import ../../with-extensions.nix {
    inherit lib tvp;
    php = package.php;
    extensions = [ package ];
  };
  postgresql = package.tvp.declaredTestDependencies.postgresql;
  bash = package.specification.base.tools.bash;
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = ''${runtime}/bin/php -r 'echo phpversion("pgsql");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${bash}/bin/bash ${../pdo_pgsql/with-postgresql.sh} ${postgresql} ${runtime}/bin/php ${./roundtrip.php}
      '';
      expected = "pgsql-roundtrip";
    };
  };
}

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
  php = "${runtime}/bin/php";
  bash = package.specification.base.tools.bash;
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = ''${php} -r 'if (in_array("pgsql", PDO::getAvailableDrivers(), true)) echo "pdo-pgsql";' '';
      expected = "pdo-pgsql";
    };
    roundtrip = {
      script = ''
        ${bash}/bin/bash ${./with-postgresql.sh} ${postgresql} ${php} ${./roundtrip.php}
      '';
      expected = "pdo-pgsql-roundtrip";
    };
  };
}

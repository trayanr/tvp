# Definition-owned smoke checks load the installed gem and its resolved gem graph.
{ lib }:
package:
{
  name,
  script,
  expected,
}:
let
  ruby = package.ruby;
  closure = lib.genericClosure {
    startSet = [
      {
        key = package.drvPath;
        value = package;
      }
    ];
    operator =
      item:
      map (dependency: {
        key = dependency.drvPath;
        value = dependency;
      }) (item.value.specification.dependencies or [ ]);
  };
  gemPaths = map (item: "${item.value}/${item.value.gemPath}") closure ++ [
    "${ruby}/${ruby.gemPath}"
  ];
in
ruby.testContext.mkTest {
  inherit package name expected;
  tools = [ ruby ];
  script = ''
    unset RUBYLIB BUNDLE_GEMFILE BUNDLE_PATH
    export GEM_HOME=${lib.escapeShellArg "${package}/${package.gemPath}"}
    export GEM_PATH=${lib.escapeShellArg (lib.concatStringsSep ":" gemPaths)}
    ${script}
  '';
}

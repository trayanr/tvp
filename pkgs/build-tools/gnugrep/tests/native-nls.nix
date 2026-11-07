# Current-context release catalogs and actual translated installed command.
{
  package,
  command ? "grep",
  locale,
}:
let
  deps = package.tvp.declaredDependencies;
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [
    deps.python
    locale
  ];
  tests.nls = {
    script = ''
      ${deps.python}/bin/python3 -B ${../../../../lib/tests/release-catalogs.py} ${package.src} ${package} ${
        if package.pname == "gnugrep" then
          "grep"
        else if package.pname == "gnused" then
          "sed"
        else if package.pname == "gnutar" then
          "tar"
        else
          package.pname
      } >&2
      LC_ALL=C ${package}/bin/${command} --help > untranslated
      LOCPATH=${locale} LC_ALL=fr_FR.UTF-8 ${package}/bin/${command} --help > translated
      test -s translated
      if cmp -s untranslated translated; then
        echo 'installed command did not translate' >&2
        exit 1
      fi
      grep -Eq 'Utilisation|Utilisation|usage|Usage|utilisation' translated
      echo translated-installed-command
    '';
    expected = "translated-installed-command";
  };
}

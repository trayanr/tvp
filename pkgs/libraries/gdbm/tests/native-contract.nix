{ package }:
let
  deps = package.tvp.deps;
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [
    deps.python
    deps.binutils
    deps.patchelf
  ];
  libraries = [ package ];
  tests = {
    cli-reorganize = {
      script = ''
        printf 'store answer 42\nreorganize\nfetch answer\n' | gdbmtool -n roundtrip > cli.txt
        grep -F 42 cli.txt >/dev/null
        gdbm_dump roundtrip dump.txt
        gdbm_load --replace dump.txt restored
        printf 'fetch answer\n' | gdbmtool restored > restored.txt
        grep -F 42 restored.txt >/dev/null
        test ! -e ${package}/lib/libgdbm.a
        test ! -e ${package}/lib/libgdbm_compat.a
        printf database-ok
      '';
      expected = "database-ok";
    };
  };
}

{ package }:
let
  s = package.specification;
in
package.testContext.mkSuite {
  inherit package;
  tools = s.environment.tools ++ [
    s.python
    s.gzip
  ];
  tests = {
    remote-protocol = {
      script = ''
        ${s.python}/bin/python3 -B ${./rmt-protocol.py} ${package}/libexec/rmt
      '';
      expected = "rmt-protocol-ok";
    };
    errors-and-manuals = {
      script = ''
        ${package}/bin/tar --help | grep -F -- '--rsh-command' >&2
        ${package}/bin/tar --help | grep -F -- '--rmt-command' >&2
        rc=0
        ${package}/bin/tar -cf missing.tar nonexistent 2> missing.log || rc=$?
        test "$rc" = 2
        grep -F nonexistent missing.log >&2
        printf 'broken archive' > broken.tar
        rc=0
        ${package}/bin/tar -tf broken.tar 2> broken.log || rc=$?
        test "$rc" = 2
        ${s.gzip}/bin/gzip -dc ${package}/share/man/man1/tar.1.gz | grep -F 'GNU' >&2
        ${s.gzip}/bin/gzip -dc ${package}/share/man/man8/rmt.8.gz | grep -F 'rmt' >&2
        test -s ${package}/share/info/tar.info
        echo errors-and-manuals-ok
      '';
      expected = "errors-and-manuals-ok";
    };
  };
}

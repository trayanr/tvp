{ package }:
let
  s = package.specification;
in
package.testContext.mkSuite {
  inherit package;
  tools = s.environment.tools ++ [
    s.python
    s.gzip
    s.binutils
  ];
  tests = {
    remote-protocol = {
      script = ''
        ${s.python}/bin/python3 -B ${./rmt-protocol.py} ${package}/libexec/rmt
        ${s.binutils}/bin/readelf --wide --dyn-syms ${package}/bin/tar > dynamic-symbols
        "$CC" ${./initgroups.c} -o independent-initgroups
        rc=0
        if grep -q 'initgroups@' dynamic-symbols; then
          ./independent-initgroups >&2 || rc=$?
        fi
        case "$rc" in
          0)
        mkdir remote-src remote-dest
        printf preserved > remote-src/file
        export RSH_LOG="$PWD/rsh.log"
        cat > local-rsh <<'EOF'
        #!${s.bash}/bin/bash
        set -euo pipefail
        test "$1" = localhost
        test "$(realpath "$2")" = '${package}/libexec/rmt'
        printf '%s\n' selected-local-rsh >> "$RSH_LOG"
        exec "$2"
        EOF
        chmod +x local-rsh
        # localhost resolves through the local hosts file. The selected shell
        # frontend directly execs installed rmt; it opens no network connection.
        ${package}/bin/tar --rsh-command="$PWD/local-rsh" -cf "localhost:$PWD/remote.tar" -C remote-src file
        ${package}/bin/tar --rsh-command="$PWD/local-rsh" -xf "localhost:$PWD/remote.tar" -C remote-dest
        cmp remote-src/file remote-dest/file
        test "$(grep -cx selected-local-rsh rsh.log)" = 2

            ;;
          77) echo 'SKIP remote archive transport: independent initgroups denied; direct rmt protocol PASS' >&2 ;;
          *) exit "$rc" ;;
        esac
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

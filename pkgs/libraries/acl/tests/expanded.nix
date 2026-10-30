{
  pkgs,
  tvpLib,
  package,
}:
let
  lib = pkgs.lib;
  filesystemTest =
    name: extraInputs: script:
    pkgs.runCommand "${package.pname}-${package.version}-${name}"
      {
        nativeBuildInputs = [ package ] ++ extraInputs;
        passthru = {
          inherit package;
          testName = name;
        };
        meta.description = "TVP ${name} test for ${package.pname} ${package.version}";
      }
      ''
        set -euo pipefail
        mkdir "$out"
        status=0
        bash -euo pipefail -c ${lib.escapeShellArg script} > "$out/log" 2>&1 || status=$?
        cat "$out/log" >&2
        case "$status" in
          0) echo PASS > "$out/status" ;;
          77) echo 'SKIP: filesystem rejects named ACLs' > "$out/status" ;;
          *) exit "$status" ;;
        esac
      '';
  runNative = fixture: ''
    cc -Wall -Wextra -Werror ${fixture} -lacl -o probe
    ./probe
  '';
in
(tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    upstream-filenames = {
      script =
        let
          cases =
            [
              {
                name = "acl-2.2.48.src.tar.gz";
                want = "2.2.48";
              }
              {
                name = "acl-2.4.0.tar.xz";
                want = "2.4.0";
              }
            ]
            ++ map
              (name: {
                inherit name;
                want = null;
              })
              [
                "prefix-acl-2.4.0.tar.gz"
                "acl-2.4.0.tar.gz.asc"
                "acl-2.4.0.tar.xz.sig"
                "acl-2.4.0.tar.gzjunk"
                "acl-2.4.0-rc1.tar.gz"
                "acl-2.4.0.README.tar.gz"
                "README-acl-2.4.0.tar.gz"
                "acl-2x4x0.tar.gz"
                "(acl-2.4.0.tar.gz)"
                "path/acl-2.4.0.tar.gz"
              ];
        in
        assert builtins.all (c: package.tvp.upstream.normalise c.name == c.want) cases;
        "echo ok";
      expected = "ok";
    };
    public-api = {
      script = ''
        cc -Wall -Wextra -Werror ${./fixtures/public.c} -lacl -o public
        ./public
      '';
      expected = "ok";
      extraInputs = [ package.tvp.cc ];
    };
    exact-library = {
      script = ''
        test -L ${package}/lib/libacl.so
        test -L ${package}/lib/libacl.so.1
        test "$(basename "$(readlink -f ${package}/lib/libacl.so.1)")" = libacl.so.1.${
          if package.version == "2.4.0" then "2" else "1"
        }.${
          if package.version == "2.3.0" then
            "230"
          else if package.version == "2.3.1" then
            "2301"
          else if package.version == "2.3.2" then
            "2302"
          else
            "2400"
        }
        readelf -d ${package}/lib/libacl.so.1 | grep -F 'Library soname: [libacl.so.1]' >&2
        ${lib.optionalString (lib.versionAtLeast package.version "2.4.0") ''
          if readelf -d ${package}/lib/libacl.so.1 | grep -q 'Shared library: \[libattr'; then
            echo "unexpected libattr DT_NEEDED" >&2
            exit 1
          fi
        ''}
        cc -Wall -Wextra -Werror ${./fixtures/loading.c} -ldl -o loading
        ./loading ${package}/lib/libacl.so.1
      '';
      expected = "ok";
      extraInputs = [ package.tvp.cc ];
    };
    pkgconfig = {
      script = ''
        test "$(pkg-config --modversion libacl)" = ${lib.escapeShellArg package.version}
        test -z "$(pkg-config --print-requires libacl)"
        test -z "$(pkg-config --print-requires-private libacl)"
        cc -Wall -Wextra -Werror ${./fixtures/public.c} $(pkg-config --cflags --libs libacl) -o consumer
        ./consumer
      '';
      expected = "ok";
      extraInputs = [
        package.tvp.cc
        pkgs.pkg-config
      ];
    };
  };
})
// {
  native-acls = filesystemTest "native-acls" [ package.tvp.cc ] (runNative ./fixtures/native.c);
  cli-fixtures = filesystemTest "cli-fixtures" [ ] ''
    bash ${./fixtures/cli.sh} ${lib.escapeShellArg package.version}
  '';
}
// lib.optionalAttrs (lib.versionAtLeast package.version "2.4.0") {
  at-api = filesystemTest "at-api" [ package.tvp.cc ] (runNative ./fixtures/at.c);
}

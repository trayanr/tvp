{
  pkgs,
  pkg-config,
  tvpLib,
  package,
}:
let
  commonTools = with package.tvp.declaredDependencies; [
    sed
    grep
    gawk
    diffutils
    binutils
  ];

  lib = pkgs.lib;
  filesystemTest =
    name: extraInputs: script:
    (import ../../../../lib/tests/recorded.nix) {
      inherit package name;
      tools = commonTools ++ extraInputs;
      libraries = [ package ];
      script = ''
        set -euo pipefail
        mkdir "$out"
        "$CC" ${../../../../lib/tests/filesystem-capabilities.c} -o filesystem-preflight
        status=0
        ./filesystem-preflight acls > "$out/preflight.log" 2>&1 || status=$?
        cat "$out/preflight.log" >&2
        case "$status" in
          0) ;;
          77)
            echo 'SKIP: independent kernel ACL preflight unavailable' > "$out/status"
            exit 0
            ;;
          *) exit "$status" ;;
        esac
        status=0
        bash -euo pipefail -c ${lib.escapeShellArg script} > "$out/log" 2>&1 || status=$?
        cat "$out/log" >&2
        case "$status" in
          0) echo PASS > "$out/status" ;;
          77)
            echo 'ACL test returned skip after successful kernel preflight' >&2
            exit 1
            ;;
          *) exit "$status" ;;
        esac
      '';
    };
  runNative = fixture: ''
    "$CC" -Wall -Wextra -Werror ${fixture} -lacl -o probe
    ./probe
  '';
in
(package.testContext.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = commonTools;
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
        "$CC" -Wall -Wextra -Werror ${./fixtures/public.c} -lacl -o public
        ./public
      '';
      expected = "ok";
      tools = commonTools ++ [ package.tvp.cc ];
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
        "$CC" -Wall -Wextra -Werror ${./fixtures/loading.c} -ldl -o loading
        ./loading ${package}/lib/libacl.so.1
      '';
      expected = "ok";
      tools = commonTools ++ [ package.tvp.cc ];
    };
    pkgconfig = {
      script = ''
        export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig:${package}/share/pkgconfig
        test "$(pkg-config --modversion libacl)" = ${lib.escapeShellArg package.version}
        test -z "$(pkg-config --print-requires libacl)"
        test -z "$(pkg-config --print-requires-private libacl)"
        "$CC" -Wall -Wextra -Werror ${./fixtures/public.c} $(pkg-config --cflags --libs libacl) -o consumer
        ./consumer
      '';
      expected = "ok";
      tools = commonTools ++ [
        package.tvp.cc
        pkg-config
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

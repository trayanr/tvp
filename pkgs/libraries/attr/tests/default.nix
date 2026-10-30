{
  pkgs,
  tvpLib,
  package,
}:
(tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''
        ${package}/bin/getfattr --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    upstream-metadata = {
      script =
        let
          upstream = package.tvp.upstream;
          fixtures = {
            "attr-2.4.44.src.tar.gz" = "2.4.44";
            "attr-2.4.48.tar.gz" = "2.4.48";
            "attr-2.6.0.tar.gz" = "2.6.0";
            "prefixattr-9.9.9.tar.gz" = null;
            "prefix!attr-9.9.9.tar.gz" = null;
            "attr-9.9.9.tar.gz@junk" = null;
            "attr-9.9.9.tar.gz.sig" = null;
            "attr-9.9.9.tar.gz.README" = null;
            "attr-9.9.9.tar.gz.junk" = null;
            "attr-2.7.0-rc1.tar.gz" = null;
          };
          valid = pkgs.lib.all (file: upstream.normalise file == fixtures.${file}) (
            builtins.attrNames fixtures
          );
        in
        assert valid;
        ''
          grep -oE ${pkgs.lib.escapeShellArg upstream.pattern} ${./fixtures/upstream-filenames.txt} | sort -u > actual
          printf '%s\n' ${pkgs.lib.escapeShellArgs (builtins.attrNames fixtures)} | sort -u > expected
          cmp expected actual
          echo ok
        '';
      expected = "ok";
    };
    library-api = {
      script = ''
        revision=${
          if package.version == "2.5.0" then
            "250"
          else
            (
              {
                "2.5.1" = "2501";
                "2.5.2" = "2502";
                "2.6.0" = "2600";
              }
              .${package.version}
            )
        }
        test "$(readlink ${package}/lib/libattr.so)" = "libattr.so.1.1.$revision"
        test "$(readlink ${package}/lib/libattr.so.1)" = "libattr.so.1.1.$revision"
        readelf -d ${package}/lib/libattr.so | grep -Fq 'Library soname: [libattr.so.1]'
        cc ${./fixtures/api.c} -lattr -ldl -o api
        ./api ${package}/lib/libattr.so.1 --linkage-only
      '';
      expected = "ok";
      extraInputs = [
        package.tvp.cc
        package.tvp.cc.bintools
      ];
    };
    operation = {
      script = ''
        cc ${./fixtures/policy.c} -lattr -o policy
        ./policy
      '';
      expected = "ok";
      extraInputs = [ package.tvp.cc ];
    };
  };
})
// {
  # Keep unsupported filesystems visible in the output rather than reporting
  # the xattr operations as passing. Other preflight errors are fatal.
  xattrs =
    pkgs.runCommand "attr-${package.version}-xattrs"
      {
        nativeBuildInputs = [
          package
          package.tvp.cc
        ];
        passthru = {
          inherit package;
          testName = "xattrs";
        };
      }
      ''
        set -euo pipefail
        mkdir "$out"
        cc ${./fixtures/xattr-support.c} -o preflight
        status=0
        ./preflight 2> "$out/preflight.log" || status=$?
        cat "$out/preflight.log" >&2
        if test "$status" = 77; then
          echo 'SKIP: user xattrs unavailable (EOPNOTSUPP)' > "$out/status"
        else
          test "$status" = 0
          cc ${./fixtures/api.c} -lattr -ldl -o api
          ./api ${package}/lib/libattr.so.1 > "$out/api.log"
          bash ${./fixtures/restore.sh} ${package.version} > "$out/restore.log"
          test "$(cat "$out/api.log")" = ok
          test "$(cat "$out/restore.log")" = ok
          echo PASS > "$out/status"
        fi
      '';
}

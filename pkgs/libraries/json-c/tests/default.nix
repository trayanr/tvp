{
  pkgs,
  tvpLib,
  package,
  pkg-config,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    public-api = {
      script = ''
        set -euo pipefail
        cc -Wall -Wextra -Werror ${./fixtures/api.c} -ljson-c -o api
        ./api
      '';
      expected = "ok";
      extraInputs = [ package.tvp.cc ];
    };
    static-api = {
      script = ''
        set -euo pipefail
        cc -Wall -Wextra -Werror ${./fixtures/api.c} ${package}/lib/libjson-c.a -lm -o api
        ./api
      '';
      expected = "ok";
      extraInputs = [ package.tvp.cc ];
    };
    pkgconfig = {
      script = ''
        set -euo pipefail
        export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
        actualVersion=$(pkg-config --modversion json-c) || exit 1
        test "$actualVersion" = ${pkgs.lib.escapeShellArg package.version}
        flags=$(pkg-config --cflags --libs json-c) || exit 1
        cc -Wall -Wextra -Werror ${./fixtures/api.c} $flags -o api
        ./api
      '';
      expected = "ok";
      extraInputs = [
        package.tvp.cc
        pkg-config
      ];
    };
    installed-features = {
      script = ''
        set -euo pipefail
        test -f ${package}/lib/libjson-c.a
        test -L ${package}/lib/libjson-c.so
        test -f ${package}/include/json-c/json_pointer.h
        test -f ${package}/include/json-c/json_patch.h
        test -f ${package}/lib/cmake/json-c/json-c-config.cmake
        echo ok
      '';
      expected = "ok";
    };
    upstream-tags = {
      script =
        let
          normalise = package.tvp.upstream.normalise;
        in
        assert normalise "json-c-0.19-20260627" == "0.19";
        assert normalise "json-c-0.18-20240915" == "0.18";
        assert builtins.all (tag: normalise tag == null) [
          "json-c-0.19-rc1"
          "json-c-0.19-20260627-extra"
          "v0.19"
          "prefix-json-c-0.19-20260627"
          "json-c-0x19-20260627"
        ];
        "echo ok";
      expected = "ok";
    };
  };
}

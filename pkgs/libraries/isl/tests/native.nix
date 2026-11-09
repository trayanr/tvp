{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  gmp = package.tvp.deps.gmp;
  patchelf = package.specification.tools.patchelf;
  candidate = import ../../../../bases/source-gnu { };
in
package.testContext.mkSuite {
  inherit package;
  tools = [
    patchelf
    candidate.tools.pkgConfig
    candidate.tools.grep
  ];
  libraries = [ package ];
  tests = {
    customization = {
      script = "echo customization";
      expected = import ./customization.nix { inherit package; };
    };
    steps-replacement = {
      script =
        let
          control = package.editSteps (_: [
            {
              name = "contract.probe";
              run = ''mkdir -p "$out"; printf '%s\n' 'edited plan executed' > "$out/marker"'';
            }
          ]);
        in
        ''cat ${control}/marker'';
      expected = "edited plan executed";
    };
    version = {
      script = ''cc ${./fixtures/version.c} -lisl -lgmp -o version; ./version > version.log; grep -oE '[0-9]+\.[0-9]+' version.log'';
      expected = package.version;
    };
    arithmetic = {
      script = ''cc ${./fixtures/arithmetic.c} -lisl -lgmp -o arithmetic; ./arithmetic'';
      expected = "5";
    };
    semantics = {
      script = ''cc -std=c99 -Wall -Wextra -Werror -DMODERN_API ${./fixtures/semantics.c} -lisl -lgmp -o semantics; ./semantics > semantics.log; cat semantics.log >&2; echo semantics'';
      expected = "semantics";
    };
    cpp11 = {
      script = ''c++ -std=c++11 -Wall -Wextra -Werror ${./fixtures/consumer.cc} -lisl -lgmp -o consumer; ./consumer > consumer.log; cat consumer.log >&2; echo cpp11'';
      expected = "cpp11";
    };
    cpp17 = {
      script = ''c++ -std=c++17 -Wall -Wextra -Werror ${./fixtures/consumer.cc} -lisl -lgmp -o consumer; ./consumer > consumer.log; cat consumer.log >&2; echo cpp17'';
      expected = "cpp17";
    };
    static = {
      script = ''cc ${./fixtures/arithmetic.c} ${package}/lib/libisl.a -lgmp -o arithmetic; ./arithmetic'';
      expected = "5";
    };
    pkg-config = {
      script = ''
        pkg-config --static --libs isl > static-libs
        grep -q -- '-lgmp' static-libs
        cc ${./fixtures/arithmetic.c} $(pkg-config --cflags --libs isl) -o arithmetic
        test "$(./arithmetic)" = 5
        pkg-config --modversion isl
      '';
      expected = package.version;
    };
    loaded-library = {
      script = ''
        cc ${./fixtures/loaded-native.c} -lisl -lgmp -ldl -o loaded
        ./loaded ${package}/lib/libisl.so ${gmp}/lib/libgmp.so ${pkgs.lib.escapeShellArg package.version} > loaded.log
        cat loaded.log >&2
        test "$(patchelf --print-soname ${package}/lib/libisl.so)" = libisl.so.23
        patchelf --print-needed ${package}/lib/libisl.so > needed
        test "$(grep -cx libgmp.so.10 needed)" = 1
        echo loaded
      '';
      expected = "loaded";
    };
    upstream-python = {
      tools = [
        package.tvp.declaredTestDependencies.python3
        candidate.tools.tar
        candidate.tools.xz
      ];
      script = ''
        tar -xJf ${package.src} --strip-components=1 isl-${package.version}/interface/isl.py isl-${package.version}/isl_test_python.py
        PYTHONPATH="$PWD/interface" LD_LIBRARY_PATH=${package}/lib python3 isl_test_python.py > upstream-python.log 2>&1 || { status=$?; cat upstream-python.log >&2; exit "$status"; }
        cat upstream-python.log >&2
        echo upstream-python
      '';
      expected = "upstream-python";
    };
    tracker = {
      script = ''echo tracker'';
      expected =
        assert package.tvp.upstream.normalise ''href="isl-0.28.tar.xz"'' == "0.28";
        assert package.tvp.upstream.normalise ''href="isl-0.28.tar.xz.junk"'' == null;
        "tracker";
    };
  };
}

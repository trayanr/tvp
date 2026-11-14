# One installed assertion suite for every ISL release and effective dependency set.
{
  package,
  lib,
  context,
}:
let
  s = package.specification;
  runtimeGmp = builtins.filter (p: (p.pname or null) == "gmp") s.runtime.libraries;
  gmp =
    assert builtins.length runtimeGmp == 1;
    builtins.head runtimeGmp;
  patchelf = s.base.standardTools.patchelf;
  modern = s.installedInterface.cppBindings;
in
context.mkSuite {
  inherit package;
  tools = [
    patchelf
    package.tvp.declaredTestDependencies.pkg-config
    s.base.standardTools.grep
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
      script = ''cc -std=c99 -Wall -Wextra -Werror ${lib.optionalString modern "-DMODERN_API"} ${./fixtures/semantics.c} -lisl -lgmp -o semantics; ./semantics > semantics.log; cat semantics.log >&2; echo semantics'';
      expected = "semantics";
    };
    cpp11 = {
      script =
        if !modern then
          ''test ! -e ${package}/include/isl/cpp.h; echo 'SKIP ISL 0.20 has no installed C++ bindings' >&2; echo cpp11''
        else
          ''c++ -std=c++11 -Wall -Wextra -Werror ${./fixtures/consumer.cc} -lisl -lgmp -o consumer; ./consumer > consumer.log; cat consumer.log >&2; echo cpp11'';
      expected = "cpp11";
    };
    cpp17 = {
      script =
        if !modern then
          ''test ! -e ${package}/include/isl/cpp.h; echo 'SKIP ISL 0.20 has no installed C++ bindings' >&2; echo cpp17''
        else
          ''c++ -std=c++17 -Wall -Wextra -Werror ${./fixtures/consumer.cc} -lisl -lgmp -o consumer; ./consumer > consumer.log; cat consumer.log >&2; echo cpp17'';
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
      # Link the probe with the final runtime GMP; the package's development
      # interface intentionally still records its construction headers/provider.
      libraries = [ gmp ];
      script = ''
        cc -I${package}/include -I${lib.getDev s.gmp}/include -L${package}/lib -Wl,-rpath,${package}/lib \
          ${./fixtures/loaded-native.c} -lisl -lgmp -ldl -o loaded
        ./loaded ${package}/lib/libisl.so ${gmp}/lib/libgmp.so ${lib.escapeShellArg package.version} \
          ${lib.escapeShellArg (s.gmp.tvp.reportedVersion or s.gmp.version)} \
          ${lib.escapeShellArg (gmp.tvp.reportedVersion or gmp.version)} > loaded.log
        cat loaded.log >&2
        test "$(patchelf --print-soname ${package}/lib/libisl.so)" = libisl.so.${s.installedInterface.sonameMajor}
        patchelf --print-needed ${package}/lib/libisl.so > needed
        test "$(grep -cx libgmp.so.10 needed)" = 1
        echo loaded
      '';
      expected = "loaded";
    };
    upstream-python = {
      tools = [
        package.tvp.declaredTestDependencies.python3
        s.base.standardTools.gnutar
        s.base.standardTools.xz
      ];
      script =
        if lib.versionAtLeast package.version "0.28" then
          ''
            tar -xJf ${package.src} --strip-components=1 isl-${package.version}/interface/isl.py isl-${package.version}/isl_test_python.py
            PYTHONPATH="$PWD/interface" LD_LIBRARY_PATH=${package}/lib python3 isl_test_python.py > upstream-python.log 2>&1 || { status=$?; cat upstream-python.log >&2; exit "$status"; }
            cat upstream-python.log >&2
            echo upstream-python
          ''
        else if lib.versionOlder package.version "0.27" then
          ''
            tar -tJf ${package.src} > archive-members
            if grep -qx 'isl-${package.version}/isl_test_python.py' archive-members; then exit 1; fi
            echo 'SKIP upstream Python: optional Clang generator required; no shipped root test group' >&2
            echo upstream-python
          ''
        else
          ''
            tar -xJf ${package.src} --strip-components=1 isl-${package.version}/interface/isl.py isl-${package.version}/isl_test_python.py
            # Retain the raw borrowed-reference result before the existing test-only
            # 0.27 getter backport (see patches/0.27-user-reference.patch).
            status=0
            PYTHONPATH="$PWD/interface" LD_LIBRARY_PATH=${package}/lib python3 isl_test_python.py > raw-python.log 2>&1 || status=$?
            cat raw-python.log >&2
            echo "RAW upstream Python status=$status" >&2
            python3 -B - <<'PYTHON'
            from pathlib import Path
            p = Path('interface/isl.py')
            text = p.read_text()
            old = '        return isl.isl_id_get_user(self.ptr)'
            assert text.count(old) == 1
            p.write_text(text.replace(old, '        user = isl.isl_id_get_user(self.ptr)\n        pythonapi.Py_IncRef(py_object(user))\n        return user'))
            PYTHON
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

// (
  if
    (package ? specification)
    && (package.specification ? upstreamPlan)
    && (package.specification.upstreamCheck.enabled or true)
  then
    {
      # Independent native upstream registration.
      upstream = context.mkUpstream { inherit package; };
    }
  else
    { }
)

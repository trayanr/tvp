{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''
        ${package}/bin/bzip2 --help 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf preserved | ${package}/bin/bzip2 > sample.bz2
        ${package}/bin/bzip2 -t sample.bz2
        ${package}/bin/bzip2 -dc sample.bz2
      '';
      expected = "preserved";
    };
  };
}
// tvpLib.tests.mkSuite {
  inherit package;
  # Use the package's compiler and base for the new consumer while retaining the
  # existing version/operation test derivations.
  pkgs = tvpLib.tests.withBase {
    inherit pkgs;
    base.stdenv = package.stdenv;
  };
  tests.shared-library = {
    extraInputs = [
      package.tvp.cc
      package.tvp.cc.bintools.bintools
    ];
    script = ''
      library="${package}/lib/libbz2.so.${package.version}"
      test -f "$library"
      for name in libbz2.so libbz2.so.1 libbz2.so.1.0; do
        test -L "${package}/lib/$name"
        test "$(readlink -f "${package}/lib/$name")" = "$library"
      done
      readelf -d "$library" | grep -F '(SONAME)' | grep -F '[libbz2.so.1.0]' >/dev/null

      cc ${./fixtures/shared-library.c} -I${package}/include \
        -L${package}/lib -Wl,-rpath,${package}/lib -lbz2 -o consumer
      readelf -d consumer | grep -F '(NEEDED)' | grep -F '[libbz2.so.1.0]' >/dev/null
      LD_TRACE_LOADED_OBJECTS=1 ./consumer > loaded
      grep -F "libbz2.so.1.0 => ${package}/lib/libbz2.so.1.0 " loaded >/dev/null
      ./consumer ${package.version}
    '';
    expected = package.version;
  };
}

{
  pkgs,
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
in

package.testContext.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = commonTools;
  tests = {
    version = {
      script = ''
        ${package}/bin/bzip2 --help 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    static = {
      tools = commonTools ++ [ package.tvp.cc ];
      script = ''
        "$CC" ${./fixtures/shared-library.c} ${package}/lib/libbz2.a -o static
        ./static ${package.version}
      '';
      expected = package.version;
    };
    recover = {
      script = ''
        printf 'recover preserved' > message
        ${package}/bin/bzip2 -c message > message.bz2
        ${package}/bin/bzip2recover message.bz2 >&2
        ${package}/bin/bzip2 -dc rec00001message.bz2
      '';
      expected = "recover preserved";
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
// package.testContext.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = commonTools;
  tests.shared-library = {
    tools = commonTools ++ [
      package.tvp.cc
      package.tvp.declaredDependencies.binutils
    ];
    script = ''
      library="${package}/lib/libbz2.so.${package.version}"
      test -f "$library"
      for name in libbz2.so libbz2.so.1 libbz2.so.1.0; do
        test -L "${package}/lib/$name"
        test "$(readlink -f "${package}/lib/$name")" = "$library"
      done
      readelf -d "$library" | grep -F '(SONAME)' | grep -F '[libbz2.so.1.0]' >/dev/null

      "$CC" ${./fixtures/shared-library.c} -I${package}/include \
        -L${package}/lib -Wl,-rpath,${package}/lib -lbz2 -o consumer
      readelf -d consumer | grep -F '(NEEDED)' | grep -F '[libbz2.so.1.0]' >/dev/null
      LD_TRACE_LOADED_OBJECTS=1 ./consumer > loaded
      grep -F "libbz2.so.1.0 => ${package}/lib/libbz2.so.1.0 " loaded >/dev/null
      ./consumer ${package.version}
    '';
    expected = package.version;
  };
}

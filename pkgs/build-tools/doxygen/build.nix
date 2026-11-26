{
  tvp,
  lib,
  base,
  src,
  version,
  bison,
  flex,
  python,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  cmake = "${tools.cmake}/bin/cmake";
  gcc = final.base.compiler.cc;
  paths = [ "bin" ];
in
{
  pname = "doxygen";
  inherit
    base
    src
    version
    bison
    flex
    python
    ;
  inherit (tools) bash coreutils;
  environment.tools = [
    tools.cmake
    tools.ninja
    final.bison
    final.flex
    final.python
  ];
  runtime.libraries = [ ];
  plan = [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (command "doxygen.configure" ''
      ${cmake} -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$out" \
        -DCMAKE_MAKE_PROGRAM=${tools.ninja}/bin/ninja \
        -DCMAKE_C_COMPILER_AR=${gcc}/bin/gcc-ar -DCMAKE_CXX_COMPILER_AR=${gcc}/bin/gcc-ar \
        -DCMAKE_C_COMPILER_RANLIB=${gcc}/bin/gcc-ranlib -DCMAKE_CXX_COMPILER_RANLIB=${gcc}/bin/gcc-ranlib \
        -DBISON_EXECUTABLE=${final.bison}/bin/bison \
        -DFLEX_EXECUTABLE=${final.flex}/bin/flex \
        -DPython_EXECUTABLE=${final.python}/bin/python3
    '')
    (command "doxygen.build" ''${cmake} --build build --parallel "$NIX_BUILD_CORES"'')
    (command "doxygen.install" ''
      ${cmake} --install build
      install -Dm644 LICENSE "$out/share/licenses/doxygen/LICENSE"
      test -x "$out/bin/doxygen"
    '')
    (steps.split "doxygen.finalize")
    (outputs.copyArtifacts { })
    (outputs.strip { inherit paths; })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths { inherit paths; })
  ];
  meta = {
    description = "Documentation generator for source code";
    homepage = "https://www.doxygen.nl/";
    mainProgram = "doxygen";
    license = lib.licenses.gpl2Only;
  };
}

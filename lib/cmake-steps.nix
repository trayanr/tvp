# Selected native CMake with Unix Makefiles. Discovery is the tool's provider;
# invocation policy and the generator's real install target belong here.
{ lib }:
{
  name,
  cmake,
  make,
  tools ? [ ],
  libraries ? [ ],
  env ? { },
  sourceDirectory ? "source",
  buildDirectory ? "build",
  cmakeFlags ? [ ],
  checkFlags ? [ ],
  doCheck ? true,
}:
let
  record = phase: run: {
    name = "${name}.${phase}";
    tools = [
      cmake
      make
    ] ++ tools;
    inherit libraries env run;
  };
in
[
  (record "configure" ''
    ${cmake}/bin/cmake -S ${lib.escapeShellArg sourceDirectory} -B ${lib.escapeShellArg buildDirectory} -G 'Unix Makefiles' \
      -DCMAKE_MAKE_PROGRAM=${lib.escapeShellArg "${make}/bin/make"} \
      -DCMAKE_INSTALL_PREFIX="$out" -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF \
      -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF ${lib.escapeShellArgs cmakeFlags}
  '')
  (record "build" ''${cmake}/bin/cmake --build ${lib.escapeShellArg buildDirectory} --parallel "$NIX_BUILD_CORES"'')
  (
    (record "check" ''${cmake}/bin/ctest --test-dir ${lib.escapeShellArg buildDirectory} --output-on-failure -j "$NIX_BUILD_CORES" ${lib.escapeShellArgs checkFlags}'')
    // {
      enabled = doCheck;
    }
  )
  (record "install" ''${cmake}/bin/cmake --build ${lib.escapeShellArg buildDirectory} --target install --parallel "$NIX_BUILD_CORES"'')
]

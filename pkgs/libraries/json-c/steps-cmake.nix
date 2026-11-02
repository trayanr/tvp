# Private native adapter: selected modern CMake, Unix Makefiles, one out.
{ lib }:
{
  name,
  cmake,
  make,
  doCheck,
}:
(import ../../../lib/build-steps.nix).namespace name [
  {
    name = "configure";
    tools = [
      cmake
      make
    ];
    run = ''
      compilerLibc=$(''${CC:-cc} -print-file-name=libc.so)
      case "$compilerLibc" in
        /nix/store/*/lib/libc.so)
          addToSearchPath CMAKE_PREFIX_PATH "$(dirname "$(dirname "$compilerLibc")")" ;;
      esac
      cmake -S source -B build -G 'Unix Makefiles' \
        -DCMAKE_MAKE_PROGRAM=${lib.escapeShellArg "${make}/bin/make"} \
        -DCMAKE_INSTALL_PREFIX="$out" -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF \
        -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF
    '';
  }
  {
    name = "build";
    tools = [
      cmake
      make
    ];
    run = ''cmake --build build --parallel "$NIX_BUILD_CORES"'';
  }
  {
    name = "check";
    enabled = doCheck;
    tools = [ cmake ];
    run = ''ctest --test-dir build --output-on-failure -j "$NIX_BUILD_CORES"'';
  }
  {
    name = "install";
    tools = [
      cmake
      make
    ];
    # Keep the generator's install target, as in the canonical build.
    run = ''cmake --build build --target install --parallel "$NIX_BUILD_CORES"'';
  }
]

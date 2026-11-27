{
  tvp,
  lib,
  base,
  src,
  version,
  git,
  numa,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command {
    cwd = ".";
    environment = final.environment;
  };
  cmake = "${tools.cmake}/bin/cmake";
  paths = [
    "bin"
    "lib"
  ];
  configure = lib.removeSuffix "\n" ''
    ${cmake} -S source/source -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_MAKE_PROGRAM=${tools.gnumake}/bin/make \
      -DCMAKE_INSTALL_PREFIX="$out" -DLIB_INSTALL_DIR=lib \
      -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF \
      -DNUMA_ROOT_DIR=${final.numa} -DNUMA_INCLUDE_DIR=${final.numa}/include \
      -DNUMA_LIBRARY=${final.numa}/lib/libnuma.so \
      -DENABLE_ASSEMBLY=OFF
  '';
in
{
  pname = "x265";
  inherit
    base
    src
    version
    git
    numa
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment = {
    tools = [
      tools.cmake
      tools.gnumake
      tools.binutils
      final.git
    ];
    libraries = [ final.numa ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (command "x265.build-high-depth" ''
      # This follows upstream's multilib layout. The high-depth libraries use
      # private C++ namespaces and are linked into the public 8-bit build.
      for depth in 10 12; do
        main12=OFF
        if test "$depth" = 12; then main12=ON; fi
        ${configure} -B "build-$depth" -DHIGH_BIT_DEPTH=ON -DMAIN12="$main12" \
          -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF -DENABLE_CLI=OFF
        ${cmake} --build "build-$depth" --parallel "$NIX_BUILD_CORES"
      done
    '')
    (command "x265.configure" ''
      ${configure} -B build -DENABLE_SHARED=ON -DENABLE_CLI=ON \
        -DEXTRA_LIB="$PWD/build-10/libx265.a;$PWD/build-12/libx265.a" \
        -DLINKED_10BIT=ON -DLINKED_12BIT=ON -DCMAKE_INSTALL_RPATH="$out/lib"
    '')
    (command "x265.build" ''
      ${cmake} --build build --parallel "$NIX_BUILD_CORES"
    '')
    (command "x265.install" ''
      ${cmake} --install build
      # Combine the three upstream static libraries under the public archive name.
      mv "$out/lib/libx265.a" libx265-main.a
      ${tools.binutils}/bin/ar -M <<EOF_AR
      CREATE $out/lib/libx265.a
      ADDLIB libx265-main.a
      ADDLIB build-10/libx265.a
      ADDLIB build-12/libx265.a
      SAVE
      END
      EOF_AR
      test -f "$out/lib/pkgconfig/x265.pc"
    '')
    (steps.split "x265.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    (outputs.relocateText { paths = [ "lib/pkgconfig" ]; })
    (outputs.strip { inherit paths; })
    (outputs.stripArchives { paths = [ "lib" ]; })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths { inherit paths; })
  ];
  meta = {
    description = "HEVC encoder supporting 8-bit, 10-bit and 12-bit pictures";
    homepage = "https://github.com/Multicorewareinc/x265";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}

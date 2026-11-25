{
  tvp,
  lib,
  base,
  src,
  version,
  libpng,
  libtiff,
  lcms2,
  zlib,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  cmake = "${tools.cmake}/bin/cmake";
  libraries = [
    final.libpng
    final.libtiff
    final.lcms2
    final.zlib
  ];
  prefixPath = lib.concatStringsSep ";" (map toString libraries);
  paths = [
    "bin"
    "lib"
  ];
in
{
  pname = "openjpeg";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    libpng
    libtiff
    lcms2
    zlib
    ;
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      tools.cmake
      tools.ninja
      tools.pkg-config
    ];
    inherit libraries;
  };
  runtime.libraries = libraries;
  plan = [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.command
      {
        environment.tools = [
          tools.grep
          tools.sed
        ];
      }
      "openjpeg.cli-scalar-math"
      ''
        # The CLI's color-conversion loops use exp(). The selected libc does not
        # expose the vector libm ABI emitted for these loops under fast-math.
        test "$(grep -Ec '^[[:space:]]*set\(OPENJP2_COMPILE_OPTIONS .*:-ffast-math>' CMakeLists.txt)" -eq 1
        sed -i '/^[[:space:]]*set(OPENJP2_COMPILE_OPTIONS /s/ "\$<\$<CONFIG:Release>:-ffast-math>"//' CMakeLists.txt
      ''
    )
    (command "openjpeg.configure" ''
      ${cmake} -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$out" -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_MAKE_PROGRAM=${tools.ninja}/bin/ninja -DCMAKE_PREFIX_PATH=${lib.escapeShellArg prefixPath} \
        -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=ON -DBUILD_CODEC=ON -DBUILD_THIRDPARTY=OFF
    '')
    (command "openjpeg.build" ''${cmake} --build build --parallel "$NIX_BUILD_CORES"'')
    (command "openjpeg.install" ''
      ${cmake} --install build
      install -Dm644 LICENSE "$out/share/licenses/openjpeg/LICENSE"
      test -x "$out/bin/opj_compress"
      test -x "$out/bin/opj_decompress"
      test -f "$out/lib/pkgconfig/libopenjp2.pc"
    '')
    (steps.split "openjpeg.finalize")
    (outputs.copyArtifacts { })
    {
      name = "openjpeg.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (outputs.strip {
      inherit paths;
      elfKinds = [ "runtime" ];
    })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
      elfKinds = [ "runtime" ];
    })
    (outputs.checkPaths {
      inherit paths;
      elfKinds = [ "runtime" ];
    })
  ];
  meta = {
    description = "JPEG 2000 library and codec utilities";
    homepage = "https://www.openjpeg.org/";
    license = lib.licenses.bsd2;
  };
}

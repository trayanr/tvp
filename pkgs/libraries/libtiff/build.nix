{
  tvp,
  lib,
  base,
  src,
  version,
  jpeg,
  zlib,
  zstd,
  xz,
  libwebp,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  cmake = "${tools.cmake}/bin/cmake";
  libraries = [ final.jpeg final.zlib final.zstd final.xz final.libwebp ];
  prefixPath = lib.concatStringsSep ";" (map toString libraries);
  paths = [ "bin" "lib" ];
in
{
  pname = "libtiff";
  artifactName = "${final.pname}-${final.version}";
  inherit base src version jpeg zlib zstd xz libwebp;
  inherit (tools) bash coreutils;
  environment = {
    tools = [ tools.cmake tools.ninja tools.pkg-config ];
    inherit libraries;
  };
  runtime.libraries = libraries;
  plan = [
    (steps.unpack { src = final.src; compression = "gzip"; })
    (command "libtiff.configure" ''
      ${cmake} -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$out" -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_MAKE_PROGRAM=${tools.ninja}/bin/ninja -DCMAKE_PREFIX_PATH=${lib.escapeShellArg prefixPath} \
        -Dtiff-tests=OFF -Dtiff-docs=OFF
    '')
    (command "libtiff.build" ''${cmake} --build build --parallel "$NIX_BUILD_CORES"'')
    (command "libtiff.install" ''
      ${cmake} --install build
      install -Dm644 LICENSE.md "$out/share/licenses/libtiff/LICENSE.md"
      test -x "$out/bin/tiffinfo"
      test -f "$out/lib/pkgconfig/libtiff-4.pc"
    '')
    (steps.split "libtiff.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libtiff.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (outputs.strip { inherit paths; })
    (outputs.rpaths { inherit paths; libraries = final.runtime.libraries; })
    (outputs.development { libraries = final.runtime.libraries; })
    (outputs.checkPaths { inherit paths; })
  ];
  meta = {
    description = "TIFF image library and command-line tools";
    homepage = "https://libtiff.gitlab.io/libtiff/";
    license = lib.licenses.libtiff;
  };
}

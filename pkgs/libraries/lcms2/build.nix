{
  tvp,
  lib,
  base,
  src,
  version,
  jpeg,
  libtiff,
  zlib,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  paths = [ "bin" "lib" ];
  libraries = [ final.jpeg final.libtiff final.zlib ];
in
{
  pname = "lcms2";
  artifactName = "${final.pname}-${final.version}";
  inherit base src version jpeg libtiff zlib;
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      tools.gnumake tools.gawk tools.grep tools.sed tools.diffutils tools.findutils
    ];
    inherit libraries;
  };
  runtime.libraries = libraries;
  plan = [
    (steps.unpack { src = final.src; compression = "gzip"; })
    (steps.prepareAutotools { name = "lcms2.prepare"; })
    (command "lcms2.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      "$CONFIG_SHELL" ./configure --prefix="$out" --libdir="$out/lib" --enable-shared --enable-static \
        --with-jpeg=${final.jpeg} --with-tiff=${final.libtiff} --with-zlib
    '')
    (command "lcms2.build" make)
    (command "lcms2.install" ''
      ${make} install
      install -Dm644 LICENSE "$out/share/licenses/lcms2/LICENSE"
      test -x "$out/bin/jpgicc"
      test -x "$out/bin/tificc"
      test -f "$out/lib/pkgconfig/lcms2.pc"
    '')
    (steps.split "lcms2.finalize")
    (outputs.copyArtifacts { })
    {
      name = "lcms2.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (outputs.strip { inherit paths; elfKinds = [ "runtime" ]; })
    (outputs.rpaths { inherit paths; libraries = final.runtime.libraries; elfKinds = [ "runtime" ]; })
    (outputs.checkPaths { inherit paths; elfKinds = [ "runtime" ]; })
  ];
  meta = {
    description = "Little CMS color management engine and profile utilities";
    homepage = "https://www.littlecms.com/";
    license = lib.licenses.mit;
  };
}

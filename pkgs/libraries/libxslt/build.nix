{
  tvp,
  lib,
  base,
  src,
  version,
  libxml2,
  patches ? [ ],
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  paths = [
    "bin"
    "lib"
  ];
in
{
  pname = "libxslt";
  inherit
    base
    src
    version
    libxml2
    patches
    ;
  inherit (tools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  environment = {
    tools = [
      tools.gnumake
      tools.pkg-config
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ final.libxml2 ];
  };
  runtime = {
    libraries = [ final.libxml2 ];
    shell = tools.bash;
  };
  installedInterface.pkgconfig = true;
  plan = steps.sequence [
    (steps.unpack { src = final.src; })
    (lib.optional (final.patches != [ ]) (
      steps.command { environment.tools = [ tools.patch ]; } "libxslt.patch" ''
        for patch in ${lib.escapeShellArgs (map (file: "${file}") final.patches)}; do
          ${tools.patch}/bin/patch --batch --fuzz=0 -p1 < "$patch"
        done
      ''
    ))
    (steps.prepareAutotools { name = "libxslt.prepare"; })
    (command "libxslt.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --without-python --without-crypto --disable-static
    '')
    (command "libxslt.build" make)
    (command "libxslt.install" ''
      ${make} install
      test -x "$out/bin/xsltproc"
      test -f "$out/include/libxslt/xslt.h"
      test -f "$out/lib/pkgconfig/libxslt.pc"
    '')
    (steps.split "libxslt.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libxslt.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (outputs.shebangs {
      paths = [ "bin/xslt-config" ];
      names = [ "sh" ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.strip { inherit paths; })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = [ final.libxml2 ]; })
    (outputs.checkPaths { inherit paths; })
  ];
  meta = {
    description = "XSLT processor and libraries based on libxml2";
    homepage = "https://gitlab.gnome.org/GNOME/libxslt";
    license = lib.licenses.mit;
    mainProgram = "xsltproc";
    platforms = [ "x86_64-linux" ];
  };
}

{
  tvp,
  lib,
  base,
  src,
  version,
  libxml2,
  gnu-config ? null,
  compression,
  configureOptions ? [ ],
  license ? lib.licenses.mit,
  pkgconfig ? true,
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
    gnu-config
    compression
    configureOptions
    license
    ;
  inherit (tools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  environment = {
    tools = [
      tools.gnumake
      final.libxml2
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ final.libxml2 ];
    overrides.values.CFLAGS = "-O2 -std=gnu17 -fcommon";
  };
  runtime = {
    libraries = [ final.libxml2 ];
    shell = tools.bash;
  };
  installedInterface = { inherit pkgconfig; };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = final.compression;
    })
    (lib.optional (final.gnu-config != null) {
      name = "libxslt.gnu-config";
      cwd = "source";
      run = ''
        cp ${final.gnu-config}/config.guess ${final.gnu-config}/config.sub .
        chmod u+w config.guess config.sub
      '';
    })
    (steps.prepareAutotools { name = "libxslt.prepare"; })
    (command "libxslt.xml2-config-probe" ''
      # Newer xml2-config rejects the historical stray "print" argument.
      test "$(grep -c -- '--libs print' configure)" -eq 1
      sed -i 's/--libs print/--libs/g' configure
    '')
    (command "libxslt.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --with-libxml-prefix=${final.libxml2} --disable-static \
        ${lib.escapeShellArgs final.configureOptions}
    '')
    (command "libxslt.build" make)
    (command "libxslt.install" ''
      ${make} install
      test -x "$out/bin/xsltproc"
      test -f "$out/include/libxslt/xslt.h"
      ${lib.optionalString final.installedInterface.pkgconfig ''test -f "$out/lib/pkgconfig/libxslt.pc"''}
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
    inherit (final) license;
    mainProgram = "xsltproc";
    platforms = [ "x86_64-linux" ];
  };
}

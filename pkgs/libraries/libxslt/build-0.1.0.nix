{
  tvp,
  lib,
  base,
  src,
  version,
  libxml2,
  gnu-config ? null,
  compression,
  legacyXslAttributes ? false,
  withBreakpoint ? false,
  withExslt ? false,
  patches ? [ ],
  license ? lib.licenses.mit,
  pkgconfig ? false,
  repairPkgconfigRequires ? false,
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
    legacyXslAttributes
    withBreakpoint
    withExslt
    patches
    license
    repairPkgconfigRequires
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
    # xml2-config --libs links the selected libxml2 compression providers directly.
    libraries = [ final.libxml2 ] ++ final.libxml2.specification.runtime.libraries;
    shell = tools.bash;
  };
  installedInterface = { inherit pkgconfig; };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = final.compression;
    })
    (lib.optional (final.patches != [ ]) (
      steps.command { environment.tools = [ tools.patch ]; } "libxslt.patch" ''
        for patch in ${lib.escapeShellArgs (map (file: "${file}") final.patches)}; do
          ${tools.patch}/bin/patch --batch --fuzz=0 -p1 < "$patch"
        done
      ''
    ))
    (lib.optional final.legacyXslAttributes (
      command "libxslt.legacy-xsl-attributes" ''
        found=0
        for source in libxslt/*.c; do
          if grep -Fq 'xmlGetNsProp(' "$source"; then
            test "$(grep -Fxc '#include "xsltutils.h"' "$source")" -eq 1
            sed -i \
              -e 's/\<xmlGetNsProp\>/tvpXsltGetNsProp/g' \
              -e '/^#include "xsltutils.h"$/a #include "${./ordinary/legacy-xsl-attributes.h}"' \
              "$source"
            found=1
          fi
        done
        test "$found" -eq 1
      ''
    ))
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
    (lib.optional (lib.versionOlder final.version "1.0.23") (
      command "libxslt.type-compiler-probe" ''
        # The shipped Autoconf probes relied on pre-C99 implicit int.
        test "$(grep -Fxc 'main(){return(0);}' configure)" -ge 1
        sed -i 's/^main(){return(0);}$/int main(void){return(0);}/' configure
      ''
    ))
    (command "libxslt.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --with-libxml-prefix=${final.libxml2} --disable-static
    '')
    # These release makefiles couple the recursive target to upstream tests
    # and documentation generation. Build the shipped production targets.
    (command "libxslt.build" (
      lib.optionalString final.withBreakpoint ''
        ${make} -C breakpoint all
      ''
      + ''
        ${make} -C libxslt libxslt.la
        ${make} -C libxslt all
        ${lib.optionalString final.withExslt ''
          ${make} -C libexslt all
          ${make} -C xsltproc all
        ''}
      ''
    ))
    (command "libxslt.install" (
      lib.optionalString final.withBreakpoint ''
        ${make} -C breakpoint install
      ''
      + ''
        ${make} -C libxslt install
        ${lib.optionalString final.withExslt ''
          ${make} -C libexslt install
          ${make} -C xsltproc install
        ''}
        ${make} install-am
        test -x "$out/bin/xsltproc"
        test -f "$out/include/libxslt/xslt.h"
      ''
      + lib.optionalString final.installedInterface.pkgconfig ''
        test -f "$out/lib/pkgconfig/libxslt.pc"
      ''
    ))
    (steps.split "libxslt.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libxslt.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (lib.optional final.repairPkgconfigRequires {
      name = "libxslt.pkgconfig-requires";
      tools = [
        tools.grep
        tools.sed
      ];
      run = ''
        pc="$out/lib/pkgconfig/libxslt.pc"
        test "$(grep -Fxc 'Requires:' "$pc")" -eq 1
        sed -i 's/^Requires:$/Requires: libxml-2.0/' "$pc"
      '';
    })
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

{
  tvp,
  lib,
  base,
  src,
  version,
  needsLocaleHeader ? false,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  cwd = final.sourceLayout.configureDirectory;
  command = steps.command {
    inherit cwd;
    environment = final.environment;
  };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  elfPaths = [
    "bin"
    "lib"
    "sbin"
  ];
in
{
  pname = "icu";
  inherit base src version;
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ ];
  };
  buildFeatures = { inherit needsLocaleHeader; };
  sourceLayout.configureDirectory = "source/source";
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "icu.prepare-configure";
      inherit cwd;
    })
    (command "icu.configure" ''
      ${lib.optionalString final.buildFeatures.needsLocaleHeader ''
        # glibc 2.26 removed xlocale.h. Keep the strtod_l support.
        test "$(grep -c '^# *include <xlocale\.h>$' i18n/digitlst.cpp)" = 1
        sed -i 's|^\(# *include \)<xlocale\.h>$|\1<locale.h>|' i18n/digitlst.cpp
      ''}
      # The shipped echo-character probe explicitly calls /bin/sh.
      sed -i 's|/bin/sh -c|${tools.bash}/bin/bash -c|g' configure
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      # Use the GNU99 and C++11 dialects selected by historical ICU configure scripts.
      export CFLAGS="''${CFLAGS:--O2} -std=gnu99"
      export CXXFLAGS="''${CXXFLAGS:--O2} -std=c++11"
      ./configure --prefix="$out" --libdir="$out/lib" --enable-shared --disable-static \
        --with-data-packaging=library --enable-rpath --disable-tests --disable-samples
    '')
    (command "icu.build" "${make} all")
    (command "icu.install" "${make} install")
    (steps.split "icu.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText {
      paths = [
        "bin/icu-config"
        "lib/icu/${final.version}"
        "lib/pkgconfig"
        "share/man"
      ];
    })
    (outputs.shebangs {
      paths = [
        "bin/icu-config"
        "share/icu/${final.version}"
      ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    {
      name = "icu.bind-script-tools";
      tools = [ tools.sed ];
      run = ''
        for script in "$out/bin/icu-config" "$out/share/icu/${final.version}/"{install-sh,mkinstalldirs}; do
          sed -i '2i export PATH=${tools.coreutils}/bin:${tools.sed}/bin:$PATH' "$script"
        done
      '';
    }
    # Before 56, libicuuc embeds the default plug-in directory.
    (lib.optional (lib.versionOlder final.version "56") {
      name = "icu.relocate-plugin-directory";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./relocate-plugin-directory.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    })
    (outputs.strip { paths = elfPaths; })
    (outputs.rpaths {
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = [ ]; })
    (outputs.checkPaths { paths = elfPaths; })
  ];
  meta = {
    description = "Unicode and globalization libraries and tools for C and C++";
    homepage = "https://icu.unicode.org/";
    license = if lib.versionOlder version "58" then lib.licenses.icu else lib.licenses.unicode-dfs-2016;
    platforms = [ "x86_64-linux" ];
  };
}

{
  tvp,
  lib,
  base,
  src,
  version,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  cwd = "source/source";
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
      tools.python
    ];
    libraries = [ ];
  };
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
      # The shipped echo-character probe explicitly calls /bin/sh.
      sed -i 's|/bin/sh -c|${tools.bash}/bin/bash -c|g' configure
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      export PYTHON=${tools.python}/bin/python3
      export CXXFLAGS="''${CXXFLAGS:--O2} -std=c++17"
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
    license = lib.licenses.unicode-30;
    platforms = [ "x86_64-linux" ];
  };
}

# Autotools releases. The first archive ships configure inputs only.
{
  tvp,
  lib,
  base,
  src,
  version,
  autoconf ? null,
  automake ? null,
  libtool ? null,
  pkgconfig ? true,
  cliVersion ? false,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  regenerate = final.autoconf != null;
  make = ''
    ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash
  '';
in
{
  pname = "numactl";
  inherit
    base
    src
    version
    autoconf
    automake
    libtool
    pkgconfig
    cliVersion
    ;
  inherit (tools) bash coreutils;
  installedInterface = {
    inherit (final) pkgconfig cliVersion;
    static = true;
  };
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ]
    ++ lib.optionals regenerate [
      final.autoconf
      final.automake
      final.libtool
    ];
    overrides.flags.NIX_CFLAGS_COMPILE = [ "-std=gnu17" ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (lib.optional regenerate (
      command "numactl.autoreconf" ''
        test ! -e configure
        export CONFIG_SHELL=${tools.bash}/bin/bash
        export ACLOCAL_PATH=${final.libtool}/share/aclocal
        ${final.autoconf}/bin/autoreconf --install --force
      ''
    ))
    (steps.prepareAutotools { name = "numactl.prepare"; })
    (command "numactl.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" --enable-shared --enable-static
    '')
    (command "numactl.build" make)
    (command "numactl.install" "${make} install")
    (steps.split "numactl.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText {
      paths = [
        "lib/libnuma.la"
      ]
      ++ lib.optional final.installedInterface.pkgconfig "lib/pkgconfig/numa.pc";
    })
    (outputs.libtool { paths = [ "lib/libnuma.la" ]; })
    (outputs.strip {
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.stripArchives { paths = [ "lib/libnuma.a" ]; })
    (outputs.rpaths {
      paths = [
        "bin"
        "lib"
      ];
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = [ ]; })
    (outputs.checkPaths {
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  meta = {
    description = "Linux NUMA policy tools and library";
    homepage = "https://github.com/numactl/numactl";
    license = [
      lib.licenses.gpl2Only
      lib.licenses.lgpl21Only
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "numactl";
  };
}

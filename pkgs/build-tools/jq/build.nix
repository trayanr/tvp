{
  tvp,
  lib,
  base,
  src,
  version,
  oniguruma,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  configureFlags = [
    "--enable-shared"
    "--disable-static"
    "--disable-docs"
    "--with-oniguruma=${final.oniguruma}"
  ];
in
{
  pname = "jq";
  inherit
    base
    src
    version
    oniguruma
    ;
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
    libraries = [ final.oniguruma ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools { name = "jq.prepare"; })
    (steps.shebangs {
      name = "jq.version-script";
      paths = [ "scripts/version" ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "jq.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" ${lib.escapeShellArgs configureFlags}
      if ! grep -Eq '^DEFS = (.* )?-DHAVE_LIBONIG=1( |$)' Makefile ||
         grep -Fxq 'SUBDIRS = vendor/oniguruma' Makefile; then
        echo "jq: configure must select the declared Oniguruma provider" >&2
        exit 1
      fi
      # Keep jq --build-configuration informative without embedding the artifact prefix.
      printf '#define JQ_CONFIG "%s"\n' ${lib.escapeShellArg (lib.concatStringsSep " " configureFlags)} > src/config_opts.inc
    '')
    (command "jq.build" make)
    (command "jq.install" ''
      ${make} install
      install -Dm644 COPYING "$out/share/licenses/jq/COPYING"
    '')
    (steps.split "jq.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText {
      paths = [
        "lib/libjq.la"
        "lib/pkgconfig/libjq.pc"
      ];
    })
    (outputs.libtool { paths = [ "lib/libjq.la" ]; })
    (outputs.strip {
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.rpaths {
      paths = [
        "bin"
        "lib"
      ];
      libraries = final.runtime.libraries;
    })
    (outputs.checkSymlinks {
      paths = [
        "lib/libjq.so"
        "lib/libjq.so.1"
      ];
    })
    (outputs.checkPaths {
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  meta = {
    description = "Command-line JSON processor";
    homepage = "https://jqlang.org/";
    license = lib.licenses.mit;
    mainProgram = "jq";
  };
}

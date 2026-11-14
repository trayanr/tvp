# Complete ISL 0.20 procedure; release facts stay with this source/interface era.
{
  tvp,
  lib,
  base,
  src,
  version,
  gmp,
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      name = "isl.${name}";
      cwd = "source";
      inherit run;
    };
  checkpoint = "nix-support/isl-build-tree";
in
{
  pname = "isl";
  inherit
    base
    src
    version
    gmp
    doCheck
    ;
  inherit (tools) bash coreutils;
  installedInterface = {
    sonameMajor = "19";
    cppBindings = false;
  };
  configureFlags = [
    "--without-gcc-arch"
    "--with-gmp=system"
    "--with-gmp-prefix=${lib.getDev final.gmp}"
    "--enable-shared"
    "--enable-static"
  ];
  environment = {
    tools = [
      tools.gnumake
      tools.findutils
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.gnutar
      tools.gzip
    ];
    libraries = [ final.gmp ];
    overrides.values.CFLAGS = "-O2 -std=gnu17";
  };
  runtime = {
    libraries = [ final.gmp ];
    dlopenDirectories = [ ];
  };
  productionPlan = steps.sequence [
    (steps.unpack { src = final.src; })
    (
      (command "validate-source" ''
        ${tools.python}/bin/python3 -B ${./validate-source.py} "$PWD" '{}' validate-source
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
    (steps.prepareAutotools { name = "isl.prepare"; })
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'')
    (command "install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash install
      mkdir -p "$out/share/licenses/isl"
      cp LICENSE "$out/share/licenses/isl/"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    {
      name = "isl.restore-build-tree";
      tools = [ tools.python ];
      run = ''
        ${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"
      '';
    }
  ];
  upstreamCheck =
    (command "check" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash check || {
        status=$?
        if test -f test-suite.log; then cat test-suite.log >&2; fi
        exit "$status"
      }
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "isl.finalize")
    (outputs.copyArtifacts { })
    {
      name = "isl.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    (outputs.relocateText {
      paths = [
        "lib/pkgconfig/isl.pc"
        "lib/libisl.la"
      ];
    })
    (outputs.libtool { paths = [ "lib/libisl.la" ]; })
    (outputs.strip { paths = [ "lib" ]; })
    (outputs.stripArchives { paths = [ "lib" ]; })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "lib" ];
    })
    (outputs.development { libraries = [ final.gmp ]; })
    (outputs.checkSymlinks {
      paths = [
        "lib/libisl.so"
        "lib/libisl.so.${final.installedInterface.sonameMajor}"
      ];
    })
    (outputs.checkPaths { paths = [ "lib" ]; })
  ];
  tvp.features = {
    doCheck = final.doCheck;
    shared = true;
    static = true;
    cxx = final.installedInterface.cppBindings;
  };
  meta = {
    description = "Integer sets and relations library for polyhedral compilation";
    license = lib.licenses.mit;
  };
}

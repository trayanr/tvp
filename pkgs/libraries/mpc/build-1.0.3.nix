# Complete MPC 1.0.3 procedure; sources and dependencies are selected in default.nix.
{
  tvp,
  lib,
  base,
  src,
  version,
  gmp,
  mpfr,
  additionalSourceScripts ? [ ],
  stripFlags ? [
    "-S"
    "-p"
  ],
  dlopenDirectories ? [ ],
  checkCFlags ? [ ],
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
      inherit name run;
      cwd = "source";
    };
  elfPaths = [ "lib" ];
  checkpoint = "nix-support/mpc-build-tree";
in
{
  pname = "mpc";
  inherit
    base
    src
    version
    gmp
    mpfr
    stripFlags
    dlopenDirectories
    checkCFlags
    doCheck
    ;
  inherit additionalSourceScripts;
  inherit (tools) bash coreutils;
  sourceLayout = {
    compression = "gzip";
    scripts = [
      "configure"
      "config.guess"
      "config.sub"
      "install-sh"
      "ltmain.sh"
      "missing"
      "depcomp"
      "test-driver"
    ] ++ final.additionalSourceScripts;
  };
  installedInterface = {
    hasPkgConfig = false;
    sonameMajor = "3";
  };
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [
      final.gmp
      final.mpfr
    ];
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = final.sourceLayout.compression;
    })
    (steps.prepareAutotools { name = "mpc.prepare"; })
    (steps.shebangs {
      name = "mpc.source-shells";
      paths = final.sourceLayout.scripts;
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "mpc.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --disable-static --disable-dependency-tracking \
        --with-gmp=${lib.getDev final.gmp} --with-mpfr=${lib.getDev final.mpfr}
    '')
    (command "mpc.build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "mpc.install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "mpc.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    {
      name = "mpc.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }
  ];
  upstreamCheck =
    (command "mpc.check" ''
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE ${lib.concatStringsSep " " final.checkCFlags}"
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "mpc.finalize")
    (outputs.copyArtifacts { })
    {
      name = "mpc.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    (outputs.relocateText {
      paths = [
        "lib/libmpc.la"
      ] ++ lib.optional final.installedInterface.hasPkgConfig "lib/pkgconfig/mpc.pc";
    })
    (outputs.strip {
      paths = elfPaths;
      flags = final.stripFlags;
    })
    (outputs.libtool { paths = [ "lib/libmpc.la" ]; })
    (outputs.rpaths {
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      libraries = final.runtime.libraries;
      paths = elfPaths;
    })
    (outputs.development {
      libraries = [
        final.gmp
        final.mpfr
      ];
    })
    (outputs.checkSymlinks {
      paths = [
        "lib/libmpc.so"
        "lib/libmpc.so.${final.installedInterface.sonameMajor}"
      ];
    })
    (outputs.checkPaths { paths = elfPaths; })
  ];
  runtime = {
    libraries = [
      final.gmp
      final.mpfr
    ];
    dlopenDirectories = final.dlopenDirectories;
  };
  tvp.features = {
    shared = true;
    static = false;
  };
  meta = {
    description = "Multiple-precision complex arithmetic library";
    license = lib.licenses.lgpl3Plus;
  };
}

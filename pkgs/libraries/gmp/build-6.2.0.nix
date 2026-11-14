# Complete GMP 6.2.0 procedure; release-specific exceptions stay in default.nix.
{
  tvp,
  lib,
  base,
  src,
  version,
  m4,
  cStandard ? "gnu17",
  configureCFlags ? [ ],
  checkCFlags ? [ ],
  cxx ? true,
  reportedVersion ? version,
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
  checkpoint = "nix-support/gmp-build-tree";
  elfPaths = [ "lib" ];
in
{
  pname = "gmp";
  inherit
    base
    src
    version
    m4
    cStandard
    configureCFlags
    checkCFlags
    cxx
    reportedVersion
    doCheck
    ;
  buildFeatures = {
    cxx = final.cxx;
    assembly = true;
  };
  sourceLayout.scripts = [
    "configure"
    "configfsf.guess"
    "configfsf.sub"
    "config.guess"
    "config.sub"
    "install-sh"
    "ltmain.sh"
    "missing"
    "test-driver"
    "compile"
    "mpn/x86/t-zdisp.sh"
  ];
  installedInterface = {
    hasPkgConfig = true;
    gmpSonameMajor = "10";
    gmpxxSonameMajor = "4";
  };
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      tools.gnumake
      final.m4
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    overrides.values = {
      M4 = "${final.m4}/bin/m4";
      # GMP's configure probes predate GCC's default C23 semantics.
      CFLAGS = "-O2 -std=${final.cStandard}";
    };
  };
  productionPlan = steps.sequence [
    (steps.unpack { src = final.src; })
    (steps.prepareAutotools { name = "gmp.prepare"; })
    (steps.shebangs {
      name = "gmp.source-shells";
      paths = final.sourceLayout.scripts;
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "gmp.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE ${lib.concatStringsSep " " final.configureCFlags}"
      ./configure --prefix="$out" --build=${final.base.platform.config} --host=${final.base.platform.config} \
        ${lib.enableFeature final.buildFeatures.cxx "cxx"} \
        --enable-shared --enable-static \
        ${lib.enableFeature final.buildFeatures.assembly "assembly"} \
        --with-pic --disable-dependency-tracking
    '')
    (command "gmp.build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "gmp.install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "gmp.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    {
      name = "gmp.restore-build-tree";
      tools = [ tools.python ];
      run = ''
        ${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"
      '';
    }
  ];
  upstreamCheck =
    (command "gmp.check" ''
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE ${lib.concatStringsSep " " final.checkCFlags}"
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "gmp.finalize")
    (outputs.copyArtifacts { })
    {
      name = "gmp.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    (outputs.relocateText {
      paths =
        [ "lib/libgmp.la" ]
        ++ lib.optional final.buildFeatures.cxx "lib/libgmpxx.la"
        ++ lib.optional final.installedInterface.hasPkgConfig "lib/pkgconfig";
    })
    (outputs.strip { paths = elfPaths; })
    (outputs.stripArchives { paths = [ "lib" ]; })
    (outputs.libtool {
      paths = [ "lib/libgmp.la" ] ++ lib.optional final.buildFeatures.cxx "lib/libgmpxx.la";
    })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = elfPaths;
    })
    (outputs.development { libraries = [ ]; })
    (outputs.checkSymlinks {
      paths = (
        [
          "lib/libgmp.so"
          "lib/libgmp.so.${final.installedInterface.gmpSonameMajor}"
        ]
        ++ lib.optionals final.buildFeatures.cxx [
          "lib/libgmpxx.so"
          "lib/libgmpxx.so.${final.installedInterface.gmpxxSonameMajor}"
        ]
      );
    })
    (outputs.checkPaths { paths = elfPaths; })
  ];
  runtime = {
    libraries = [ ];
    dlopenDirectories = [ ];
  };
  tvp.reportedVersion = final.reportedVersion;
  tvp.features = final.buildFeatures // {
    shared = true;
    static = true;
  };
  meta = {
    description = "GNU multiple precision arithmetic with native assembly and C++";
    license = lib.licenses.lgpl3Plus;
  };
}

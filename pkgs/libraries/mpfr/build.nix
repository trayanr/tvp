# One owned MPFR procedure. Compatibility choices live in the definition table.
{
  tvp,
  lib,
  base,
  src,
  version,
  gmp,
  checkCFlags ? [ ],
  float128 ? true,
  mpfrRoundingNames ? true,
  hasPkgConfig ? true,
  sonameMajor ? "6",
  sourceScripts ? [
    "configure"
    "config.guess"
    "config.sub"
    "install-sh"
    "ltmain.sh"
    "missing"
    "depcomp"
    "test-driver"
  ],
  stripFlags ? [
    "-S"
    "-p"
  ],
  dlopenDirectories ? [ ],
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
  checkpoint = "nix-support/mpfr-build-tree";
in
{
  pname = "mpfr";
  inherit
    base
    src
    version
    gmp
    checkCFlags
    float128
    mpfrRoundingNames
    hasPkgConfig
    sonameMajor
    sourceScripts
    stripFlags
    dlopenDirectories
    doCheck
    ;
  # The runner and test factory use the effective base's canonical providers.
  inherit (tools) bash coreutils;
  toolProviders = context.selectTools [
    "bash"
    "coreutils"
    "binutils"
    "gnumake"
    "gnutar"
    "xz"
    "python"
    "patchelf"
    "sed"
    "grep"
    "gawk"
    "diffutils"
    "findutils"
  ];
  environment = {
    tools = map (name: tools.${name}) [
      "gnumake"
      "sed"
      "grep"
      "gawk"
      "diffutils"
      "findutils"
    ];
    libraries = [ final.gmp ];
  };
  productionPlan = steps.sequence [
    (steps.unpack { src = final.src; })
    (steps.prepareAutotools { name = "mpfr.prepare"; })
    (steps.shebangs {
      name = "mpfr.source-shells";
      paths = final.sourceScripts;
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "mpfr.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --disable-static --disable-dependency-tracking ${
        lib.optionalString (!final.float128) "--disable-float128"
      } --with-gmp=${lib.getDev final.gmp}
    '')
    (command "mpfr.build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "mpfr.install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "mpfr.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  # Restoring the immutable compiled tree is separate from A/F and test policy.
  upstreamPlan = artifact: [
    {
      name = "mpfr.restore-build-tree";
      tools = [ tools.python ];
      run = ''
        ${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"
      '';
    }
  ];
  upstreamCheck =
    (command "mpfr.check" ''
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE ${lib.concatStringsSep " " final.checkCFlags}"
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "mpfr.finalize")
    (outputs.copyArtifacts { })
    {
      name = "mpfr.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    (outputs.relocateText {
      paths = [ "lib/libmpfr.la" ] ++ lib.optional final.hasPkgConfig "lib/pkgconfig/mpfr.pc";
    })
    (outputs.strip {
      paths = elfPaths;
      flags = final.stripFlags;
    })
    (outputs.libtool { paths = [ "lib/libmpfr.la" ]; })
    (outputs.rpaths {
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      libraries = final.runtime.libraries;
      paths = elfPaths;
    })
    (outputs.development { libraries = [ final.gmp ]; })
    (outputs.checkSymlinks {
      paths = [
        "lib/libmpfr.so"
        "lib/libmpfr.so.${final.sonameMajor}"
      ];
    })
    (outputs.checkPaths { paths = elfPaths; })
  ];
  runtime = {
    libraries = [ final.gmp ];
    dlopenDirectories = final.dlopenDirectories;
  };
  tvp.features = {
    float128 = final.float128;
    mpfrRoundingNames = final.mpfrRoundingNames;
  };
  meta = {
    description = "Correctly rounded multiple-precision floating-point arithmetic";
    license = lib.licenses.lgpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}

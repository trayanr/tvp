{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  steps = import ../build-steps.nix;
  p = tvp.variants.build-steps.mpfr_4_2_2;
  names = map (s: s.name) p.buildSteps;
  outputNames = [
    "output.strip"
    "output.libtool"
    "output.rpaths"
    "output.development"
    "output.check-symlinks"
    "output.check-paths"
  ];
  tools = {
    binutils = tvp.packages.binutils_2;
    patchelf = tvp.packages.patchelf_0;
    python = tvp.packages.python_3;
  };
  # Different tool outputs expose accidental hardcoding, without building them.
  rebound = p.override {
    binutils = tools.binutils // {
      outPath = "/selected/binutils";
    };
    patchelf = tools.patchelf // {
      outPath = "/selected/patchelf";
    };
    python = tools.python // {
      outPath = "/selected/python";
    };
    stripFlags = [
      "--strip-debug"
      "--preserve-dates"
    ];
  };
  text = lib.concatStrings (map (s: s.run or "") rebound.buildSteps);
  edited = (p.editSteps (steps.delete "output.libtool")).editSteps (
    steps.replace "output.strip" (
      old:
      old
      // {
        enabled = false;
        run = throw "disabled output body";
        tools = throw "disabled output tools";
      }
    )
  );
  inserted = p.editSteps (
    steps.insertAfter "output.rpaths" [
      {
        name = "local.between";
        run = ":";
      }
    ]
  );
  contracts = {
    ordinaryOrder = lib.drop 9 names == outputNames;
    actualArguments = builtins.all (s: lib.hasInfix s text) [
      "/selected/binutils/bin/strip"
      "/selected/binutils/bin/readelf"
      "/selected/patchelf/bin/patchelf"
      "/selected/python/bin/python3"
      "--strip-debug"
    ];
    declarationRebound =
      rebound.tvp.declaredDependencies.binutils.outPath == "/selected/binutils"
      && rebound.tvp.declaredDependencies.python.outPath == "/selected/python"
      && rebound.tvp.declaredDependencies.patchelf.outPath == "/selected/patchelf";
    testsRebound =
      rebound.tests.arithmetic.drvPath != p.tests.arithmetic.drvPath
      && builtins.any (v: v.outPath == rebound.outPath) rebound.tests.arithmetic.nativeBuildInputs;
    independentDeletion =
      builtins.length (
        steps.active (
          (steps.partition edited.buildSteps).first ++ (steps.partition edited.buildSteps).second
        )
      ) == builtins.length p.buildSteps - 3
      && builtins.isString edited.drvPath;
    independentInsertion = lib.elemAt (map (s: s.name) inserted.buildSteps) 12 == "local.between";
  };
  failed = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
in
assert failed == [ ] || throw "Native output contracts: ${lib.concatStringsSep ", " failed}";
tvp.bases.default.stdenv.mkDerivation {
  name = "tvp-native-output-contracts";
  nativeBuildInputs = [
    tools.python
    tools.binutils
    tools.patchelf
  ];
  buildCommand = ''
    ${tools.python}/bin/python3 -B ${./native-output.py} ${../native-output} ${tools.binutils} ${tools.patchelf} "$CC" ${tvp.packages.gmp_6} ${tvp.packages.zlib_1}
    printf '%s\n' '${builtins.toJSON contracts}' > "$out"
  '';
}

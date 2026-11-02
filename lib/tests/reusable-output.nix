{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  output = import ../native-output-steps.nix { inherit lib; };
  python = tvp.packages.python_3;
  binutils = tvp.packages.binutils_2;
  bash = tvp.packages.bash;
  selected = output.stripArchives {
    inherit python;
    binutils = binutils // {
      outPath = "/selected/binutils";
    };
    paths = [ "lib" ];
  };
  script = output.shebangs {
    inherit python;
    paths = [ "bin" ];
    names = [ "bash" ];
    interpreter = "${bash}/bin/bash";
  };
  own = output.shebangs {
    inherit python;
    paths = [ "bin" ];
    names = [ "python3" ];
    selfInterpreter = "bin/python3";
  };
  contracts = {
    ordinaryNames = selected.name == "output.strip-archives" && script.name == "output.shebangs";
    selectedArchiveTools = builtins.all (s: lib.hasInfix s selected.run) [
      "/selected/binutils/bin/strip"
      "/selected/binutils/bin/ranlib"
      "/selected/binutils/bin/readelf"
    ];
    explicitExternal = lib.hasInfix (builtins.unsafeDiscardStringContext "${bash}/bin/bash") script.run;
    runtimeContext = builtins.hasAttr (builtins.unsafeDiscardStringContext bash.drvPath) (
      builtins.getContext script.run
    );
    explicitSelf = lib.hasInfix "bin/python3" own.run;
    editable =
      (builtins.head (
        (import ../build-steps.nix).replace "output.shebangs" (old: old // { enabled = false; }) [ script ]
      )).enabled == false;
  };
  failed = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
in
assert failed == [ ] || throw "Reusable output contracts: ${lib.concatStringsSep ", " failed}";
tvp.bases.default.stdenv.mkDerivation {
  name = "tvp-reusable-output-contracts";
  nativeBuildInputs = [
    python
    binutils
    bash
  ];
  buildCommand = ''
    ${python}/bin/python3 -B ${./reusable-output.py} ${../output-tools} ${../native-output} ${binutils} ${bash}/bin/bash ${python}/bin/python3 "$CC"
    printf '%s\n' '${builtins.toJSON contracts}' > "$out"
  '';
}

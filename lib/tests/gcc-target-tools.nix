# Distinct construction/target providers catch bindings that configure flags alone miss.
{ lib }:
let
  buildTools = {
    CC = "/construction/bin/cc";
    CXX = "/construction/bin/c++";
    AR = "/construction/bin/ar";
    AS = "/construction/bin/as";
    LD = "/construction/bin/ld";
    NM = "/construction/bin/nm";
    RANLIB = "/construction/bin/ranlib";
    READELF = "/construction/bin/readelf";
  };
  targetTools = {
    AR = "ar";
    AS = "as";
    LD = "ld";
    NM = "nm";
    RANLIB = "ranlib";
    READELF = "readelf";
    OBJDUMP = "objdump";
  };
  inspect =
    version: path:
    let
      recipe = import path;
      args =
        builtins.mapAttrs (name: _: "/selected/${name}") (builtins.functionArgs recipe)
        // {
          inherit lib version;
          patches = [ ];
          binutils = "/target/binutils";
          base.environment = _: { env = buildTools; };
          tvp.builder = {
            steps.split = name: { inherit name; };
            outputs.interpreters = _: { name = "output.interpreters"; };
            outputs.checkPaths = _: { name = "output.check-paths"; };
          };
        }
        // lib.optionalAttrs ((builtins.functionArgs recipe) ? bootstrap) { bootstrap = true; };
      spec = recipe args spec;
      rebound = recipe (args // { binutils = "/replacement/binutils"; }) rebound;
      command = s: name: builtins.head (builtins.filter (step: step.name == "gcc.${name}") s.plan);
      targetBindings =
        s: provider:
        builtins.all
          (
            name:
            let
              c = command s name;
            in
            builtins.all (
              tool:
              lib.hasInfix "${tool}_FOR_TARGET=\"${provider}/bin/${targetTools.${tool}}\"" c.run
              || lib.hasInfix "${tool}_FOR_TARGET=${provider}/bin/${targetTools.${tool}}" c.run
            ) (builtins.attrNames targetTools)
          )
          [
            "configure"
            "bootstrap"
            "install"
          ];
    in
    {
      inherit version;
      contracts = {
        selectedTarget = targetBindings spec args.binutils;
        reboundTarget = targetBindings rebound "/replacement/binutils";
        constructionBindings =
          builtins.all
            (
              name:
              let
                c = command rebound name;
              in
              c.env == buildTools
              && lib.hasInfix ''CC_FOR_BUILD="$CC" CXX_FOR_BUILD="$CXX"'' c.run
              && lib.hasInfix ''AR_FOR_BUILD="$AR"'' c.run
              && lib.hasInfix ''RANLIB_FOR_BUILD="$RANLIB"'' c.run
            )
            [
              "configure"
              "bootstrap"
              "install"
            ];
        configureCoherence = builtins.all (flag: builtins.elem flag rebound.configureFlags) [
          "--with-as=/replacement/binutils/bin/as"
          "--with-ld=/replacement/binutils/bin/ld"
        ];
      };
    };
  versions = {
    gcc13 = inspect "13.3.0" ../../pkgs/compilers/gcc/native/build-13.3.0.nix;
    gcc16 = inspect "16.2.0" ../../pkgs/compilers/gcc/native/build-16.2.0.nix;
  };
  results = lib.mapAttrs (_: value: value.contracts) versions;
  failed = builtins.filter (name: !builtins.all (x: x) (builtins.attrValues results.${name})) (
    builtins.attrNames results
  );
in
assert failed == [ ] || throw "GCC target-tool contracts: ${lib.concatStringsSep ", " failed}";
results

{
  pkgs,
  tvpLib,
  base,
  parent,
  compiler,
}:
let
  inherit (pkgs) lib;
  undeclared = base.components.gcc;
  negativeAudit = tvpLib.bases.mkOwnershipTest {
    inherit pkgs base;
    name = "gcc16-missing-owner";
    roots = base.ownership.roots;
    allowedRuntimePaths = builtins.filter (
      p: toString p != toString undeclared
    ) base.ownership.allowedRuntimePaths;
  };
  # Run the production audit in a separate shell so the expected-failure
  # conditional cannot suppress errexit inside its command substitution.
  negativeScript = pkgs.writeText "tvp-negative-ownership.sh" (
    "shopt -s inherit_errexit\n" + negativeAudit.buildPhase
  );

in
{
  pinned-construction = tvpLib.bases.mkBaseTest {
    inherit base;
    name = "pinned-construction";
    script = ''
      test '${compiler.stdenv.drvPath}' = '${parent.stdenv.drvPath}'
      test '${base.components.libc}' = '${parent.components.libc}'
      test '${base.components.binutils}' = '${parent.components.binutils}'
      test '${base.stdenv.shell}' = '${parent.stdenv.shell}'
      test '${base.fixupTools.patchelf}' = '${parent.fixupTools.patchelf}'
      test '${base.stdenv.cc.version}' = 16.2.0
      cc -dumpfullversion | grep -qx 16.2.0
      echo ok
    '';
    expected = "ok";
  };
  undeclared-runtime-owner = tvpLib.bases.mkBaseTest {
    inherit base;
    name = "undeclared-runtime-owner";
    script = ''
      if out=$PWD/rejected-output ${base.stdenv.shell} -e ${negativeScript} >rejected.log 2>&1; then
        echo 'undeclared compiler incorrectly accepted' >&2
        exit 1
      fi
      grep -F 'unowned runtime dependency: ${undeclared}' rejected.log >&2
      echo ok
    '';
    expected = "ok";
  };
}

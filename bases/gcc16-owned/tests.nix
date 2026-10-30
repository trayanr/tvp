{
  pkgs,
  tvpLib,
  base,
  parent,
  compiler,
}:
let
  inherit (pkgs) lib;
  closure = pkgs.closureInfo { rootPaths = base.ownership.roots; };
  undeclared = base.components.gcc;
  allowedWithoutCompiler = pkgs.writeText "tvp-gcc16-missing-owner" (
    lib.concatMapStrings (p: "${p}\n") (
      builtins.filter (p: toString p != toString undeclared) base.ownership.allowedRuntimePaths
    )
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
      # Remove one real selected compiler, not an unrelated synthetic path.
      grep -Fx '${undeclared}' ${closure}/store-paths >&2
      if grep -Fx '${undeclared}' ${allowedWithoutCompiler}; then exit 1; fi
      foreign=0
      while IFS= read -r path; do
        if ! grep -Fx "$path" ${allowedWithoutCompiler} >/dev/null; then
          printf '%s\n' "$path" >> rejected
          foreign=1
        fi
      done < ${closure}/store-paths
      test "$foreign" = 1
      grep -Fx '${undeclared}' rejected >/dev/null
      echo ok
    '';
    expected = "ok";
  };
}

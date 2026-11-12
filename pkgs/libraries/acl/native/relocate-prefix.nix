# Installed ACL locale constants need the same fixed-width relocation as Attr.
{
  lib,
  python,
  binutils,
  patchelf,
  bash,
}:
{
  name = "acl.relocate";
  tools = [
    python
    binutils
    patchelf
  ];
  run = ''${python}/bin/python3 -B ${../../ordinary-attr-crypt-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${patchelf}/bin/patchelf ${
    lib.escapeShellArg (
      builtins.toJSON {
        readelf = "${binutils}/bin/readelf";
        requiredDirectories = [
          "bin"
          "lib"
          "share/man"
          "nix-support"
        ];
        requiredFiles = [
          "bin/chacl"
          "bin/getfacl"
          "bin/setfacl"
          "lib/libacl.a"
          "lib/libacl.la"
          "lib/pkgconfig/libacl.pc"
        ];
        requiredRegular = [
          "lib/libacl.a"
          "lib/libacl.la"
          "lib/pkgconfig/libacl.pc"
          "nix-support/propagated-build-inputs"
        ];
        libtoolData = [ "lib/libacl.la" ];
        buildShell = "${bash}/bin/bash";
        shell = "${bash}/bin/bash";
        paths = [ ];
      }
    )
  }'';
}

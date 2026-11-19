{
  lib,
  fetchMirrors,
  certificates,
}:
{ version, sha256 }:
if
  builtins.elem version [
    "8.6.18"
    "9.1.0"
  ]
then
  import <nix/fetchurl.nix> {
    url = "https://prdownloads.sourceforge.net/tcl/tcl${version}-src.tar.gz";
    inherit sha256;
  }
else
  fetchMirrors {
    inherit certificates;
    urls = [
      "https://prdownloads.sourceforge.net/tcl/tcl${version}-src.tar.gz"
      "https://prdownloads.sourceforge.net/tcl/tcl${version}.tar.gz"
    ]
    ++ lib.optionals (lib.versionOlder version "8.6.0") [
      "https://prdownloads.sourceforge.net/tcl/tcl${lib.versions.majorMinor version}p${lib.versions.patch version}.tar.gz"
      "https://prdownloads.sourceforge.net/tcl/tcl${lib.versions.majorMinor version}.tar.gz"
    ];
    inherit sha256;
  }

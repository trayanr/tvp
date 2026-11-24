# Translate a Nixpkgs library's declared development graph for the explicit TVP
# environment. TVP providers already publish this interface and remain unchanged.
{ lib }:
let
  library =
    package:
    if package ? development then
      package
    else
      package
      // {
        development = {
          libraryDirectories = [ "${lib.getLib (package // { outputSpecified = false; })}/lib" ];
          libraries = map library (
            builtins.filter lib.isDerivation (
              (package.buildInputs or [ ]) ++ (package.propagatedBuildInputs or [ ])
            )
          );
        };
      };
in
library

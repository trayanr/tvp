# Shared installed-library finalization; each versioned recipe owns its plan,
# dependencies and upstream configure/check behavior.
{ lib }:
{
  finish =
    {
      outputs,
      bash,
      python,
      binutils,
      patchelf,
      base,
      libraryDirectory,
      runtimeLibraries,
      developmentLibraries,
    }:
    assert builtins.match "[A-Za-z0-9][A-Za-z0-9/_+-]*" libraryDirectory != null;
    assert !(builtins.elem ".." (lib.splitString "/" libraryDirectory));
    [
      (outputs.shebangs {
        inherit python;
        paths = [ libraryDirectory ];
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${bash}/bin/bash";
      })
      (outputs.strip {
        inherit python binutils;
        paths = [ libraryDirectory ];
        elfKinds = [ "runtime" ];
      })
      (outputs.stripArchives {
        inherit python binutils;
        paths = [ libraryDirectory ];
      })
      (outputs.rpaths {
        inherit
          python
          binutils
          patchelf
          base
          ;
        libraries = runtimeLibraries;
        paths = [ libraryDirectory ];
        elfKinds = [ "runtime" ];
      })
      (outputs.checkPaths {
        inherit python binutils patchelf;
        paths = [ libraryDirectory ];
        elfKinds = [ "runtime" ];
      })
      (outputs.development {
        inherit python;
        libraries = developmentLibraries;
      })
    ];
}

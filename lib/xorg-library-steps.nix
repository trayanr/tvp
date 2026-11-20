# Shared installed-library steps; each recipe owns its plan, dependencies and
# upstream configure/check behavior.
{
  lib,
  context ? null,
}:
{
  indexArchives =
    { libraryDirectory, archives }:
    assert builtins.match "[A-Za-z0-9][A-Za-z0-9/_+-]*" libraryDirectory != null;
    assert
      archives != [ ] && builtins.all (name: builtins.match "[A-Za-z0-9_-]+[.]a" name != null) archives;
    {
      name = "xorg.index-archives";
      tools = [ context.tools.binutils ];
      run = ''
        # Libtool's install-time ranlib can stamp the archive index with the
        # current time. Normalize it before storing the compilation artifact.
        for archive in ${lib.escapeShellArgs archives}; do
          path="$out"/${lib.escapeShellArg libraryDirectory}/"$archive"
          if [[ ! -f "$path" || -L "$path" ]]; then
            printf 'Expected regular static archive at %s\n' "$path" >&2
            exit 1
          fi
          ${context.tools.binutils}/bin/ranlib -D -- "$path"
        done
      '';
    };

  finish =
    {
      outputs ? context.outputs,
      bash ? context.tools.bash,
      python ? context.tools.python,
      binutils ? context.tools.binutils,
      patchelf ? context.tools.patchelf,
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

{ lib }:
{
  # Effective base/environment wiring, returning an ordinary editable step.
  command =
    {
      base,
      environment,
      cwd ? "source",
    }:
    let
      selected = base.environment environment;
    in
    name: run: selected // { inherit name run cwd; };

  # Test-side restoration never participates in the production checkpoint.
  restoreCheckpoint =
    {
      name,
      checkpoint,
      python,
    }:
    {
      inherit name;
      tools = [ python ];
      run = ''
        ${python}/bin/python3 -B ${./restore-checkpoint.py} ${lib.escapeShellArg checkpoint} "$TVP_SOURCE_ROOT"
      '';
    };

  unpack =
    {
      src,
      tar,
      xz ? null,
      gzip ? null,
      bzip2 ? null,
      findutils ? null,
      compression ? "xz",
    }:
    let
      codec =
        if compression == "xz" || compression == "lzip" then
          if xz == null then throw "Owned ${compression} source requires an xz tool" else xz
        else if compression == "gzip" then
          if gzip == null then throw "Owned gzip source requires a gzip tool" else gzip
        else if compression == "bzip2" then
          if bzip2 == null then throw "Owned bzip2 source requires a bzip2 tool" else bzip2
        else
          throw "Unsupported owned source compression: ${compression}";
      extract =
        if compression == "lzip" then
          "${codec}/bin/xz --format=lzip --decompress --stdout ${src} | ${tar}/bin/tar -xf -"
        else
          ''PATH=${lib.escapeShellArg "${codec}/bin"}:"$PATH" ${tar}/bin/tar -x${
            if compression == "xz" then
              "J"
            else if compression == "bzip2" then
              "j"
            else
              "z"
          }f ${src}'';
    in
    {
      name = "source.unpack";
      tools = [
        tar
        codec
      ]
      ++ lib.optional (findutils != null) findutils;
      run = ''
        mkdir source
        ${extract} --strip-components=1 -C source
        chmod -R u+w source
        # Match the source epoch policy: regular files, bounded by build start.
        epoch=$(${
          if findutils == null then "find" else "${findutils}/bin/find"
        } source -type f -not -newer "$NIX_BUILD_TOP/.." -printf '%T@\n' | sort -n | tail -n1)
        epoch=''${epoch%%.*}
        if (( ''${epoch:-0} < 315532800 )); then epoch=315532800; fi
        printf '%s\n' "$epoch" > source-date-epoch
      '';
    };
  # Explicit source scripts, using the same validated replacement operation as
  # installed scripts. No interpreter discovery or recursive source-wide sweep.
  shebangs =
    {
      name,
      python,
      paths,
      names,
      interpreter,
      cwd ? "source",
    }:
    {
      inherit name cwd;
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${./output-tools}/shebangs.py "$PWD" ${
        lib.escapeShellArg (
          builtins.toJSON {
            inherit paths names;
            interpreter = toString interpreter;
            selfInterpreter = null;
          }
        )
      } ${./native-output}'';
    };
  prepareAutotools =
    {
      name,
      bash,
      python,
      base,
      cwd ? "source",
    }:
    {
      inherit name cwd;
      tools = [ python ];
      env = {
        CONFIG_SHELL = "${bash}/bin/bash";
        lt_cv_deplibs_check_method = "pass_all";
      };
      run = "${python}/bin/python3 -B ${./owned-autotools.py} ${lib.escapeShellArg "${bash}/bin/bash"}";
    };
}

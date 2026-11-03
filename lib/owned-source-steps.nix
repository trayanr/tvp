{ lib }:
{
  unpack =
    {
      src,
      tar,
      xz ? null,
      gzip ? null,
      compression ? "xz",
    }:
    let
      codec =
        if compression == "xz" then
          if xz == null then throw "Owned xz source requires an xz tool" else xz
        else if compression == "gzip" then
          if gzip == null then throw "Owned gzip source requires a gzip tool" else gzip
        else
          throw "Unsupported owned source compression: ${compression}";
    in
    {
      name = "source.unpack";
      tools = [
        tar
        codec
      ];
      run = ''
        mkdir source
        PATH=${lib.escapeShellArg "${codec}/bin"}:"$PATH" ${tar}/bin/tar -x${
          if compression == "xz" then "J" else "z"
        }f ${src} --strip-components=1 -C source
        chmod -R u+w source
        # Match the source epoch policy: regular files, bounded by build start.
        epoch=$(find source -type f -not -newer "$NIX_BUILD_TOP/.." -printf '%T@\n' | sort -n | tail -n1)
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
      run = ''${python}/bin/python3 -B ${./owned-autotools.py} ${lib.escapeShellArg "${bash}/bin/bash"}'';
    };
}

{ lib }:
{
  unpack =
    {
      src,
      tar,
      xz,
    }:
    {
      name = "source.unpack";
      tools = [
        tar
        xz
      ];
      run = ''
        mkdir source
        PATH=${lib.escapeShellArg "${xz}/bin"}:"$PATH" ${tar}/bin/tar -xJf ${src} --strip-components=1 -C source
        chmod -R u+w source
        # Match the source epoch policy: regular files, bounded by build start.
        epoch=$(find source -type f -not -newer "$NIX_BUILD_TOP/.." -printf '%T@\n' | sort -n | tail -n1)
        epoch=''${epoch%%.*}
        if (( ''${epoch:-0} < 315532800 )); then epoch=315532800; fi
        printf '%s\n' "$epoch" > source-date-epoch
      '';
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

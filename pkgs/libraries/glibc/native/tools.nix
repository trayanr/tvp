# Post-bootstrap owned API. Explicit base replaces legacy stdenv; source libc
# binds the effective bin sibling and build-Perl fallback at the call site.
{
  tvp,
  lib,
  glibc,
  base,
  bash,
  perl,
  buildPerl,
  coreutils,
  python3Minimal,
  sed,
  grep,
  gawk,
}:
tvp.builder {
  recipe =
    args@{
      base,
      bash,
      perl,
      coreutils,
      python3Minimal,
      glibc,
      buildPerl,
      sed,
      grep,
      gawk,
    }:
    final: {
      pname = "glibc-tools";
      version = final.glibc.version;
      src = null;
      inherit (args)
        base
        bash
        perl
        coreutils
        python3Minimal
        glibc
        buildPerl
        sed
        grep
        gawk
        ;
      plan = [
        {
          name = "glibc-tools.copy";
          tools = [
            final.coreutils
            final.python3Minimal
          ];
          run = ''
            ${final.coreutils}/bin/cp -a --no-preserve=ownership ${final.glibc.bin} "$out"
            ${final.coreutils}/bin/chmod -R u+w "$out"
            ${final.python3Minimal}/bin/python3 -B ${./.}/rebind-tools.py "$out" \
              ${final.bash}/bin/bash ${final.perl}/bin/perl ${final.buildPerl}/bin/perl \
              ${lib.escapeShellArg "${final.coreutils}/bin:${final.sed}/bin:${final.grep}/bin:${final.gawk}/bin"}
          '';
        }
      ];
    };
  args = {
    inherit
      base
      bash
      perl
      coreutils
      python3Minimal
      glibc
      buildPerl
      sed
      grep
      gawk
      ;
  };
  dependencyNames = [
    "bash"
    "perl"
    "coreutils"
    "python3Minimal"
    "glibc"
    "buildPerl"
    "sed"
    "grep"
    "gawk"
  ];
  metadata.kind = "owned-libc-tools";
  selection.kind = "owned-libc-tools";
  mkTests = _: { };
}

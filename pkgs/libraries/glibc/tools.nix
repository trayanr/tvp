# Rebind installed scripts after libc has bootstrapped its runtime interpreters.
# Keep this separate from libc's build to avoid a libc/shell dependency cycle.
{
  glibc,
  stdenv,
  bash,
  perl,
}:
stdenv.mkDerivation {
  pname = "glibc-tools";
  inherit (glibc) version;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    cp -a ${glibc.bin} "$out"
    chmod -R u+w "$out"
    while IFS= read -r -d "" f; do
      if [ "$(head -c2 "$f")" = '#!' ]; then
        read -r first < "$f"
        case "$first" in
          *perl*)
            # mtrace also has a configured Perl exec fallback in its body.
            substituteInPlace "$f" --replace-quiet ${glibc.tvp.deps.perl} ${perl}
            sed -i '1c#!${perl}/bin/perl' "$f"
            ;;
          *) sed -i '1c#!${bash}/bin/bash' "$f" ;;
        esac
      fi
    done < <(find "$out" -type f -print0)
  '';
}

# Dated data installation, with no compile, runtime-library or ELF stages.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
}:
final: {
  pname = "ca-certificates";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  plan = [
    {
      name = "certificates.install";
      tools = [ final.coreutils ];
      run = ''
        install -Dm644 ${final.src} "$out/etc/ssl/certs/ca-bundle.crt"
        mkdir -p "$out/nix-support"
        # Exact former substitution; the hook is output data, never executed here.
        hook=$(cat ${../setup-hook.sh})
        printf '%s\n' "''${hook//@bundle@/$out/etc/ssl/certs/ca-bundle.crt}" > "$out/nix-support/setup-hook"
        chmod 644 "$out/nix-support/setup-hook"
      '';
    }
  ];
  meta = {
    description = "Dated Mozilla CA root certificate bundle published by curl";
    homepage = "https://curl.se/docs/caextract.html";
    license = lib.licenses.mpl20;
    platforms = [ "x86_64-linux" ];
  };
}

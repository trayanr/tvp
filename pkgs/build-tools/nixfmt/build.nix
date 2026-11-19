{
  tvp,
  lib,
  base,
  src,
  version,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
in
{
  pname = "nixfmt";
  inherit base src version;
  inherit (tools) bash coreutils;
  plan = steps.sequence [
    {
      name = "nixfmt.install-release";
      tools = [ tools.coreutils ];
      run = ''
        install -Dm755 ${final.src} "$out/bin/nixfmt"
      '';
    }
    (steps.split "nixfmt.finalize")
    (outputs.copyArtifacts { })
    {
      name = "nixfmt.verify-static-elf";
      tools = [
        tools.binutils
        tools.grep
      ];
      run = ''
        export LC_ALL=C
        header=$(readelf -hW "$out/bin/nixfmt")
        grep -Eq '^[[:blank:]]*Class:[[:blank:]]*ELF64[[:blank:]]*$' <<< "$header"
        grep -Eiq '^[[:blank:]]*Machine:.*X86-64[[:blank:]]*$' <<< "$header"
        program_headers=$(readelf -lW "$out/bin/nixfmt")
        if grep -Eq '^[[:blank:]]*(INTERP|DYNAMIC)[[:blank:]]' <<< "$program_headers"; then
          echo 'nixfmt unexpectedly needs a dynamic loader or libraries' >&2
          exit 1
        fi
      '';
    }
  ];
  meta = {
    description = "Official Nix formatter, packaged from the upstream static release";
    homepage = "https://github.com/NixOS/nixfmt";
    license = lib.licenses.mpl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "nixfmt";
  };
}

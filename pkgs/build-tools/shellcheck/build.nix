# Repackage the pinned upstream Linux x86-64 static executable.
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
  pname = "shellcheck";
  inherit base src version;
  inherit (tools) bash coreutils;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    {
      name = "shellcheck.install-pristine";
      tools = [ tools.coreutils ];
      cwd = "source";
      run = ''
        install -Dm755 shellcheck "$out/bin/shellcheck"
        install -Dm644 LICENSE.txt "$out/share/licenses/shellcheck/LICENSE.txt"
      '';
    }
    (steps.split "shellcheck.finalize")
    (outputs.copyArtifacts { })
    {
      name = "shellcheck.verify-static-elf";
      tools = [
        tools.binutils
        tools.grep
      ];
      run = ''
        export LC_ALL=C
        header=$(${tools.binutils}/bin/readelf -hW "$out/bin/shellcheck")
        grep -Eq '^[[:blank:]]*Class:[[:blank:]]*ELF64[[:blank:]]*$' <<< "$header"
        grep -Eq '^[[:blank:]]*Type:[[:blank:]]*EXEC[[:blank:]]' <<< "$header"
        grep -Eiq '^[[:blank:]]*Machine:.*X86-64[[:blank:]]*$' <<< "$header"
        program_headers=$(${tools.binutils}/bin/readelf -lW "$out/bin/shellcheck")
        if grep -Eq '^[[:blank:]]*(INTERP|DYNAMIC)[[:blank:]]' <<< "$program_headers"; then
          printf '%s\n' 'ShellCheck unexpectedly needs a dynamic loader or libraries' >&2
          exit 1
        fi
      '';
    }
  ];
  meta = {
    description = "Static analyzer for shell scripts, packaged from the upstream binary release";
    homepage = "https://www.shellcheck.net/";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "shellcheck";
  };
}

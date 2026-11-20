# Qualify multiple directory providers and explicit composed-environment replacement.
{
  package,
  lib,
  context,
}:
let
  p = package;
  d = p.tvp.deps;
  # aclocal gained native ACLOCAL_PATH support in 1.11.2.
  nativeMacroPath = lib.versionAtLeast p.version "1.11.2";
  message = if nativeMacroPath then "AC_MSG_NOTICE" else "AC_MSG_RESULT";
  noticePrefix = lib.optionalString nativeMacroPath "configure: ";
  configureFixture =
    if nativeMacroPath then
      "printf 'AC_INIT([macro-composition], [1])\\nTVP_FIRST\\nTVP_SECOND\\nAC_OUTPUT\\n' > configure.ac"
    else
      ''
        touch main.c
        printf 'AC_INIT([main.c])\nTVP_FIRST\nTVP_SECOND\nAC_OUTPUT\n' > configure.in
      '';
  collectMacros =
    if nativeMacroPath then
      "aclocal >&2"
    else
      ''
        IFS=: read -r -a macro_dirs <<< "$ACLOCAL_PATH"
        includes=()
        for directory in "''${macro_dirs[@]}"; do
          includes+=(-I "$directory")
        done
        aclocal "''${includes[@]}" >&2
      '';
  tools = (
    builtins.removeAttrs p.specification.base.tools [
      "gcc"
      "bash"
      "coreutils"
      "binutils"
    ]
  );
  provider =
    marker:
    p.edit (
      s:
      (builtins.removeAttrs s [ "artifactName" ])
      // {
        development = output: {
          aclocalDirectories = [
            "${output}/first"
            "${output}/second"
          ];
        };
        plan = [
          {
            name = "macro-provider.fixture";
            run = ''
              mkdir -p "$out/first" "$out/second" "$out/nix-support"
              printf 'AC_DEFUN([TVP_FIRST], [${message}([first-${marker}])])\n' > "$out/first/first.m4"
              printf 'AC_DEFUN([TVP_SECOND], [${message}([second-${marker}])])\n' > "$out/second/second.m4"
              printf 'exit 93\n' > "$out/nix-support/setup-hook"
            '';
          }
        ];
      }
    );
  ordinary = provider "ordinary";
  replacement = provider "replacement";
  script = marker: ''
    ${configureFixture}
    ${collectMacros}
    ${d.autoconf}/bin/autoconf >&2
    ./configure > notices
    grep -qx '${noticePrefix}first-${marker}' notices
    grep -qx '${noticePrefix}second-${marker}' notices
    if grep -q '${if marker == "ordinary" then "replacement" else "ordinary"}' notices; then exit 1; fi
    printf '${marker}'
  '';
in
context.mkSuite {
  package = p;
  tools = [
    d.autoconf
    tools.grep
    tools.sed
    tools.gawk
  ];
  libraries = [ ordinary ];
  tests = {
    macro-multiple-directories = {
      script = script "ordinary";
      expected = "ordinary";
    };
    macro-environment-replacement = {
      environment.paths.ACLOCAL_PATH = {
        separator = ":";
        entries = replacement.development.aclocalDirectories;
      };
      script = script "replacement";
      expected = "replacement";
    };
  };
}

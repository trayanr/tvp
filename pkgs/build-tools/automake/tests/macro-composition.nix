# Qualify multiple directory providers and explicit composed-environment replacement.
{ package, pkgs }:
let
  p = package;
  d = p.tvp.deps;
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
              printf 'AC_DEFUN([TVP_FIRST], [AC_MSG_NOTICE([first-${marker}])])\n' > "$out/first/first.m4"
              printf 'AC_DEFUN([TVP_SECOND], [AC_MSG_NOTICE([second-${marker}])])\n' > "$out/second/second.m4"
              printf 'exit 93\n' > "$out/nix-support/setup-hook"
            '';
          }
        ];
      }
    );
  ordinary = provider "ordinary";
  replacement = provider "replacement";
  script = marker: ''
    printf 'AC_INIT([macro-composition], [1])\nTVP_FIRST\nTVP_SECOND\nAC_OUTPUT\n' > configure.ac
    aclocal >&2
    ${d.autoconf}/bin/autoconf >&2
    ./configure > notices
    grep -qx 'configure: first-${marker}' notices
    grep -qx 'configure: second-${marker}' notices
    if grep -q '${if marker == "ordinary" then "replacement" else "ordinary"}' notices; then exit 1; fi
    printf '${marker}'
  '';
in
p.testContext.mkSuite {
  package = p;
  tools = [
    d.autoconf
    d.grep
    d.sed
    d.gawk
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

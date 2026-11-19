{ package, context, ... }:
let
  zoneinfo = "${package}/share/zoneinfo";
  coreutils = package.specification.base.tools.coreutils;
in
context.mkSuite {
  inherit package;
  tools = [ coreutils ];
  tests = {
    transition = {
      script = ''
        export TZDIR=${zoneinfo} TZ=Europe/Paris
        date -d '@1705320000' +%z
        date -d '@1721044800' +%z
      '';
      expected = "+0100\n+0200";
    };
    layout = {
      script = ''
        for zone in Europe/Paris posix/Europe/Paris right/Europe/Paris; do
          test "$(head -c 4 ${zoneinfo}/"$zone")" = TZif
        done
        IFS=' ' read -r hash keyword release extra < ${zoneinfo}/tzdata.zi
        test "$hash $keyword" = '# version'
        printf '%s\n' "$release"
      '';
      expected = package.version;
    };
  };
}

# Compile the IANA database with the zic from the same source release.
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
  command = steps.command { environment = final.environment; };
in
{
  pname = "tzdata";
  inherit base src version;
  inherit (tools) bash coreutils;
  environment.tools = [
    tools.gnumake
    tools.gawk
  ];

  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "lzip";
    })
    (command "tzdata.build" ''
      test "$(cat version)" = "${final.version}"
      make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash CC="$CC" zic tzdata.zi leapseconds
    '')
    (command "tzdata.install" ''
      zoneinfo="$out/share/zoneinfo"
      mkdir -p "$zoneinfo"
      ./zic -b fat -d "$zoneinfo" tzdata.zi
      ./zic -b fat -d "$zoneinfo/right" -L leapseconds tzdata.zi
      install -m644 -t "$zoneinfo" iso3166.tab zone.tab zone1970.tab zonenow.tab \
        leapseconds leap-seconds.list tzdata.zi
      install -Dm644 LICENSE "$out/share/licenses/tzdata/LICENSE"

      mkdir "$zoneinfo/posix"
      for entry in "$zoneinfo"/*; do
        name="''${entry##*/}"
        case "$name" in
          posix|right) continue ;;
        esac
        ln -s "../$name" "$zoneinfo/posix/$name"
      done
    '')
    (steps.split "tzdata.finalize")
    (outputs.copyArtifacts { })
    (outputs.checkPaths { paths = [ "share" ]; })
  ];

  meta = {
    description = "IANA time zone and daylight saving time data";
    homepage = "https://www.iana.org/time-zones";
    license = lib.licenses.publicDomain;
    platforms = [ "x86_64-linux" ];
  };
}

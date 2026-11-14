# Complete libdns_sd 2881.120.11 procedure; earlier providers stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "libdns_sd.${name}";
      cwd = "source";
      run = ''
          mkdir -p "$evidence"
          status=0
        export TVP_SOURCE_ROOT
          ${final.bash}/bin/bash -euo pipefail -c ${lib.escapeShellArg run} > "$evidence/${name}.log" 2>&1 || status=$?
          cat "$evidence/${name}.log"
          printf '%s\n' "$status" > "$evidence/${name}.status"
          test "$status" = 0
      '';
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libdns_sd";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    ;
  inherit (tools) bash coreutils;
  outputs = [
    "out"
    "evidence"
  ];
  environment = {
    tools = [
      tools.gnumake
      tools.python
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      tools.gzip
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    # Upstream's ST hook strips the linked client library; defer it to F.
    (command "build" ''
      ${make} -C mDNSPosix os=linux CC="$CC" LD="$CC" ST=${final.coreutils}/bin/true libdns_sd
    '')
    (command "install" ''
      install -Dm755 mDNSPosix/build/prod/libdns_sd.so "$out/lib/libdns_sd.so.1"
      ln -s libdns_sd.so.1 "$out/lib/libdns_sd.so"
      install -Dm644 mDNSShared/dns_sd.h "$out/include/dns_sd.h"
      install -Dm644 mDNSShared/dnssd_clientlib.c "$out/share/licenses/libdns_sd/dnssd_clientlib.c"
      printf '%s\n' 'Client-library profile: upstream daemon and integration tests are outside this build.' > "$evidence/upstream-limit.txt"
    '')
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "libdns_sd.finalize")
    (outputs.copyArtifacts {
      outputs = final.outputs;
    })
    {
      name = "libdns_sd.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        if builtins.elem "evidence" final.outputs then
          ''"$evidence" "''${TVP_ARTIFACT_OUTPUTS[evidence]}"''
        else
          ""
      }'';
    }
    (outputs.strip {
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      paths = [ "lib" ];
    })
    (outputs.development {
      libraries = [ ];
    })
    (outputs.checkPaths {
      paths = [ "lib" ];
    })
  ];
  tvp.features = {
    daemon = false;
    shared = true;
    static = false;
  };
  meta = {
    description = "mDNSResponder DNS Service Discovery client library";
    homepage = "https://github.com/apple-oss-distributions/mDNSResponder";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}

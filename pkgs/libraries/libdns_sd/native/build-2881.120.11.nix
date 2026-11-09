# Ordinary native 2881.120.11 only; retained construction and historical profiles use independent recipes.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnumake,
  gnutar,
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  gzip,
}:
final:
let
  inherit (tvp.builder) steps outputs;
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
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libdns_sd";
  inherit
    base
    src
    version
    bash
    coreutils
    gnumake
    gnutar
    python
    binutils
    patchelf
    sed
    grep
    gawk
    diffutils
    findutils
    gzip
    ;
  outputs = [
    "out"
    "evidence"
  ];
  environment = {
    tools = [
      final.gnumake
      final.python
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.gzip
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    (command "build" ''
      ${make} -C mDNSPosix os=linux CC="$CC" LD="$CC" ST="$STRIP" libdns_sd
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
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [ "lib" ];
    })
    (outputs.development {
      python = final.python;
      libraries = [ ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
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

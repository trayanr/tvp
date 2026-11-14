# Ordinary native 2.4.20 only; retained construction and historical profiles use independent recipes.
{
  tvp,
  lib,
  base,
  src,
  version,
  patches,
  testPatches ? [ ../patches/testfile-explicit-search-path.patch ],
  patch,
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
  pkg-config,
  openssl,
  zlib,
  dnssd,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "libcups.${name}";
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
  productionPatches = builtins.filter (p: !(builtins.elem p final.testPatches)) final.patches;
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libcups";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    patches
    testPatches
    patch
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
    pkg-config
    openssl
    zlib
    dnssd
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
      final.pkg-config
    ];
    libraries = [
      final.dnssd
      final.openssl
      final.zlib
    ];
  };
  runtime.libraries = [
    final.dnssd
    final.openssl
    final.zlib
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    # The declared testfile patch is private validation preparation. Caller
    # production patches retain the original effective override interface.
    {
      name = "source.patch";
      cwd = "source";
      enabled = productionPatches != [ ];
      tools = [ final.patch ];
      run = lib.concatMapStringsSep "\n" (
        p: "${final.patch}/bin/patch -p1 < ${lib.escapeShellArg "${p}"}"
      ) productionPatches;
    }
    (steps.prepareAutotools {
      name = "libcups.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" --with-components=libcups \
        --with-tls=openssl --with-dnssd=mdnsresponder \
        --with-dnssd-includes=${final.dnssd}/include --with-dnssd-libs=${final.dnssd}/lib \
        --disable-gssapi --disable-pam --disable-dbus --disable-libusb --disable-systemd \
        --with-rcdir=no --with-rclevels=no
    '')
    (command "build" make)
    (command "install" "${make} install")
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "libcups.finalize")
    (tvp.builder.outputs.copyArtifacts {
      coreutils = final.coreutils;
      outputs = final.outputs;
    })
    {
      name = "libcups.relocate";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        if builtins.elem "evidence" final.outputs then
          ''"$evidence" "''${TVP_ARTIFACT_OUTPUTS[evidence]}"''
        else
          ""
      }'';
    }
    (outputs.shebangs {
      python = final.python;
      paths = [
        "bin"
        "lib"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    {
      name = "libcups.helper-tools";
      tools = [ final.python ];
      run = ''
                ${final.python}/bin/python3 - "$out/bin/cups-config" ${lib.escapeShellArg "${final.coreutils}/bin/dirname"} <<'PY_HELPER'
        import pathlib, sys
        p = pathlib.Path(sys.argv[1])
        p.write_text(p.read_text().replace('`dirname $0`', '`' + sys.argv[2] + ' "$0"`'))
        PY_HELPER
      '';
    }
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.development {
      python = final.python;
      libraries = [
        final.dnssd
        final.openssl
        final.zlib
      ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp.features = {
    server = false;
    tls = true;
    discovery = true;
    gssapi = false;
    pam = false;
    dbus = false;
    libusb = false;
    systemd = false;
  };
  meta = {
    description = "CUPS client printing library with TLS support";
    homepage = "https://openprinting.github.io/cups/";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}

# Complete libcups 2.4.20 procedure; earlier providers stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
  dnssd,
  openssl,
  pkg-config,
  zlib,
  patches,
  testPatches ? [ ./patches/testfile-explicit-search-path.patch ],
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "libcups.${name}";
      cwd = "source";
      run = ''
        mkdir -p "$evidence"
        export TVP_SOURCE_ROOT
        status=0
        # Keep diagnostics in the Nix log because parallel output can vary.
        ${final.bash}/bin/bash -euo pipefail -c ${lib.escapeShellArg run} || status=$?
        printf '%s\n' "$status" > "$evidence/${name}.status"
        test "$status" = 0
      '';
    };
  productionPatches = builtins.filter (p: !(builtins.elem p final.testPatches)) final.patches;
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
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
    pkg-config
    openssl
    zlib
    dnssd
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
      compression = "gzip";
    })
    # The declared testfile patch is private validation preparation. Caller
    # production patches retain the original effective override interface.
    {
      name = "source.patch";
      cwd = "source";
      enabled = productionPatches != [ ];
      tools = [ tools.patch ];
      run = lib.concatMapStringsSep "\n" (
        p: "${tools.patch}/bin/patch -p1 < ${lib.escapeShellArg "${p}"}"
      ) productionPatches;
    }
    (steps.prepareAutotools {
      name = "libcups.prepare";
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
    (outputs.copyArtifacts {
      outputs = final.outputs;
    })
    {
      name = "libcups.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        if builtins.elem "evidence" final.outputs then
          ''"$evidence" "''${TVP_ARTIFACT_OUTPUTS[evidence]}"''
        else
          ""
      }'';
    }
    (outputs.shebangs {
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
      tools = [ tools.python ];
      run = ''
                ${tools.python}/bin/python3 - "$out/bin/cups-config" ${lib.escapeShellArg "${final.coreutils}/bin/dirname"} <<'PY_HELPER'
        import pathlib, sys
        p = pathlib.Path(sys.argv[1])
        p.write_text(p.read_text().replace('`dirname $0`', '`' + sys.argv[2] + ' "$0"`'))
        PY_HELPER
      '';
    }
    (outputs.strip {
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.development {
      libraries = [
        final.dnssd
        final.openssl
        final.zlib
      ];
    })
    (outputs.checkPaths {
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

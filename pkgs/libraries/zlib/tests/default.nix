# One suite, shared by every zlib version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
#
# zlib installs no executable, so every test compiles against the headers and
# links the library — which is also how every consumer uses it.
{
  package,
  lib,
  context,
}:
let
  zlib = package;
  s = package.specification;
  d = s.base.tools // {
    binutils = s.base.compiler.bintools;
  };
  t = package.tvp.declaredTestDependencies;
  pkg-config = t.pkgConfig;
  gzip = t.gzip;
  commonTools = [
    d.sed
    d.grep
    d.gawk
    d.diffutils
    d.binutils
  ];

  message = "tvp preserves what other software is built on";
  tvpCrc32 = "85d9b6d2";

  cc = [ s.base.compiler ];

  features = zlib.passthru.tvp.features or { };

  # 0.x names the archive libgz.a; from 1.0 it is libz.a.
  l = "-l" + (features.libName or "z");

  # 1.2.7.2 reports "1.2.7.2-motley"; every other release reports its own name.
  reported = zlib.passthru.tvp.reportedVersion or zlib.version;
  custom = (package.override { doCheck = false; }).editSteps (
    plan:
    plan
    ++ [
      {
        name = "zlib.consumer-marker";
        run = ''printf '%s\n' edited > "$out/nix-support/consumer-marker"'';
      }
    ]
  );
in
context.mkSuite {
  package = zlib;
  libraries = [ zlib ];
  tools = commonTools;

  tests = {
    # Paired with `version`: together they prove the installed header and the
    # installed library came from the same build.
    soname = {
      script = "${d.binutils}/bin/readelf -d ${zlib}/lib/libz.so.${s.installedInterface.libraryVersion} | grep -F '(SONAME)' | grep -F '[libz.so.1]' >/dev/null; echo ok";
      expected = "ok";
    };
    symbol-versions = {
      script = ''
        ${d.python}/bin/python3 -B ${./symbol-versions.py} \
          ${zlib.specification.src} ${zlib}/lib/libz.so.${s.installedInterface.libraryVersion} \
          ${d.binutils}/bin/readelf
      '';
      expected = "ok";
      tools = commonTools ++ [ d.python ];
    };
    header-version = {
      script = ''
        "$CC" ${./fixtures/header-version.c} ${l} -o header-version
        ./header-version
      '';
      expected = reported;
      tools = commonTools ++ cc;
    };

    compress = {
      script = ''
        "$CC" ${./fixtures/roundtrip.c} ${l} -o roundtrip
        ./roundtrip
      '';
      expected = message;
      tools = commonTools ++ cc;
    };

    crc32 = {
      script = ''
        "$CC" ${./fixtures/crc.c} ${l} -o crc
        ./crc
      '';
      expected = tvpCrc32;
      tools = commonTools ++ cc;
    };

    # The on-disk format, checked by a gzip that knows nothing about this build.
    gzip = {
      script = ''
        "$CC" ${./fixtures/gz.c} ${l} -o gz
        ./gz
        gzip -dc out.gz
      '';
      expected = "tvp";
      tools = commonTools ++ cc ++ [ gzip ];
    };
  }

  // lib.optionalAttrs (features.compress2 or true) {
    # The levelled form, which arrives at 1.0.8. Kept as its own test so the
    # older releases lose only this one rather than the whole roundtrip.
    compress-level = {
      script = ''
        "$CC" ${./fixtures/roundtrip-level.c} ${l} -o roundtrip-level
        ./roundtrip-level
      '';
      expected = message;
      tools = commonTools ++ cc;
    };
  }

  // lib.optionalAttrs (features.versionFunction or true) {
    # The runtime version, from the library. zlibVersion() arrives at 1.0.5;
    # before that only the header carries a version at all.
    version = {
      script = ''
        "$CC" ${./fixtures/version.c} ${l} -o version
        ./version
      '';
      expected = reported;
      tools = commonTools ++ cc;
    };
  }

  // lib.optionalAttrs (features.pkgConfig or false) {
    pkg-config = {
      script = ''
        export PKG_CONFIG_LIBDIR=${zlib}/lib/pkgconfig
        pkg-config --modversion zlib
      '';
      expected = reported;
      tools = commonTools ++ [ pkg-config ];
    };
  }

  // lib.optionalAttrs (features.static or false) {
    # The archive by path, so this cannot silently fall through to libz.so.
    static = {
      script = ''
        "$CC" ${./fixtures/roundtrip.c} ${zlib}/lib/libz.a -o roundtrip-static
        ./roundtrip-static
      '';
      expected = message;
      tools = commonTools ++ cc;
    };
  }
  // lib.optionalAttrs ((features.pkgConfig or false) && (features.static or false)) {
    pkg-config-consumer = {
      tools = commonTools ++ [ pkg-config ];
      script = ''
        unset NIX_CFLAGS_COMPILE NIX_CFLAGS_LINK NIX_LDFLAGS
        export PKG_CONFIG_LIBDIR=${zlib}/lib/pkgconfig
        "$CC" ${./fixtures/version.c} $(pkg-config --cflags --libs zlib) -Wl,-rpath,${zlib}/lib -o shared
        ./shared
        "$CC" ${./fixtures/version.c} $(pkg-config --cflags zlib) -Wl,-Bstatic $(pkg-config --static --libs zlib) -Wl,-Bdynamic -o static
        ./static
      '';
      expected = "${reported}\n${reported}";
    };
    customization = {
      script = ''
        cat ${custom}/nix-support/consumer-marker
        "$CC" ${./fixtures/version.c} -I${custom}/include -L${custom}/lib -Wl,-rpath,${custom}/lib -lz -o consumer
        ./consumer
      '';
      expected = "edited\n${reported}";
    };
  };
}

// import ./contracts.nix { inherit package lib context; }
// lib.optionalAttrs (s.upstreamCheck.enabled or true) {
  upstream = context.mkUpstream { inherit package; };
}

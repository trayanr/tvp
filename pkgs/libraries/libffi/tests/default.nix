# One suite, shared by every libffi version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
#
# libffi installs no executable, so every test compiles against the header and
# links the library — which is also how every consumer uses it.
{
  package,
  lib,
  context,
}:

let
  libffi = package;
  pkg-config = package.tvp.declaredTestDependencies.pkgConfig;
  tools = package.specification.base.tools // {
    binutils = package.specification.base.compiler.bintools;
  };

  features = libffi.passthru.tvp.features or { };

  reported = libffi.passthru.tvp.reportedVersion or libffi.version;

  # Before 3.3 the headers install under ${libdir}/libffi-VERSION/include, which
  # no consumer finds without being told.
  inc =
    if (features.headersInIncludedir or true) then
      ""
    else
      "-I${libffi}/lib/libffi-${libffi.version}/include ";
in
context.mkSuite {
  inherit package;
  tools = [
    tools.binutils
    tools.grep
    tools.sed
    tools.gawk
    pkg-config
  ];
  libraries = [ package ];

  tests =
    {
      call = {
        script = ''
          cc ${./fixtures/call.c} ${inc}-lffi -o call
          ./call
        '';
        expected = "42";

      };

      # The other direction: a native pointer that dispatches into libffi.
      closure = {
        script = ''
          cc ${./fixtures/closure.c} ${inc}-lffi -o closure
          ./closure
        '';
        expected = "42";

      };

      pkg-config = {
        script = ''
          export PKG_CONFIG_LIBDIR=${libffi}/lib/pkgconfig:${libffi}/share/pkgconfig
          pkg-config --modversion libffi
        '';
        expected = libffi.version;

      };
    }

    // lib.optionalAttrs features.static {
      static = {
        script = "cc ${./fixtures/call.c} ${inc}${package}/lib/libffi.a -o static-call; ./static-call";
        expected = "42";
      };
    }

    // lib.optionalAttrs (features.variadic or false) {
      variadic = {
        script = ''
          cc ${./fixtures/variadic.c} ${inc}-lffi -o variadic
          ./variadic
        '';
        expected = "42";

      };
    }

    // lib.optionalAttrs (features.versionFunction or false) {
      version = {
        script = ''
          cc ${./fixtures/version.c} ${inc}-lffi -o version
          ./version
        '';
        expected = reported;

      };
    };
}

// import ../../ffi-decimal-contracts.nix { inherit package lib context; }

// lib.optionalAttrs package.specification.installedInterface.compatibilityLib64 (
  import ./abi.nix { inherit package lib context; }
)
// lib.optionalAttrs (package.specification.upstreamCheck.enabled or true) {
  upstream = import ./upstream.nix { inherit package lib context; };
}

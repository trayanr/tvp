# One suite, shared by every libffi version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
#
# libffi installs no executable, so every test compiles against the header and
# links the library — which is also how every consumer uses it.
{
  pkgs,
  tvpLib,
  libffi,
}:
let
  cc = [ libffi.passthru.tvp.cc ];
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
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = libffi;

  tests =
    {
      call = {
        script = ''
          cc ${./fixtures/call.c} ${inc}-lffi -o call
          ./call
        '';
        expected = "42";
        extraInputs = cc;
      };

      # The other direction: a native pointer that dispatches into libffi.
      closure = {
        script = ''
          cc ${./fixtures/closure.c} ${inc}-lffi -o closure
          ./closure
        '';
        expected = "42";
        extraInputs = cc;
      };

      pkg-config = {
        script = ''
          pkg-config --modversion libffi
        '';
        expected = libffi.version;
        extraInputs = [ pkgs.pkg-config ];
      };
    }

    // pkgs.lib.optionalAttrs (features.variadic or false) {
      variadic = {
        script = ''
          cc ${./fixtures/variadic.c} ${inc}-lffi -o variadic
          ./variadic
        '';
        expected = "42";
        extraInputs = cc;
      };
    }

    // pkgs.lib.optionalAttrs (features.versionFunction or false) {
      version = {
        script = ''
          cc ${./fixtures/version.c} ${inc}-lffi -o version
          ./version
        '';
        expected = reported;
        extraInputs = cc;
      };
    };
}

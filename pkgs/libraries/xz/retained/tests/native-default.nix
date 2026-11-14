# One suite, shared by every xz version. Never fork it per builder: a test that
# exists only for newer versions cannot detect drift in an older one. Guards
# select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  xz,
  pkg-config,
  referenceOlder,
  referenceNewer,
}:
let
  commonTools = with xz.tvp.declaredDependencies; [
    sed
    grep
    gawk
    diffutils
    binutils
  ];

  message = "tvp preserves what other software is built on";

  # Keep the format oracle on another release line. An absolute executable
  # avoids adding the reference liblzma to the compiler's search paths.
  reference = if pkgs.lib.versionOlder xz.version "5.8" then referenceNewer else referenceOlder;
  independent =
    reference.drvPath != xz.drvPath
    && reference.outPath != xz.outPath
    && (pkgs.lib.versions.majorMinor reference.version != pkgs.lib.versions.majorMinor xz.version);

  cc = [ xz.passthru.tvp.cc ];
  features = xz.passthru.tvp.features or { };
in
xz.testContext.mkSuite {
  package = xz;
  libraries = [ xz ];
  tools = commonTools;

  tests =
    {
      version = {
        script = ''
          "$CC" ${./fixtures/version.c} -llzma -o version
          ./version
        '';
        expected = xz.version;
        tools = commonTools ++ cc;
      };

      compress = {
        script = ''
          "$CC" ${./fixtures/roundtrip.c} -llzma -o roundtrip
          ./roundtrip
        '';
        expected = message;
        tools = commonTools ++ cc;
      };

      # The on-disk container, read back by an xz this build knows nothing about.
      format =
        assert independent;
        {
          script = ''
            "$CC" ${./fixtures/format.c} -llzma -o format
            ./format
            ${reference}/bin/xz -dc out.xz
          '';
          expected = "tvp";
          tools = commonTools ++ cc ++ [ reference ];
        };

      cli = {
        script = ''
          printf 'tvp' | xz -c | xz -dc
        '';
        expected = "tvp";
      };

      pkg-config = {
        script = ''
          export PKG_CONFIG_LIBDIR=${xz}/lib/pkgconfig
          pkg-config --modversion liblzma
        '';
        expected = xz.version;
        tools = commonTools ++ [ pkg-config ];
      };
    }

    // pkgs.lib.optionalAttrs (features.threaded or false) {
      threaded = {
        script = ''
          "$CC" ${./fixtures/threaded.c} -llzma -pthread -o threaded
          ./threaded
        '';
        expected = message;
        tools = commonTools ++ cc;
      };
    };
}

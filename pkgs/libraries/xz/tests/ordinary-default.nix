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

      installed-helpers = {
        script = ''
          mkdir empty
          printf 'needle preserved\n' > message
          ${xz}/bin/xz -c message > message.xz
          env -i PATH="$PWD/empty" ${xz}/bin/xzgrep needle message.xz > matched
          cmp message matched
          env -i PATH="$PWD/empty" ${xz}/bin/xzmore message.xz > paged
          grep -Fq 'needle preserved' paged
          ${xz}/bin/xz -t message.xz
          printf broken > broken.xz
          if ${xz}/bin/xz -t broken.xz >/dev/null 2>&1; then exit 1; fi
          printf helpers
        '';
        expected = "helpers";
      };
      raw-filter = {
        script = ''
          "$CC" ${./fixtures/ordinary-filter.c} -llzma -o filter
          ./filter
        '';
        expected = "filter";
        tools = commonTools ++ cc;
      };
      static = {
        script = ''
          "$CC" ${./fixtures/roundtrip.c} ${xz}/lib/liblzma.a -pthread -o static
          ./static
        '';
        expected = message;
        tools = commonTools ++ cc;
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
          "$CC" ${./fixtures/ordinary-threaded.c} -llzma -pthread -o threaded
          ./threaded
        '';
        expected = message;
        tools = commonTools ++ cc;
      };
    };
}

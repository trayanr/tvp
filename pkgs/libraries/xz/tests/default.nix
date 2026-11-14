# One suite, shared by every xz version. Never fork it per builder: a test that
# exists only for newer versions cannot detect drift in an older one. Guards
# select whole tests; they never edit a test body.
{
  package,
  lib,
  context,
}:
let
  xz = package;
  tools = xz.specification.base.standardTools;
  t = xz.tvp.declaredTestDependencies;
  inherit (t) referenceOlder referenceNewer;
  pkg-config = t.pkgConfig;
  commonTools = [
    tools.sed
    tools.grep
    tools.gawk
    tools.diffutils
    xz.specification.base.compiler.bintools
  ];
  message = "tvp preserves what other software is built on";

  # Keep the format oracle on another release line. An absolute executable
  # avoids adding the reference liblzma to the compiler's search paths.
  reference = if lib.versionOlder xz.version "5.8" then referenceNewer else referenceOlder;
  independent =
    reference.drvPath != xz.drvPath
    && reference.outPath != xz.outPath
    && (lib.versions.majorMinor reference.version != lib.versions.majorMinor xz.version);

  cc = [ xz.specification.base.compiler ];
  features = xz.tvp.features or { };
  custom =
    ((xz.override { doCheck = false; }).edit (
      s:
      s
      // {
        upstreamCheck = s.upstreamCheck // {
          run = throw "disabled XZ upstream command was forced";
        };
      }
    )).editSteps
      (
        plan:
        plan
        ++ [
          {
            name = "xz.consumer-marker";
            run = ''printf '%s\n' edited > "$out/nix-support/consumer-marker"'';
          }
        ]
      );
  shell = t.runtimeShell;
  runtime = (xz.override { doCheck = false; }).editRuntime (r: r // { inherit shell; });
in
(context.mkSuite {
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

      abi-pkgconfig = {
        tools = [
          pkg-config
          xz.specification.base.compiler
          xz.specification.base.compiler.bintools
          tools.grep
        ];
        script = ''
          unset NIX_CFLAGS_COMPILE NIX_CFLAGS_LINK NIX_LDFLAGS
          export PKG_CONFIG_LIBDIR=${xz}/lib/pkgconfig
          "$CC" ${./fixtures/version.c} $(pkg-config --cflags --libs liblzma) -Wl,-rpath,${xz}/lib -o shared
          ./shared
          "$CC" ${./fixtures/version.c} $(pkg-config --cflags liblzma) -Wl,-Bstatic $(pkg-config --static --libs liblzma) -Wl,-Bdynamic -o static
          ./static
          readelf -d ${xz}/lib/liblzma.so.5 | grep -F 'Library soname: [liblzma.so.5]' >/dev/null
          nm -D --defined-only ${xz}/lib/liblzma.so.5 | grep -w lzma_code >/dev/null
        '';
        expected = "${xz.version}\n${xz.version}";
      };
      formats-errors = {
        script = ''
          printf 'formats and integrity\n' > plain
          for format in xz lzma raw; do
            options=()
            if test "$format" = raw; then options=(--lzma2); fi
            ${xz}/bin/xz --format="$format" "''${options[@]}" -c plain > data
            ${xz}/bin/xz --format="$format" "''${options[@]}" -dc data > decoded
            cmp plain decoded
          done
          ${xz}/bin/xz -c plain > data.xz
          ${xz}/bin/xz -t data.xz
          head -c 10 data.xz > broken
          if ${xz}/bin/xz -t broken >/dev/null 2>&1; then exit 1; fi
          if ${xz}/bin/xz --definitely-invalid >/dev/null 2>&1; then exit 1; fi
          printf formats
        '';
        expected = "formats";
      };
      shell-helpers = {
        script = ''
          printf 'helper-ok\n' > plain
          ${xz}/bin/xz -c plain > sample.xz
          ${xz}/bin/xzgrep helper sample.xz
          ${xz}/bin/xzcmp sample.xz plain
        '';
        expected = "helper-ok";
      };
      runtime-shell = {
        tools = commonTools ++ [
          runtime
          shell
        ];
        script = ''
          test ${lib.escapeShellArg (toString shell)} != ${lib.escapeShellArg (toString xz.specification.base.shell)}
          mkdir empty
          printf 'runtime-shell\n' > plain
          ${runtime}/bin/xz -c plain > sample.xz
          env -i PATH="$PWD/empty" ${runtime}/bin/xzgrep runtime-shell sample.xz
        '';
        expected = "runtime-shell";
      };
      installed-payload = {
        script = ''
          test -s ${xz}/lib/liblzma.a
          test -s ${xz}/include/lzma.h
          test -s ${xz}/lib/pkgconfig/liblzma.pc
          test -s ${xz}/share/man/man1/xz.1.gz
          test -s ${xz}/nix-support/source-date-epoch
          test ! -e ${xz}/nix-support/xz-build-tree
          printf payload
        '';
        expected = "payload";
      };
    }

    // lib.optionalAttrs (features.threaded or false) {
      customization = {
        tools = commonTools ++ [ custom ];
        script = ''
          cat ${custom}/nix-support/consumer-marker
          printf 'custom-ok' | ${custom}/bin/xz -T2 | ${custom}/bin/unxz
        '';
        expected = "edited\ncustom-ok";
      };
      threaded = {
        script = ''
          "$CC" ${./fixtures/ordinary-threaded.c} -llzma -pthread -o threaded
          ./threaded
        '';
        expected = message;
        tools = commonTools ++ cc;
      };
    };
})
// lib.optionalAttrs xz.specification.installedInterface.prewriteGuards (
  context.mkSuite {
    package = xz;
    tools = commonTools;
    tests.guards = {
      tools = [ tools.python ];
      script = ''${tools.python}/bin/python3 -B ${./older-guards.py} ${../installed-guard.py} ${../validate-output.py}'';
      expected = "guards 38";
    };
  }
)
// lib.optionalAttrs xz.specification.buildFeatures.boundLess (
  context.mkSuite {
    package = xz;
    tools = commonTools;
    tests.pager = {
      script = ''
        mkdir empty
        printf 'pager roundtrip\n' > plain
        ${xz}/bin/xz -c plain > plain.xz
        env -i PATH="$PWD/empty" ${xz}/bin/xzless --show-preproc-error plain.xz > paged
        cmp plain paged
        printf pager
      '';
      expected = "pager";
    };
  }
)
// {
  split = import ./split.nix { inherit package context; };
}
// lib.optionalAttrs (xz.specification.upstreamCheck.enabled or true) {
  upstream = context.mkUpstream { inherit package; };
}

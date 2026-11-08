{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  p = package;
  d = p.tvp.deps;
  upstream = p.editSteps (
    tvp.builder.steps.insertAfter "texinfo.build" [
      (
        (p.specification.base.environment p.specification.environment)
        // {
          name = "texinfo.upstream";
          cwd = "source";
          run = ''
            export CONFIG_SHELL=${p.specification.bash}/bin/bash SHELL=${p.specification.bash}/bin/bash
            status=0
            ${d.gnumake}/bin/make -j"$NIX_BUILD_CORES" check || status=$?
            find . \( -name 'test-suite.log' -o -name '*.trs' \) -exec cat {} \; >&2
            if (( status )); then exit "$status"; fi
            mkdir -p "$out/nix-support/upstream"
            find . \( -name 'test-suite.log' -o -name '*.trs' \) | while read -r file; do
              mkdir -p "$out/nix-support/upstream/$(dirname "$file")"
              cp "$file" "$out/nix-support/upstream/$file"
            done
          '';
        }
      )
    ]
  );
  sourceProbe =
    (p.override { src = "${p.tvp.declaredTestDependencies.alternateSource}/source.tar.gz"; }).edit
      (
        s:
        let
          base = s.base.override { compiler = p.tvp.declaredTestDependencies.sentinel; };
        in
        s
        // {
          inherit base;
          plan = [
            (tvp.builder.steps.unpack {
              src = s.src;
              tar = d.gnutar;
              gzip = p.tvp.declaredTestDependencies.sourceGzip;
              findutils = d.findutils;
              compression = "gzip";
            })
            (
              (base.environment s.environment)
              // {
                name = "texinfo.source-base";
                run = ''
                  test "$(cat source/marker)" = 'alternate source'
                  printf 'int main(void) { return 0; }\n' > probe.c
                  "$CC" probe.c -o probe; "$CXX" -x c++ probe.c -o probe-cxx
                  env -i ./probe; env -i ./probe-cxx
                  test "$(cat selected-compiler)" = $'selected\nselected'
                  mkdir "$out"; cp source/marker "$out/source-marker"
                '';
              }
            )
          ];
        }
      );
  runtimeChanged = p.editRuntime (r: r // { dlopenDirectories = [ "${d.python}/lib" ]; });
  outputChanged = p.editSteps (
    tvp.builder.steps.append [
      {
        name = "texinfo.output-control";
        run = ''printf edited > "$out/nix-support/custom-output"'';
      }
    ]
  );
  provider = d.perl.edit (
    s:
    s
    // {
      plan = [
        {
          name = "texinfo.provider";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/perl" <<'SCRIPT'
            #!${p.specification.bash}/bin/bash
            if [[ -n "''${TVP_PROVIDER_LOG-}" ]]; then printf selected >> "$TVP_PROVIDER_LOG"; fi
            exec ${d.perl}/bin/perl "$@"
            SCRIPT
            chmod +x "$out/bin/perl"
          '';
        }
      ];
    }
  );
  localeProvider = d.perl.edit (
    s:
    s
    // {
      plan = [
        {
          name = "texinfo.locale-provider";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/locale" <<'SCRIPT'
            #!${p.specification.bash}/bin/bash
            if [[ -n "''${TVP_PROVIDER_LOG-}" ]]; then printf locale >> "$TVP_PROVIDER_LOG"; fi
            exec ${d.localeTools}/bin/locale "$@"
            SCRIPT
            chmod +x "$out/bin/locale"
          '';
        }
      ];
    }
  );
  ncursesProvider = d.ncurses.edit (
    s:
    s
    // {
      plan = [
        {
          name = "texinfo.ncurses-provider";
          run = ''mkdir "$out"; cp -R ${d.ncurses}/. "$out/"; chmod -R u+w "$out"'';
        }
      ];
    }
  );
  rebound = p.override {
    perl = provider;
    localeTools = localeProvider;
    ncurses = ncursesProvider;
  };

in
p.testContext.mkSuite {
  inherit package;
  tools = [
    d.grep
    d.sed
    d.gawk
    d.findutils
    d.diffutils
  ];
  libraries = [ ];
  tests = {
    upstream = {
      script = ''test -d ${upstream}/nix-support/upstream; printf upstream'';
      expected = "upstream";
    };
    version = {
      script = ''${p}/bin/makeinfo --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' '';
      expected = p.version;
    };

    formats = {
      script = ''
        env -i ${p}/bin/makeinfo ${./fixtures/manual.texi} -o manual.info
        env -i ${p}/bin/texi2any --html --no-split ${./fixtures/manual.texi} -o manual.html
        env -i ${p}/bin/makeinfo --plaintext ${./fixtures/manual.texi} -o manual.txt
        grep -q 'TVP preserves build tools' manual.html
        grep -q 'TVP preserves build tools' manual.txt
        env -i ${p}/bin/info --file=./manual.info --output=read.txt
        grep -q 'TVP preserves build tools' read.txt
        printf ok
      '';
      expected = "ok";
    };
    perl-xs = {
      script = ''
        env -i TEXINFO_XS=debug ${p}/bin/makeinfo --plaintext ${./fixtures/manual.texi} -o manual.txt 2>xs.log
        grep -Fq '${p}/lib/texinfo/Parsetexi.so loaded' xs.log
        grep -Fq '${p}/lib/texinfo/MiscXS.so loaded' xs.log
        env -i TEXINFO_XS=required ${p}/bin/makeinfo --plaintext ${./fixtures/manual.texi} -o required.txt
        cmp manual.txt required.txt
        grep -q 'TVP preserves build tools' required.txt
        printf ok
      '';
      expected = "ok";
    };
    errors = {
      script = ''
        printf '@node Top\n@top Bad\n@unknowncommand{}\n' > invalid.texi
        if env -i TEXINFO_XS=required ${p}/bin/makeinfo invalid.texi -o bad.info >stdout 2>stderr; then exit 1; fi
        grep -q 'unknown command' stderr
        if env -i ${p}/bin/makeinfo missing.texi -o missing.info >stdout 2>stderr; then exit 1; fi
        test -s stderr
        printf errors
      '';
      expected = "errors";
    };
    reader-locale = {
      script = ''
        env -i ${p}/bin/info --version | head -1 | grep -q '${p.version}'
        readelf -d ${p}/bin/info | grep -q 'libncursesw'
        ${p.specification.base.compiler.libc}/lib/ld-linux-x86-64.so.2 --list ${p}/bin/info > linkage
        grep -Fq '${d.ncurses}/lib/libncursesw' linkage
        grep -Fq '${d.localeTools}/bin/locale' ${p}/share/texinfo/Texinfo/Translations.pm
        env -i ${d.localeTools}/bin/locale -a | grep -qx C
        printf reader
      '';
      expected = "reader";
    };
    tex-support = {
      script = ''test -s ${p}/texmf-dist/tex/texinfo/texinfo.tex; printf ok'';
      expected = "ok";
    };

    constructor = {
      expected =
        assert (p.override { }).drvPath == p.drvPath;
        assert (p.edit (s: s)).drvPath == p.drvPath;
        assert !(p ? stdenv) && !(p ? overrideAttrs);
        assert rebound.tests.version.package.outPath == rebound.outPath;
        assert
          ((p.mkTests.override { inherit pkgs; }) rebound).version.drvPath == rebound.tests.version.drvPath;
        assert runtimeChanged.drvPath != p.drvPath;
        "qualified";
      script = ''
        test -s ${sourceProbe}/source-marker
        test "$(cat ${outputChanged}/nix-support/custom-output)" = edited
        ${runtimeChanged}/bin/makeinfo --version >&2
        readelf -d ${runtimeChanged}/bin/info | grep -Fq '${d.python}/lib'
        env -i TVP_PROVIDER_LOG="$PWD/provider" TEXINFO_XS=required ${rebound}/bin/makeinfo --plaintext ${./fixtures/manual.texi} -o rebound.txt
        test -s provider
        # Exercise the selected locale executable through the installed module.
        env -i TVP_PROVIDER_LOG="$PWD/locale-calls" ${provider}/bin/perl -I${rebound}/share/texinfo -MTexinfo::ModulePath -e 'Texinfo::ModulePath::init($ARGV[0],$ARGV[1],$ARGV[0], "installed" => 1); require Texinfo::Translations; Texinfo::Translations::_switch_messages_locale();' ${rebound}/share/texinfo ${rebound}/lib/texinfo 2>locale.err || { cat locale.err >&2; exit 1; }
        test -s locale-calls
        ${p.specification.base.compiler.libc}/lib/ld-linux-x86-64.so.2 --list ${rebound}/bin/info > rebound-linkage
        grep -Fq '${ncursesProvider}/lib/libncursesw' rebound-linkage
        grep -q 'TVP preserves build tools' rebound.txt
        printf qualified
      '';
    };
  };
}

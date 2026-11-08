{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  p = package;
  d = p.tvp.deps;
  # Configure-time discovery belongs to this upstream test variant only.
  upstream =
    (p.edit (
      s:
      s
      // {
        environment = s.environment // {
          tools = s.environment.tools ++ [ p.tvp.declaredTestDependencies.bison ];
        };
      }
    )).editSteps
      (
        tvp.builder.steps.insertAfter "flex.build" [
          (
            (p.specification.base.environment (
              p.specification.environment
              // {
                tools = p.specification.environment.tools ++ [
                  d.gnutar
                  d.gzip
                  p.tvp.declaredTestDependencies.bison
                ];
              }
            ))
            // {
              name = "flex.upstream";
              cwd = "source";
              run = ''
                export CONFIG_SHELL=${p.specification.bash}/bin/bash SHELL=${p.specification.bash}/bin/bash
                status=0
                ${d.gnumake}/bin/make -j"$NIX_BUILD_CORES" TESTSUITEFLAGS="-j$NIX_BUILD_CORES" check || status=$?
                find . \( -name '*suite.log' -o -name 'test-suite.log' \) -exec cat {} \; >&2
                if (( status )); then exit "$status"; fi
                mkdir -p "$out/nix-support/upstream"
                find . \( -name '*.log' -o -name '*.trs' \) | while read -r file; do
                  mkdir -p "$out/nix-support/upstream/$(dirname "$file")"
                  cp "$file" "$out/nix-support/upstream/$file"
                done
              '';
            }
          )
        ]
      );
  skeleton = p.editSteps (plan: [
    (builtins.head plan)
    {
      name = "flex.skeleton-fixture";
      cwd = "source";
      tools = [
        d.sed
        d.m4
      ];
      # Upstream mkskel.sh first preprocesses m4preproc_ directives; --skel
      # consumes that intermediate text, not the unprocessed source template.
      run = ''
        mkdir "$out"
        printf '/* TVP custom skeleton */\n' > "$out/custom.skl"
        ${d.sed}/bin/sed 's/4_/a4_/g; s/m4preproc_/m4_/g' src/flex.skl |
          ${d.m4}/bin/m4 -P -I src -DFLEX_MAJOR_VERSION=2 -DFLEX_MINOR_VERSION=6 -DFLEX_SUBMINOR_VERSION=4 |
          ${d.sed}/bin/sed '/^%#/d; s/m4_/m4preproc_/g; s/a4_/4_/g' >> "$out/custom.skl"
      '';
    }
  ]);
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
            (builtins.head s.plan)
            (
              (base.environment s.environment)
              // {
                name = "flex.source-base";
                run = ''
                  test "$(cat source/marker)" = 'alternate source'
                  printf 'int main(void) { return 0; }\n' > probe.c
                  "$CC" probe.c -o probe
                  "$CXX" -x c++ probe.c -o probe-cxx
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
  optionsChanged = p.override { configureFlags = [ "--disable-nls" ]; };
  factoryChanged = (p.mkTests.override { inherit pkgs; }) rebound;
  outputChanged = p.editSteps (
    tvp.builder.steps.append [
      {
        name = "flex.output-control";
        run = ''printf edited > "$out/nix-support/custom-output"'';
      }
    ]
  );
  macroProvider = d.m4.edit (
    s:
    s
    // {
      plan = [
        {
          name = "m4.provider";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/m4" <<'SCRIPT'
            #!${p.specification.bash}/bin/bash
            if [[ -n "''${TVP_PROVIDER_LOG-}" ]]; then printf 'selected-m4\n' >> "$TVP_PROVIDER_LOG"; fi
            exec ${d.m4}/bin/m4 "$@"
            SCRIPT
            chmod +x "$out/bin/m4"
          '';
        }
      ];
    }
  );
  rebound = p.override { m4 = macroProvider; };

in
p.testContext.mkSuite {
  inherit package;
  tools = [
    d.grep
    d.sed
    d.gawk
  ];
  libraries = [ p ];
  tests = {
    version = {
      script = ''flex --version | awk 'NR==1 {print $NF}' '';
      expected = p.version;
    };
    upstream = {
      script = ''test -d ${upstream}/nix-support/upstream; printf upstream'';
      expected = "upstream";
    };
    scanner = {
      script = ''
        PATH=${p}/bin flex ${./fixtures/scanner.l}
        "$CC" lex.yy.c -o scanner
        printf '20 22\n' | env -i ./scanner
        if printf 'invalid\n' | env -i ./scanner; then exit 1; fi
      '';
      expected = "42";
    };
    cxx = {
      script = ''
        flex --c++ ${./fixtures/scanner.l}
        "$CXX" lex.yy.cc -o scanner
        printf '20 22\n' | env -i ./scanner
      '';
      expected = "42";
    };
    bison = {
      tools = [
        p.tvp.declaredTestDependencies.bison
        d.grep
      ];
      script = ''
        bison -d ${./fixtures/calc.y} -o calc.c
        flex -o scanner.c ${./fixtures/calc.l}
        "$CC" calc.c scanner.c -o calc
        printf '20 + 22\n' | env -i ./calc
        if printf '20 + nope\n' | env -i ./calc >bad.out 2>bad.err; then exit 1; fi
        grep -q 'syntax error' bad.err
      '';
      expected = "42";
    };
    libfl = {
      script = ''
        test -s ${p}/include/FlexLexer.h; test -s ${p}/lib/libfl.la
        flex ${./fixtures/library.l}
        "$CC" lex.yy.c -lfl -o shared
        printf '42\n' | env -i ./shared
        readelf -d shared | grep -Fq '[libfl.so.2]'
        readelf -d shared | grep -Fq '${p}/lib'
        "$CC" lex.yy.c ${p}/lib/libfl.a -o static
        printf '42\n' | env -i ./static
        if readelf -d static | grep -q libfl.so; then exit 1; fi
        readelf -d ${p}/lib/libfl.so > lib.elf
        grep -Fq '${p.specification.base.compiler.libc}/lib' lib.elf
      '';
      expected = "42\n42";
    };
    reentrant = {
      script = ''
        flex --reentrant --prefix=tvp --header-file=scanner.h -o scanner.c ${./fixtures/reentrant.l}
        "$CC" scanner.c ${./fixtures/reentrant.c} -I. -o scanner
        env -i ./scanner
      '';
      expected = "42";
    };
    overrides = {
      script = ''
        cat > m4 <<'SCRIPT'
        #!${p.specification.bash}/bin/bash
        printf used >> "$TVP_PROVIDER_LOG"
        exec ${d.m4}/bin/m4 "$@"
        SCRIPT
        chmod +x m4
        M4="$PWD/m4" TVP_PROVIDER_LOG="$PWD/calls" flex -o scanner.c ${./fixtures/scanner.l}
        test -s calls
        flex --skel=${skeleton}/custom.skl -o custom.c ${./fixtures/scanner.l}
        grep -q 'TVP custom skeleton' custom.c
        "$CC" custom.c -o custom
        printf '20 22\n' | env -i ./custom >&2
        if flex --skel=missing.skl ${./fixtures/scanner.l} >bad.out 2>bad.err; then exit 1; fi
        test -s bad.err
        printf overrides
      '';
      expected = "overrides";
    };
    constructor = {
      expected =
        assert (p.override { }).drvPath == p.drvPath;
        assert (p.edit (s: s)).drvPath == p.drvPath;
        assert rebound.tests.version.package.outPath == rebound.outPath;
        assert !(p ? stdenv) && !(p ? overrideAttrs);
        assert factoryChanged.version.package.outPath == rebound.outPath;
        assert factoryChanged.version.drvPath == rebound.tests.version.drvPath;
        assert runtimeChanged.drvPath != p.drvPath;
        "qualified";
      script = ''
        ${optionsChanged}/bin/flex --version >&2
        test ! -d ${optionsChanged}/share/locale
        test -s ${sourceProbe}/source-marker
        test "$(cat ${outputChanged}/nix-support/custom-output)" = edited
        ${runtimeChanged}/bin/flex --version >&2
        readelf -d ${runtimeChanged}/bin/flex | grep -Fq '${d.python}/lib'
        env -u M4 TVP_PROVIDER_LOG="$PWD/provider" ${rebound}/bin/flex -o rebound.c ${./fixtures/scanner.l}
        grep -qx selected-m4 provider
        "$CC" rebound.c -o rebound; printf '20 22\n' | env -i ./rebound >&2
        printf qualified
      '';
    };

  };
}

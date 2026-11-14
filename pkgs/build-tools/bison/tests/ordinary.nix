{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  p = package;
  d = p.tvp.deps;
  upstream =
    (p.edit (
      s:
      s
      // {
        environment = s.environment // {
          tools = s.environment.tools ++ [
            p.tvp.declaredTestDependencies.flex
            p.specification.testAutoconf
          ];
        };
      }
    )).editSteps
      (
        tvp.builder.steps.insertAfter "bison.build" [
          (
            (p.specification.base.environment (
              p.specification.environment
              // {
                tools = p.specification.environment.tools ++ [
                  p.specification.testAutoconf
                  d.gnutar
                  d.gzip
                  p.tvp.declaredTestDependencies.flex
                  d.perl
                ];
              }
            ))
            // {
              name = "bison.upstream";
              cwd = "source";
              run = ''
                    export CONFIG_SHELL=${p.specification.bash}/bin/bash SHELL=${p.specification.bash}/bin/bash
                    ${
                      pkgs.lib.optionalString (
                        p.specification.upstreamPrerequisites != [ ]
                      ) "${d.gnumake}/bin/make ${pkgs.lib.escapeShellArgs p.specification.upstreamPrerequisites}"
                    }
                status=0
                    ${d.gnumake}/bin/make -j"$NIX_BUILD_CORES" TESTSUITEFLAGS="-j$NIX_BUILD_CORES" check || status=$?
                    find . \( -name '*suite.log' -o -name 'test-suite.log' \) -exec cat {} \; >&2
                    if (( status )); then exit "$status"; fi
                    mkdir -p "$out/nix-support/upstream"
                    printf 'Raw upstream logs are retained in the Nix build log.\n' > "$out/nix-support/upstream/notice"
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
        (builtins.removeAttrs s [ "artifactName" ])
        // {
          inherit base;
          plan = [
            (builtins.head s.plan)
            (
              (base.environment s.environment)
              // {
                name = "bison.source-base";
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
        name = "bison.output-control";
        run = ''printf edited > "$out/nix-support/custom-output"'';
      }
    ]
  );
  macroProvider = d.m4.edit (
    s:
    (builtins.removeAttrs s [ "artifactName" ])
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
  libraries = [ ];
  tests = {
    version = {
      script = ''bison --version | awk 'NR==1 {print $NF}' '';
      expected = p.version;
    };
    upstream = {
      script = ''test -d ${upstream}/nix-support/upstream; printf upstream'';
      expected = "upstream";
    };
    parser = {
      script = ''
        PATH=${p}/bin bison --defines=calc.h --report=all --report-file=calc.report ${./fixtures/calc.y} -o calc.c
        test -s calc.h; test -s calc.report
        printf '#include "calc.h"\nint main(void) { return NUMBER <= 0; }\n' > header.c
        "$CC" header.c -o header; env -i ./header
        "$CC" calc.c -o calc; env -i ./calc
      '';
      expected = "42";
    };
    cxx = {
      script = ''
        bison --defines=calc.hh ${./fixtures/calc.yy} -o calc.cc
        "$CXX" calc.cc -o calc; env -i ./calc
      '';
      expected = "42";
    };
    yacc = {
      script = ''yacc ${./fixtures/calc.y}; "$CC" y.tab.c -o calc; env -i ./calc'';
      expected = "42";
    };
    overrides-errors = {
      script = ''
        mkdir data; cp -R ${p}/share/bison/. data/
        BISON_PKGDATADIR="$PWD/data" bison -S "$PWD/data${pkgs.lib.removePrefix "share/bison" p.specification.skeletonDirectory}/yacc.c" ${./fixtures/calc.y} -o custom.c
        "$CC" custom.c -o custom; env -i ./custom >&2
        cat > m4 <<'SCRIPT'
        #!${p.specification.bash}/bin/bash
        printf used >> "$TVP_PROVIDER_LOG"
        exec ${d.m4}/bin/m4 "$@"
        SCRIPT
        chmod +x m4
        M4="$PWD/m4" TVP_PROVIDER_LOG="$PWD/calls" bison ${./fixtures/calc.y} -o override.c
        test -s calls
        printf '%%%%\ninvalid: ; invalid !\n' > malformed.y
        if bison malformed.y >bad.out 2>bad.err; then exit 1; fi
        test -s bad.err
        sed "s/case 1: return '+';/case 1: return '-';/" ${./fixtures/calc.y} > reject.y
        bison reject.y -o reject.c; "$CC" reject.c -o reject
        if env -i ./reject >stdout 2>stderr; then exit 1; fi
        grep -q 'syntax error' stderr
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
        ${optionsChanged}/bin/bison --version >&2
        test ! -d ${optionsChanged}/share/locale
        test -s ${sourceProbe}/source-marker
        test "$(cat ${outputChanged}/nix-support/custom-output)" = edited
        ${runtimeChanged}/bin/bison --version >&2
        readelf -d ${runtimeChanged}/bin/bison | grep -Fq '${d.python}/lib'
        env -u M4 TVP_PROVIDER_LOG="$PWD/provider" ${rebound}/bin/bison ${./fixtures/calc.y} -o rebound.c
        grep -qx selected-m4 provider
        "$CC" rebound.c -o rebound; env -i ./rebound >&2
        printf qualified
      '';
    };

  };
}

// {
  split = import ./ordinary-split.nix { inherit package; };
}

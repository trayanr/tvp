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
    tvp.builder.steps.insertAfter "gzip.build" [
      (
        (p.specification.base.environment p.specification.environment)
        // {
          name = "gzip.upstream";
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
                name = "gzip.source-base";
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
        name = "gzip.output-control";
        run = ''printf edited > "$out/nix-support/custom-output"'';
      }
    ]
  );
  provider = d.grep.edit (
    s:
    s
    // {
      plan = [
        {
          name = "gzip.provider";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/grep" <<'SCRIPT'
            #!${p.specification.bash}/bin/bash
            if [[ -n "''${TVP_PROVIDER_LOG-}" ]]; then printf selected >> "$TVP_PROVIDER_LOG"; fi
            exec ${d.grep}/bin/grep "$@"
            SCRIPT
            chmod +x "$out/bin/grep"
          '';
        }
      ];
    }
  );
  shellProvider = d.grep.edit (
    s:
    s
    // {
      plan = [
        {
          name = "gzip.shell-provider";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/bash" <<'SCRIPT'
            #!${d.bash}/bin/bash
            if [[ -n "''${TVP_SHELL_LOG-}" ]]; then printf shell >> "$TVP_SHELL_LOG"; fi
            exec ${d.bash}/bin/bash "$@"
            SCRIPT
            chmod +x "$out/bin/bash"
          '';
        }
      ];
    }
  );
  pagerProvider = d.pager.edit (
    s:
    s
    // {
      plan = [
        {
          name = "gzip.pager-provider";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/less" <<'SCRIPT'
            #!${p.specification.bash}/bin/bash
            if [[ -n "''${TVP_PAGER_LOG-}" ]]; then printf pager >> "$TVP_PAGER_LOG"; fi
            exec ${d.pager}/bin/less "$@"
            SCRIPT
            chmod +x "$out/bin/less"
          '';
        }
      ];
    }
  );
  pagerRebound = p.override { pager = pagerProvider; };
  rebound = p.override {
    grep = provider;
    bash = shellProvider;
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
      script = ''${p}/bin/gzip --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' '';
      expected = p.version;
    };

    helpers = {
      script = ''for helper in ${p}/bin/*; do test -x "$helper"; basename "$helper"; done | LC_ALL=C sort'';
      expected = "gunzip\ngzexe\ngzip\nuncompress\nzcat\nzcmp\nzdiff\nzegrep\nzfgrep\nzforce\nzgrep\nzless\nzmore\nznew";
    };
    operation = {
      script = ''
        printf preserved | env -i ${p}/bin/gzip -n > sample.gz
        env -i ${p}/bin/gzip -t sample.gz
        env -i ${p}/bin/gunzip -c sample.gz
        env -i ${p}/bin/zcat sample.gz > actual; test "$(cat actual)" = preserved
        env -i ${p}/bin/uncompress -c sample.gz > actual; test "$(cat actual)" = preserved
        printf garbage > invalid.gz
        head -c 12 sample.gz > truncated.gz
        for file in invalid.gz truncated.gz; do
          if env -i ${p}/bin/gzip -t "$file" 2>error; then exit 1; fi
          test -s error
        done
      '';
      expected = "preserved";
    };
    zgrep-pin = {
      script = ''grep -Fq '${d.grep}/bin/grep' ${p}/bin/zgrep; printf pinned'';
      expected = "pinned";
    };
    zgrep = {
      script = ''
        printf 'before\npreserved\nafter\n' | gzip -n > lines.gz
        env -i ${p}/bin/zgrep '^preserved$' lines.gz
        env -i ${p}/bin/zegrep 'pre(served|fix)' lines.gz > actual; test "$(cat actual)" = preserved
        env -i ${p}/bin/zfgrep 'preserved' lines.gz > actual; test "$(cat actual)" = preserved
        env -i ${p}/bin/zgrep -n -e preserved lines.gz > actual; test "$(cat actual)" = 2:preserved
        if env -i ${p}/bin/zgrep missing lines.gz; then exit 1; else test "$?" = 1; fi
        if env -i ${p}/bin/zgrep -r x lines.gz 2>error; then exit 1; else test "$?" = 2; fi
      '';
      expected = "preserved";
    };
    zmore = {
      script = ''
        printf 'preserved\n' > plain; gzip -nc plain > plain.gz
        env -i PAGER=${d.coreutils}/bin/cat ${p}/bin/zmore plain.gz
        env -i PAGER=${d.coreutils}/bin/cat ${p}/bin/zmore plain
        env -i PAGER='${d.coreutils}/bin/cat -n' ${p}/bin/zmore < plain.gz
      '';
      expected = "preserved\npreserved\n     1\tpreserved";
    };
    helper-behavior = {
      script = ''
        printf 'preserved\n' > a; gzip -nc a > a.gz; cp a.gz b.gz
        env -i ${p}/bin/zcmp a.gz b.gz
        env -i ${p}/bin/zdiff a.gz b.gz
        printf 'different\n' | gzip -n > b.gz
        if env -i ${p}/bin/zcmp a.gz b.gz >different; then exit 1; else test "$?" = 1; fi
        if env -i ${p}/bin/zdiff a.gz b.gz >different; then exit 1; else test "$?" = 1; fi
        cp a.gz force; env -i ${p}/bin/zforce force >&2
        test -f force.gz
        # Upstream znew accepts gzip input as well as compress input. This proves
        # its replacement/verification path, not an unavailable .Z encoder.
        cp a.gz new.Z; env -i ${p}/bin/znew -f -t new.Z >&2
        env -i ${p}/bin/gzip -t new.gz
        printf '#!${p.specification.bash}/bin/bash\nprintf executable\n' > executable
        chmod +x executable
        env -i ${p}/bin/gzexe executable >&2
        test "$(env -i ./executable)" = executable
        env -i ${p}/bin/gzexe -d executable >&2
        test "$(env -i ./executable)" = executable
        env -i ${p}/bin/zless --version | head -1 | grep -q 'zless (gzip)'
        for name in gunzip zcat gzexe zcmp zdiff zegrep zfgrep zforce zgrep zless zmore znew uncompress; do
          test "$(head -1 ${p}/bin/$name)" = '#!${p.specification.bash}/bin/bash'
        done
        printf helpers
      '';
      expected = "helpers";
    };

    zless = {
      script = ''
        printf 'preserved\n' > 'name with spaces'
        ${p}/bin/gzip -nc 'name with spaces' > 'name with spaces.gz'
        env -i PATH=/nonexistent ${p}/bin/zless 'name with spaces.gz' > actual 2> error
        test ! -s error; cmp actual 'name with spaces'
        env -i PATH=/nonexistent ${p}/bin/zless -F -X 'name with spaces.gz' > actual 2> error
        test ! -s error; cmp actual 'name with spaces'
        env -i PATH=/nonexistent ${p}/bin/zmore 'name with spaces.gz' > actual 2> error
        test ! -s error; cmp actual 'name with spaces'
        if env -i PATH=/nonexistent ${p}/bin/zless missing.gz > actual 2> error; then exit 1; fi
        test -s error
        head -c 12 'name with spaces.gz' > truncated.gz
        if env -i PATH=/nonexistent ${p}/bin/zless truncated.gz > actual 2> error; then exit 1; fi
        test -s error
        env -i PATH=/nonexistent TVP_PAGER_LOG="$PWD/pager" ${pagerRebound}/bin/zless 'name with spaces.gz' > actual 2> error
        test ! -s error; cmp actual 'name with spaces'; grep -Eq '^(pager)+$' pager
        printf complete
      '';
      expected = "complete";
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
        ${runtimeChanged}/bin/gzip --version >&2
        readelf -d ${runtimeChanged}/bin/gzip | grep -Fq '${d.python}/lib'
        printf 'preserved\n' | gzip -n > lines.gz
        env -i TVP_SHELL_LOG="$PWD/shell" TVP_PROVIDER_LOG="$PWD/provider" ${rebound}/bin/zgrep preserved lines.gz > actual
        test "$(cat actual)" = preserved; grep -Eq '^(selected)+$' provider; grep -Eq '^(shell)+$' shell
        test "$(head -1 ${rebound}/bin/zgrep)" = '#!${shellProvider}/bin/bash'
        printf qualified
      '';
    };
  };
}

{
  package,
  lib,
  context,
}:
let
  deps = package.tvp.deps;
  runtimeProvider =
    dependency:
    let
      matches = builtins.filter (
        p: (p.pname or null) == dependency.pname
      ) package.specification.runtime.libraries;
    in
    if builtins.length matches == 1 then
      builtins.head matches
    else
      throw "PHP: expected one runtime provider for ${dependency.pname}";
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  has =
    needle: value:
    let
      text = builtins.unsafeDiscardStringContext value;
    in
    builtins.replaceStrings [ (builtins.unsafeDiscardStringContext needle) ] [ "" ] text != text;
  runtimeContract =
    dependency: testName:
    let
      original = runtimeProvider dependency;
      replacement = original.editSteps (
        xs:
        xs
        ++ [
          {
            name = "contract.runtime-provider";
            run = "true";
          }
        ]
      );
      edited = package.editRuntime (
        r:
        r
        // {
          libraries = map (
            provider: if provider.outPath == original.outPath then replacement else provider
          ) r.libraries;
        }
      );
      rpaths = (step "output.rpaths" edited).run;
      test = edited.tests.${testName};
      expectation = (step "test.compare" test).run;
    in
    has replacement.outPath rpaths
    && !(has original.outPath rpaths)
    && has replacement.outPath expectation
    && !(has original.outPath expectation)
    && test.package.outPath == edited.outPath;
  missingRuntime = package.editRuntime (
    r:
    r
    // {
      libraries = builtins.filter (provider: (provider.pname or null) != deps.openssl.pname) r.libraries;
    }
  );
  duplicateRuntime = package.editRuntime (
    r:
    r
    // {
      libraries = r.libraries ++ [ (runtimeProvider deps.openssl) ];
    }
  );

  consumerStandard = package.tvp.features.consumerCStandard or null;
  configureEnv = lib.optionalString (
    consumerStandard != null
  ) "CFLAGS=\"\${CFLAGS:--g -O2} -std=${consumerStandard}\" ";

  # sha256("tvp"), first 16 hex characters.
  currentCommand = q: builtins.head (builtins.filter (s: s ? env && s.env ? CC) q.buildSteps);
  altered = package.edit (
    s:
    s
    // {
      meta = s.meta // {
        description = "selected";
      };
    }
  );
  marker = package.edit (
    s:
    builtins.removeAttrs s [ "artifactName" ]
    // {
      plan = [
        {
          name = "php.marker";
          run = "mkdir $out; printf selected > $out/marker";
        }
      ];
    }
  );
  runtimeControl = (package.editRuntime (r: r // { libraries = [ deps.zlib ]; })).edit (
    s:
    builtins.removeAttrs s [ "artifactName" ]
    // {
      plan = [
        (
          (s.base.environment {
            tools = [ ];
            libraries = s.runtime.libraries;
          })
          // {
            name = "php.runtime-provider-control";
            run = ''
              mkdir -p "$out/bin"
              printf '#include <zlib.h>\n#include <stdio.h>\nint main(void) { puts(zlibVersion()); }\n' > control.c
              "$CC" control.c -lz -o "$out/bin/control"
            '';
          }
        )
      ];
    }
  );
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  contracts = {
    noop = (package.override { }).drvPath == package.drvPath;
    metadata = altered.meta.description == "selected";
    tests = altered.tests.version.package.outPath == altered.outPath;
    factory =
      ((package.mkTests.override { tests = import ./installed.nix; }) altered).version.package.outPath
      == altered.outPath;
    source =
      (builtins.head (package.override { src = builtins.toFile "php-source-probe" "probe"; }).buildSteps)
      .run != (builtins.head package.buildSteps).run;
    environment =
      (currentCommand (
        package.edit (
          s:
          s
          // {
            environment = s.environment // {
              overrides.values.PHP_CONTRACT = "selected";
            };
          }
        )
      )).env.PHP_CONTRACT == "selected";
    unknown = rejects (package.override { unknownDependency = package; }).drvPath;
    feature = !((package.override { testFeatures.passwordApi = false; }).tvp.features.passwordApi);
    provider =
      (package.override {
        openssl = deps.openssl.editSteps (
          xs:
          xs
          ++ [
            {
              name = "provider.control";
              run = "true";
            }
          ]
        );
      }).drvPath != package.drvPath;
    opensslRuntime = runtimeContract deps.openssl "openssl-linkage";
    zlibRuntime = runtimeContract deps.zlib "zlib-linkage";
    sqliteRuntime = runtimeContract deps.sqlite "sqlite-linkage";
    readlineRuntime = runtimeContract deps.readline "readline-linkage";
    xmlRuntime = runtimeContract deps.libxml2 "xml-linkage";
    ncursesRuntime = runtimeContract deps.ncurses "ncurses-linkage";
    missingRuntime = rejects (step "test.compare" missingRuntime.tests.openssl-linkage).run;
    duplicateRuntime = rejects (step "test.compare" duplicateRuntime.tests.openssl-linkage).run;
  };

in
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = package.specification.environment.tools ++ [
    package.specification.base.compiler.bintools
    package.specification.base.standardTools.python
  ];
  tests = {
    constructor =
      assert builtins.all (x: x) (builtins.attrValues contracts);
      {
        script = ''
          test "$(cat ${marker}/marker)" = selected
          test "$(env -i ${runtimeControl}/bin/control)" = '${deps.zlib.version}'
          printf qualified
        '';
        expected = "qualified";
      };
    runtime-elf = {
      script = ''
        readelf -l ${package}/bin/php > program-headers
        grep -F '${package.specification.base.compiler.libc}/lib/ld-linux-x86-64.so.2' program-headers >/dev/null
        readelf -d ${package}/bin/php > dynamic
        readelf -W -l ${package}/bin/php | grep 'GNU_STACK' | grep -vq 'RWE'
        env -i ${package}/bin/php -r 'echo PHP_VERSION;' > version
        test -s version
        printf elf-ok
      '';
      expected = "elf-ok";
    };
  };
}

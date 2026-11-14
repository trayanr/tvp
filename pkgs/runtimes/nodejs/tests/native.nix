{
  pkgs,
  tvpLib,
  package,
}:
let
  deps = package.tvp.deps;
  runtimeProvider =
    dependency:
    let
      matches = builtins.filter (
        provider: (provider.pname or null) == dependency.pname
      ) package.specification.runtime.libraries;
    in
    if builtins.length matches == 1 then
      builtins.head matches
    else
      throw "TVP: expected exactly one runtime provider for ${dependency.pname}";
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
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  marker = package.editSteps (_: [
    {
      name = "nodejs.marker";
      run = "mkdir $out; printf selected > $out/marker";
    }
  ]);
  shell =
    (package.editRuntime (r: r // { shell = package.tvp.declaredTestDependencies.shell; })).edit
      (
        s:
        s
        // {
          plan = [
            {
              name = "nodejs.shell-control";
              run =
                "mkdir $out; "
                + s.runtime.shell.outPath
                + "/bin/bash -c 'test \"$BASH\" = "
                + s.runtime.shell.outPath
                + "/bin/bash; printf selected' > $out/shell";
            }
          ];
        }
      );
  sentinel = (import ../../../../bases/source-gnu/tests/probes.nix { }).sentinel;
  compilerControl = package.edit (s: s // { base = s.base.override { compiler = sentinel; }; });
  contracts = {
    noop = (package.override { }).drvPath == package.drvPath;
    opensslRuntime = runtimeContract deps.openssl "libraries";
    zlibRuntime = runtimeContract deps.zlib "libraries";
    missingRuntime = rejects (step "test.compare" missingRuntime.tests.libraries).run;
    duplicateRuntime = rejects (step "test.compare" duplicateRuntime.tests.libraries).run;
    tests = marker.tests.version.package.outPath == marker.outPath;
    factory =
      ((package.mkTests.override { inherit pkgs; }) marker).version.package.outPath == marker.outPath;
    source =
      (builtins.head (package.override { src = builtins.toFile "node-source-probe" "probe"; }).buildSteps)
      .run != (builtins.head package.buildSteps).run;
    provider = (package.override { openssl = deps.zlib; }).drvPath != package.drvPath;
    shell =
      (package.editRuntime (r: r // { shell = package.tvp.declaredTestDependencies.shell; })).drvPath
      != package.drvPath;
    compilerSelected =
      (builtins.head (builtins.filter (s: s ? env && s.env ? CC) compilerControl.buildSteps)).env.CC
      == "${sentinel}/bin/cc";
    compiler =
      (package.edit (s: s // { base = s.base.override { compiler = s.base.compiler; }; })).drvPath
      == package.drvPath;
  };
in
(package.testContext.mkSuite {
  inherit package;
  tools = [
    package.tvp.deps.grep
    package.tvp.deps.binutils
  ];
  libraries = [ package ];
  tests = {
    constructor =
      assert builtins.all (x: x) (builtins.attrValues contracts);
      {
        script = ''test "$(cat ${marker}/marker)" = selected; test "$(cat ${shell}/shell)" = selected; printf qualified'';
        expected = "qualified";
      };
    runtime-elf = {
      script = ''
        readelf -l ${package}/bin/node > program-headers
        grep -F '${package.specification.base.compiler.libc}/lib/ld-linux-x86-64.so.2' program-headers >/dev/null
        readelf -d ${package}/bin/node > dynamic
        readelf -W -l ${package}/bin/node | grep 'GNU_STACK' | grep -vq 'RWE'
        env -i ${package}/bin/node --version > version
        test -s version
        printf elf-ok
      '';
      expected = "elf-ok";
    };
    version = {
      script = ''node --version'';
      expected = "v${package.version}";
    };
    runtime = {
      script = ''node ${./fixtures/runtime.js}'';
      expected = "runtime-ok";
    };
    shell = {
      script = ''env -i ${package}/bin/node ${./fixtures/shell.js} '${package.specification.runtime.shell}/bin/bash' '';
      expected = "shell-ok";
    };
    addon = {
      script = ''
        cc -shared -fPIC -I${package}/include/node ${./fixtures/addon.c} -o answer.node
        node -e 'if(require("./answer.node").answer()!==42) throw Error("N-API"); console.log("addon-ok")'
      '';
      expected = "addon-ok";

    };
    npm = {
      tools = [
        deps.grep
        deps.python
      ];
      script = ''
        test ! -x ${package}/lib/node_modules/npm/node_modules/node-gyp/gyp/gyp_main.py
        ${deps.python}/bin/python3 ${package}/lib/node_modules/npm/node_modules/node-gyp/gyp/gyp_main.py --help > gyp-help
        test -s gyp-help
        for entry in npm npx; do
          head -n1 ${package}/bin/$entry | grep -Fx '#!${package}/bin/node' > /dev/null
        done
        export npm_config_cache="$PWD/cache" npm_config_offline=true npm_config_audit=false npm_config_fund=false
        printf '%s\n' '{"name":"offline-consumer","version":"1.0.0","scripts":{"test":"node -e \"console.log(42)\""}}' > package.json
        npm install --offline --ignore-scripts > install.log
        npm test --silent
      '';
      expected = "42";
    };
    libraries = {
      script = ''
        LD_TRACE_LOADED_OBJECTS=1 ${package}/bin/node > linked
        grep -F '${runtimeProvider deps.openssl}/lib/libssl' linked >/dev/null
        grep -F '${runtimeProvider deps.zlib}/lib/libz' linked >/dev/null
        printf owned
      '';
      expected = "owned";
    };
  };
}) // { upstream = import ./upstream.nix { inherit package; }; }

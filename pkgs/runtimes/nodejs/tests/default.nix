{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''node --version'';
      expected = "v${package.version}";
    };
    runtime = {
      script = ''node ${./fixtures/runtime.js}'';
      expected = "runtime-ok";
    };
    shell = {
      script = ''node ${./fixtures/shell.js} '${package.tvp.deps.bash}/bin/bash' '';
      expected = "shell-ok";
    };
    addon = {
      script = ''
        cc -shared -fPIC -I${package}/include/node ${./fixtures/addon.c} -o answer.node
        node -e 'if(require("./answer.node").answer()!==42) throw Error("N-API"); console.log("addon-ok")'
      '';
      expected = "addon-ok";
      extraInputs = [ package.tvp.cc ];
    };
    npm = {
      script = ''
        export npm_config_cache="$PWD/cache" npm_config_offline=true npm_config_audit=false npm_config_fund=false
        printf '%s\n' '{"name":"offline-consumer","version":"1.0.0","scripts":{"test":"node -e \"console.log(42)\""}}' > package.json
        npm install --offline --ignore-scripts > install.log
        npm test --silent
      '';
      expected = "42";
    };
    libraries = {
      script = ''
        ldd ${package}/bin/node > linked
        grep -F '${package.tvp.deps.openssl}/lib/libssl' linked >/dev/null
        grep -F '${package.tvp.deps.zlib}/lib/libz' linked >/dev/null
        printf owned
      '';
      expected = "owned";
    };
  };
}

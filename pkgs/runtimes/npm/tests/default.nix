{ context, package, ... }:
context.mkSuite {
  inherit package;
  tests = {
    version = {
      script = ''
        npm_version=$(env -i ${package}/bin/npm --version)
        npx_version=$(env -i ${package}/bin/npx --version)
        printf '%s %s\n' "$npm_version" "$npx_version"
      '';
      expected = "${package.version} ${package.version}";
    };
    offline-lifecycle = {
      script = ''
        export HOME="$PWD/home"
        export npm_config_cache="$PWD/cache" npm_config_offline=true npm_config_audit=false npm_config_fund=false
        mkdir -p "$HOME"
        cat > package.json <<'JSON'
        {"name":"offline-consumer","version":"1.0.0","scripts":{"check":"node -p 'process.execPath'"}}
        JSON
        ${package}/bin/npm install --offline --ignore-scripts > install.log
        ${package}/bin/npm run --silent check
      '';
      expected = "${package.specification.runtime.nodejs}/bin/node";
    };
  };
}

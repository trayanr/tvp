{
  package,
  context,
  ...
}:
let
  python = package.tvp.declaredTestDependencies.python;
in
context.mkSuite {
  inherit package;
  tools = [ python ];
  tests = {
    version = {
      script = ''
        export GRYPE_CHECK_FOR_APP_UPDATE=false GRYPE_DB_AUTO_UPDATE=false
        grype version --output json > version.json
        ${python}/bin/python3 -B -c 'import json; print(json.load(open("version.json"))["version"])'
      '';
      expected = package.version;
    };
    offline-config = {
      script = ''
        export GRYPE_CHECK_FOR_APP_UPDATE=false GRYPE_DB_AUTO_UPDATE=false
        grype config --load > config.yaml
        ${python}/bin/python3 -B - <<'PY'
        from pathlib import Path
        text = Path("config.yaml").read_text()
        assert "check-for-app-update: false" in text
        assert "auto-update: false" in text
        assert Path("${package.runtime.certificates}/etc/ssl/certs/ca-bundle.crt").is_file()
        print("offline-config-ok")
        PY
      '';
      expected = "offline-config-ok";
    };
  };
}

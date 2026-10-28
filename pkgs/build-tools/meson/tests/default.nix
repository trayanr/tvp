{
  pkgs,
  tvpLib,
  package,
  zlib,
}:
let
  consumer = pkgs.stdenv.mkDerivation {
    name = "meson-consumer";
    src = ./fixtures;
    nativeBuildInputs = [ package ];
    buildInputs = [ zlib ];
    doCheck = true;
    postInstall = ''"$out/bin/answer" > "$out/result"'';
  };
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = "meson --version";
      expected = package.version;
    };
    phases = {
      script = ''cat ${consumer}/result'';
      expected = "42";
    };
    introspection = {
      script = ''
        meson setup build ${./fixtures/standalone} >&2
        meson introspect --targets build > info.json
        ${package.tvp.deps.python}/bin/python3 -c 'import json; d=json.load(open("info.json")); assert any(t["name"] == "answer" and t["type"] == "executable" for t in d); print(42)'
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
    standalone = {
      script = ''
        cp -R ${./fixtures/standalone} project
        chmod -R u+w project
        meson setup build project >&2
        meson compile -C build >&2
        meson test -C build --print-errorlogs >&2
        ./build/answer
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
    wrap-archive = {
      script = ''
        cp -R ${./fixtures/wrap} project
        chmod -R u+w project
        mkdir -p project/subprojects/packagecache
        tar -cJf project/subprojects/packagecache/child.tar.xz -C project child
        digest=$(sha256sum project/subprojects/packagecache/child.tar.xz | cut -d' ' -f1)
        cat > project/subprojects/child.wrap <<EOF
        [wrap-file]
        directory = child
        source_filename = child.tar.xz
        source_url = https://invalid.example/child.tar.xz
        source_hash = $digest
        EOF
        rm -rf project/child
        meson setup build project --wrap-mode=nodownload >&2
        meson compile -C build >&2
        meson test -C build --print-errorlogs >&2
        ./build/answer
      '';
      expected = "42";
      extraInputs = [
        package.tvp.cc
        package.tvp.deps.python.tvp.deps.xz
      ];
    };
  };
}

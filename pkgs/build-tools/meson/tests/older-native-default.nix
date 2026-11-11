{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  deps = package.tvp.deps;
  zlib = tvp.packages.zlib_1;
  standalone = ./fixtures/standalone;
  wrap = ./fixtures/wrap;
in
package.testContext.mkSuite {
  inherit package;
  tools = [
    deps.ninja
    deps.cmake
    deps.pkg-config
    deps.gnutar
    deps.python.tvp.deps.xz
  ];
  libraries = [ zlib ];
  tests = {
    profile = {
      script = ''test -s ${
        (import ./older-native-profile.nix {
          inherit
            pkgs
            tvp
            package
            zlib
            ;
        }).evidence
      }/summary.json; printf qualified'';
      expected = "qualified";
    };
    version = {
      script = "meson --version";
      expected = package.version;
    };
    phases = {
      script = ''
        cp -R ${./fixtures} project
        chmod -R u+w project
        ${deps.helperPython}/bin/python3 - <<'PYTHON'
        from pathlib import Path
        p = Path('project/meson.build')
        p.write_text(p.read_text().replace('install_rpath:', "build_rpath: join_paths(get_option('prefix'), get_option('libdir')), install_rpath:"))
        PYTHON
        meson setup build project --prefix="$PWD/installed" --libdir=lib >&2
        meson compile -C build >&2
        meson test -C build --print-errorlogs >&2
        meson install -C build --no-rebuild >&2
        env -i installed/bin/answer
      '';
      expected = "42";
    };
    introspection = {
      script = ''
        meson setup build ${standalone} >&2
        meson introspect --targets build > info.json
        ${package.runtime.python}/bin/python3 -c 'import json; d=json.load(open("info.json")); assert any(t["name"] == "answer" and t["type"] == "executable" for t in d); print(42)'
      '';
      expected = "42";
    };
    standalone = {
      script = ''
        cp -R ${standalone} project
        chmod -R u+w project
        meson setup build project >&2
        meson compile -C build >&2
        meson test -C build --print-errorlogs >&2
        ./build/answer
      '';
      expected = "42";
    };
    wrap-archive = {
      script = ''
        cp -R ${wrap} project
        chmod -R u+w project
        mkdir -p project/subprojects/packagecache
        tar -cJf project/subprojects/packagecache/child.tar.xz -C project child
        digest=$(sha256sum project/subprojects/packagecache/child.tar.xz); digest=''${digest%% *}
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
    };
    zipapp = {
      script = ''
        ${package.runtime.python}/bin/python3 -I -c 'import zipfile; z=zipfile.ZipFile("${package}/libexec/meson.pyz"); assert len(z.infolist())>100; assert all(i.compress_type==zipfile.ZIP_DEFLATED for i in z.infolist() if not i.is_dir()); print("compressed")'
      '';
      expected = "compressed";
    };
  };
}

// {
  constructor = import ../../native-frontend-contract.nix { inherit pkgs tvp package; };
}

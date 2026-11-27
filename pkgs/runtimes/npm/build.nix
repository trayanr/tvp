{
  tvp,
  lib,
  base,
  src,
  version,
  nodejs,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  inherit (tools)
    bash
    coreutils
    findutils
    gzip
    gnutar
    python
    ;
  inherit (final.runtime) shell;
  runtimeNode = final.runtime.nodejs;
in
{
  pname = "npm";
  inherit
    base
    src
    version
    nodejs
    bash
    coreutils
    ;
  runtime = {
    inherit (final) nodejs;
    shell = final.bash;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    {
      name = "npm.install";
      cwd = "source";
      tools = [ findutils ];
      run = ''
        mkdir -p "$out/lib/node_modules/npm"
        cp -a . "$out/lib/node_modules/npm"
        # node-gyp treats the bundled Python modules as data for its selected Python.
        find "$out/lib/node_modules/npm/node_modules/node-gyp" -type f -name '*.py' -exec chmod a-x {} +
      '';
    }
    (steps.split "npm.finalize")
    (outputs.copyArtifacts { inherit coreutils; })
    {
      name = "npm.bind-runtime";
      tools = [ python ];
      run = ''
        ${python}/bin/python3 -B - "$out" <<'PYTHON'
        import sys
        from pathlib import Path

        module = Path(sys.argv[1], "lib/node_modules/npm/node_modules/@npmcli/promise-spawn/lib/index.js")
        contents = module.read_text()
        original = "process.env.ComSpec : 'sh'"
        assert contents.count(original) == 1
        module.write_text(contents.replace(original, "process.env.ComSpec : '${shell}/bin/bash'"))
        PYTHON

        mkdir -p "$out/bin"
        for entry in npm npx; do
          cat > "$out/bin/$entry" <<EOF
        #!${shell}/bin/bash
        export PATH="$out/bin:${runtimeNode}/bin\''${PATH:+:\$PATH}"
        exec ${runtimeNode}/bin/node "$out/lib/node_modules/npm/bin/$entry-cli.js" "\$@"
        EOF
          chmod +x "$out/bin/$entry"
        done
      '';
    }
    (outputs.shebangs {
      inherit python;
      paths = [ "lib/node_modules/npm" ];
      names = [ "node" ];
      interpreter = "${runtimeNode}/bin/node";
    })
    (
      (outputs.shebangs {
        inherit python;
        paths = [ "lib/node_modules/npm" ];
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${shell}/bin/bash";
      })
      // {
        name = "output.shell-shebangs";
      }
    )
  ];
  meta = {
    description = "Package manager for Node.js";
    homepage = "https://www.npmjs.com/";
    license = lib.licenses.artistic2;
    platforms = [ "x86_64-linux" ];
    mainProgram = "npm";
  };
}

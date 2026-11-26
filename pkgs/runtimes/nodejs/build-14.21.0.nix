# Node.js 14.21 uses the positional installer and npm 6's npm-lifecycle.
{
  tvp,
  lib,
  base,
  src,
  version,
  patches,
  python,
  runtimeBash,
  openssl,
  zlib,
  doCheck ? true,
}@args:
final:
let
  inherit (final)
    src
    patches
    python
    openssl
    zlib
    ;
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  inherit (tools)
    bash
    coreutils
    findutils
    ninja
    ;
  toolPython = tools.python;
  configurePrefix = lib.escapeShellArg final.configurePrefix;
  command = name: steps.command { environment = final.environment; } "nodejs.${name}";
in
{
  pname = "nodejs";
  inherit (args)
    base
    src
    version
    patches
    python
    runtimeBash
    openssl
    zlib
    ;
  inherit bash coreutils doCheck;
  configurePrefix = "/tvp/node";
  environment = {
    tools = [
      python
      ninja
      tools.patch
      tools.sed
      tools.grep
      tools.gawk
      findutils
    ];
    libraries = [
      openssl
      zlib
    ];
  };
  runtime = {
    libraries = final.environment.libraries;
    shell = final.runtimeBash;
  };
  sourceLayout = {
    subprocessShell = "lib/child_process.js";
    npmLifecycleShell = "deps/npm/node_modules/npm-lifecycle/index.js";
  };
  plan = steps.sequence [
    (steps.unpack { inherit src; })
    (command "prepare" ''
      ${lib.concatMapStringsSep "\n" (p: "${tools.patch}/bin/patch --batch --fuzz=0 -p1 < ${p}") patches}
      ${toolPython}/bin/python3 -B - <<'PYTHON'
      from pathlib import Path
      for file in ['${final.sourceLayout.subprocessShell}', '${final.sourceLayout.npmLifecycleShell}']:
          path = Path(file)
          source = path.read_text()
          assert source.count('@TVP_SHELL@') == 1, path
          path.write_text(source.replace('@TVP_SHELL@', '${final.runtime.shell}/bin/bash'))
      PYTHON
    '')
    (steps.shebangs {
      name = "nodejs.source-python";
      paths = [
        "configure"
        "tools"
      ];
      names = [
        "python"
        "python3"
      ];
      interpreter = "${python}/bin/python3";
    })
    (steps.shebangs {
      name = "nodejs.source-shell";
      paths = [
        "configure"
        "tools"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${bash}/bin/bash";
    })
    (command "configure" ''
      ${python}/bin/python3 configure --prefix=${configurePrefix} --ninja \
        --with-intl=full-icu --shared-openssl --shared-openssl-includes=${lib.getDev openssl}/include \
        --shared-openssl-libpath=${lib.getLib openssl}/lib --shared-zlib \
        --shared-zlib-includes=${lib.getDev zlib}/include --shared-zlib-libpath=${lib.getLib zlib}/lib
    '')
    (command "build" ''
      ${ninja}/bin/ninja -C out/Release -j"$NIX_BUILD_CORES" node
    '')
    (command "install" ''
      ${python}/bin/python3 tools/install.py install "" "$out"
      chmod -R u+w "$out"
      # npm's node-gyp launches these support files through its selected Python.
      find "$out/lib/node_modules/npm/node_modules/node-gyp/gyp" \
        -type f -name '*.py' -exec chmod a-x {} +
    '')
    (steps.split "nodejs.finalize")
    (outputs.copyArtifacts { })
    {
      name = "nodejs.relocate";
      tools = [ toolPython ];
      run = ''${toolPython}/bin/python3 -B ${./native/finalize.py} "$out" "$TVP_ARTIFACT_ROOT" ${../../../lib/installed-tree.py} ${configurePrefix}'';
    }
    (outputs.shebangs {
      paths = [ "lib/node_modules" ];
      names = [
        "node"
        "nodejs"
      ];
      selfInterpreter = "bin/node";
    })
    (
      (outputs.shebangs {
        paths = [ "lib/node_modules" ];
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${final.runtime.shell}/bin/bash";
      })
      // {
        name = "output.shell-shebangs";
      }
    )
    (outputs.strip {
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.development { libraries = [ ]; })
    (outputs.checkPaths {
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = {
    npm = true;
    fullIcu = true;
    assertStrictModule = false;
    temporal = false;
    sqlite = false;
    sqliteRequiresFlag = false;
  };
  meta = {
    description = "Node.js with npm and full ICU";
    homepage = "https://nodejs.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "node";
  };
}

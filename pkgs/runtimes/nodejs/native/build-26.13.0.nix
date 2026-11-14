# Native Node 26.13.0: explicit source-GNU steps, full ICU and shared providers.
# Rust/Cargo are declared pinned upstream binary build-only exceptions.
{
  tvp,
  lib,
  base,
  src,
  version,
  patches,
  bash,
  coreutils,
  toolPython,
  gnumake,
  gnutar,
  xz,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  binutils,
  patchelf,
  patch,
  python,
  ninja,
  rustc,
  cargo,
  runtimeBash,
  openssl,
  zlib,
  doCheck ? true,
}@args:
final:
let
  inherit (final)
    base
    src
    version
    patches
    bash
    coreutils
    toolPython
    gnumake
    gnutar
    xz
    findutils
    sed
    grep
    gawk
    diffutils
    binutils
    patchelf
    patch
    python
    ninja
    rustc
    cargo
    runtimeBash
    openssl
    zlib
    doCheck
    ;
  inherit (tvp.builder) steps outputs;
  configurePrefix = if builtins.isString final.configurePrefix && !(builtins.hasContext final.configurePrefix) && builtins.match "/tvp/[A-Za-z0-9][A-Za-z0-9_+./-]*" final.configurePrefix != null && !(builtins.elem ".." (lib.splitString "/" final.configurePrefix)) then final.configurePrefix else throw "Node configurePrefix must be a context-free /tvp path";
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "nodejs.${name}";
      cwd = "source";
      inherit run;

    };
in
{
  pname = "nodejs";
  inherit (args)
    base
    src
    version
    patches
    bash
    coreutils
    toolPython
    gnumake
    gnutar
    xz
    findutils
    sed
    grep
    gawk
    diffutils
    binutils
    patchelf
    patch
    python
    ninja
    rustc
    cargo
    runtimeBash
    openssl
    zlib
    ;
  doCheck = args.doCheck or true;

  environment = {
    tools = [
      python
      ninja
      rustc
      cargo
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    libraries = [
      openssl
      zlib
    ];
  };
  configurePrefix = "/tvp/node";
  runtime = {
    libraries = final.environment.libraries;
    shell = final.runtimeBash;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit xz findutils;
    })
    (command "prepare" ''
      ${lib.concatMapStringsSep "\n" (p: ''${patch}/bin/patch --batch --fuzz=0 -p1 < ${p}'') patches}
      ${toolPython}/bin/python3 -B - <<'PYTHON'
      from pathlib import Path
      for file in ['lib/child_process.js', 'deps/npm/node_modules/@npmcli/promise-spawn/lib/index.js']:
          p = Path(file)
          text = p.read_text()
          assert text.count('@TVP_SHELL@') == 1
          p.write_text(text.replace('@TVP_SHELL@', '${final.runtime.shell}/bin/bash'))
      PYTHON
    '')
    (steps.shebangs {
      name = "nodejs.source-python";
      python = toolPython;
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
      python = toolPython;
      paths = [
        "configure"
        "tools"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "configure" ''
      export CARGO_NET_OFFLINE=true
      export CARGO_HOME="$TMPDIR/cargo-home"
      ${python}/bin/python3 configure --prefix=${lib.escapeShellArg configurePrefix} --ninja --v8-enable-temporal-support \
        --with-intl=full-icu --shared-openssl --shared-openssl-includes=${lib.getDev openssl}/include \
        --shared-openssl-libpath=${lib.getLib openssl}/lib --shared-zlib \
        --shared-zlib-includes=${lib.getDev zlib}/include --shared-zlib-libpath=${lib.getLib zlib}/lib
    '')
    (command "build" ''
      export CARGO_NET_OFFLINE=true
      export CARGO_HOME="$TMPDIR/cargo-home"
      ${ninja}/bin/ninja -C out/Release -j"$NIX_BUILD_CORES" node
    '')
    (command "install" ''
      ${python}/bin/python3 tools/install.py install --dest-dir="" --prefix="$out"
      chmod -R u+w "$out"
      # node-gyp invokes these support sources through its selected Python.
      # They are data, not executable npm entry points requiring env/PATH.
      ${toolPython}/bin/python3 -B - "$out" ${../../../../lib/native-output} <<'PYTHON'
      import sys
      from pathlib import Path
      sys.path.insert(0, sys.argv[2])
      from common import files
      root = Path(sys.argv[1])
      assert root.is_absolute() and root.is_dir() and not root.is_symlink()
      for path in files(root, ["lib/node_modules/npm/node_modules/node-gyp/gyp"]):
          if path.suffix == ".py":
              info = path.stat()
              assert info.st_nlink == 1, path
              path.chmod(info.st_mode & ~0o111)
      PYTHON
    '')
    (steps.split "nodejs.finalize")
    (outputs.copyArtifacts { inherit coreutils; })
    {
      name = "nodejs.relocate";
      tools = [ toolPython ];
      run = ''${toolPython}/bin/python3 -B ${./finalize.py} "$out" "$TVP_ARTIFACT_ROOT" ${../../../../lib/installed-tree.py} ${lib.escapeShellArg final.configurePrefix}'';
    }
    (outputs.shebangs {
      python = toolPython;
      paths = [ "lib/node_modules" ];
      names = [
        "node"
        "nodejs"
      ];
      selfInterpreter = "bin/node";
    })
    (
      (outputs.shebangs {
        python = toolPython;
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
      python = toolPython;
      inherit binutils;
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.rpaths {
      python = toolPython;
      inherit binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.development {
      python = toolPython;
      libraries = [ ];
    })
    (outputs.checkPaths {
      python = toolPython;
      inherit binutils patchelf;
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
    temporal = true;
    sqlite = true;
  };
  meta = {
    description = "Node.js with npm, full ICU, Temporal and SQLite";
    homepage = "https://nodejs.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "node";
  };
}

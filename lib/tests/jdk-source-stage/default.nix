# Source-stage contracts and tiny source/ELF controls. No target JDK input.
{ pkgs, tvp }:
let
  lib = pkgs.lib;
  p = tvp.packages.jdk_21_0_13;
  spec = p.specification;
  fixture = import ../prerequisite-fixture.nix {
    inherit tvp;
    package = p;
    tools = [
      spec.python
      spec.gnutar
      spec.gzip
      spec.gnumake
      spec.base.compiler
      spec.binutils
      spec.patchelf
    ];
  };
  seed = fixture {
    name = "jdk-control-seed";
    buildCommand = ''
      mkdir -p "$out/bin"
      cat > "$out/bin/java" <<'EOF'
      #!${spec.bash}/bin/bash
      printf '%s\n' selected-boot
      EOF
      chmod +x "$out/bin/java"
    '';
  };
  selected = fixture {
    name = "jdk-control-selected-tools";
    buildCommand = ''
      mkdir -p "$out/bin"
      cat > "$out/bin/bash" <<'EOF'
      #!${spec.bash}/bin/bash
      exec ${spec.bash}/bin/bash "$@"
      EOF
      cat > "$out/bin/make" <<'EOF'
      #!${spec.bash}/bin/bash
      exec ${spec.gnumake}/bin/make "$@"
      EOF
      cat > "$out/bin/cc" <<'EOF'
      #!${spec.bash}/bin/bash
      exec ${spec.base.compiler}/bin/cc -DSELECTED_COMPILER=1 "$@"
      EOF
      cat > "$out/bin/c++" <<'EOF'
      #!${spec.bash}/bin/bash
      exec ${spec.base.compiler}/bin/c++ -DSELECTED_COMPILER=1 "$@"
      EOF
      chmod +x "$out/bin/"*
    '';
  };
  source = fixture {
    name = "jdk-control-source.tar.gz";
    buildCommand = ''
      mkdir -p source/src/java.base/unix/native/libjava source/src/java.desktop/unix/native/common/awt
      cp ${./source}/* source/
      printf 'shell=original\n' > source/src/java.base/unix/native/libjava/childproc.c
      printf 'font=original\n' > source/src/java.desktop/unix/native/common/awt/fontpath.c
      tar -czf "$out" source
    '';
  };
  # A distinct selected library output proves final store-path and runtime binding.
  cups = fixture {
    name = "jdk-control-cups";
    buildCommand = ''mkdir -p "$out/lib"; printf selected > "$out/lib/control"'';
  };
  font = fixture {
    name = "jdk-control-fontconfig";
    buildCommand = ''mkdir -p "$out/lib"; printf selected > "$out/lib/libfontconfig.so"'';
  };
  args = {
    src = source;
    base = spec.base.override {
      name = "jdk-control-selected-base";
      compiler = spec.base.compiler // {
        outPath = selected.outPath;
      };
    };
    bash = selected;
    gnumake = selected;
    bootJdk = seed;
    fontconfig = font;
    libcups = cups;
    patches = [ ./tokens.patch ];
    configurationName = "selected-configuration";
    imageDirectory = "selected-image";
  };
  miniature =
    package:
    package.edit (
      s:
      s
      // {
        pname = "tvp-miniature-java-source-control";
        environment = s.environment // {
          overrides.values = {
            JDK_CONTROL_BOOT = toString seed;
            JDK_CONTROL_PYTHON = "${spec.python}/bin/python3";
            JDK_CONTROL_VERIFY = "${./verify-pre-image.py}";
            JDK_CONTROL_PATCHELF = "${spec.patchelf}/bin/patchelf";
          };
        };
      }
    );
  overridden = miniature (p.override args);
  edited = miniature (p.edit (s: s // args));
  plain = builtins.unsafeDiscardStringContext;
  has = needle: haystack: lib.hasInfix (plain needle) (plain haystack);
  step = q: name: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  text = q: lib.concatStringsSep "\n" (map (s: s.run) q.buildSteps);
  defaultRpaths = tvp.builder.outputs.rpaths {
    inherit (spec) python binutils patchelf;
    paths = [ "bin" ];
  };
  defaultConfig = {
    paths = [ "bin" ];
    dlopenDirectories = [ ];
    readelf = "${spec.binutils}/bin/readelf";
    patchelf = "${spec.patchelf}/bin/patchelf";
  };
  retained = import ../../../pkgs/runtimes/jdk/legacy.nix { inherit pkgs tvp; };
  factory = (import ../../../pkgs/runtimes/jdk { inherit pkgs tvp; }).recipes.jdk.extraArgs.mkTests;
  callerPkgs = pkgs // {
    runCommandWith =
      args:
      pkgs.runCommandWith (
        args
        // {
          derivationArgs = args.derivationArgs // {
            callerControl = "selected";
          };
        }
      );
  };
  testIds = builtins.mapAttrs (_: test: test.drvPath);
  contracts = {
    retainedFactoryCaller =
      testIds ((factory.override { pkgs = callerPkgs; }) retained.canonical.jdk_21_0_13) == testIds (
        (import ../../../pkgs/runtimes/jdk/legacy.nix {
          pkgs = callerPkgs;
          inherit tvp;
        }).packageArgs.extraArgs.mkTests
          retained.canonical.jdk_21_0_13
      );

    defaultRendering =
      defaultRpaths.run
      == ''${spec.python}/bin/python3 -B ${../../native-output}/rpaths.py "$out" ${lib.escapeShellArg (builtins.toJSON defaultConfig)}'';
    nullRendering =
      defaultRpaths == tvp.builder.outputs.rpaths {
        inherit (spec) python binutils patchelf;
        paths = [ "bin" ];
        workspaceRoot = null;
      };
    editedLoader =
      has "${spec.base.compiler.libc}/selected/loader"
        (step (p.edit (
          s: s // { dynamicLinker = "selected/loader"; }
        )) "jdk.installed-loaders-and-self-paths").run;
    editedRuntime =
      has "${cups}/lib"
        (step (p.editRuntime (r: r // { libraries = [ cups ]; })) "output.rpaths").run;
    editedTests =
      has "${selected}/bin/bash" (builtins.head edited.tests.shell.buildSteps).run
      && has "${font}/lib/libfontconfig.so" (builtins.head edited.tests.desktop.buildSteps).run
      && has "${cups}/lib/libcups.so" (builtins.head edited.tests.desktop.buildSteps).run;
    independentRecipe = p.tvp.builder == "build-21.0.13.nix";
    nineTests =
      builtins.attrNames p.tests == [
        "desktop"
        "image"
        "native"
        "package-image"
        "runtime"
        "runtime-closure"
        "shell"
        "shell-fork"
        "version"
      ];
    ordered =
      lib.take 7 (map (s: s.name) p.buildSteps) == [
        "source.unpack"
        "jdk.patch"
        "jdk.configure"
        "jdk.exploded-image"
        "jdk.pre-image-rpaths"
        "jdk.images"
        "jdk.install"
      ];
    overrideAndEdit = overridden.drvPath == edited.drvPath;
    selectedActualCommands =
      builtins.all
        (
          q:
          builtins.all (n: has n (text q)) [
            (toString source)
            "${selected}/bin/bash"
            "${selected}/bin/make"
            "${seed}"
            "${font}/lib/libfontconfig.so"
            "${cups}/lib"
            "selected-configuration"
            "selected-image"
            "${spec.base.compiler.libc}/lib/ld-linux-x86-64.so.2"
          ]
          && (step q "jdk.configure").env.CC == "${selected}/bin/cc"
        )
        [
          overridden
          edited
        ];
    testInputsRebound = builtins.all (
      t:
      t.specification.base.compiler.outPath == selected.outPath
      && builtins.any (i: i.outPath == overridden.outPath) t.buildStepRunner.inputs
    ) (builtins.attrValues overridden.tests);
    binarySeedUnchanged = spec.bootJdk.drvPath == tvp.canonical.jdk-bootstrap_21_0_13.drvPath;
  };
  context = tvp.lib.tests.fromPackage {
    builder = tvp.builder;
    package = seed;
  };
  check = context.mkTest {
    package = seed;
    name = "jdk-source-stage";
    tools = [
      spec.python
      spec.binutils
      spec.patchelf
      spec.base.compiler
    ];
    script = ''
      ${spec.python}/bin/python3 -B ${./source-paths.py} ${../../../pkgs/runtimes/jdk/native/source-paths.py}
      ${spec.python}/bin/python3 -B ${./staged-rpaths.py} \
        ${../../staged-output/rpaths.py} ${../../native-output} ${../../elf-output.py} \
        ${spec.binutils}/bin/readelf ${spec.patchelf}/bin/patchelf ${spec.coreutils}/bin/false ${../../../pkgs/runtimes/jdk/native/interpreters.py} ${spec.base.compiler.libc}/lib/ld-linux-x86-64.so.2
      for image in ${overridden} ${edited}; do
        test "$($image/bin/java)" = tiny-source-control
        test "$(cat "$image/boot-selected")" = selected-boot
        test "$(cat "$image/conf-selected")" = selected-configuration
        test "$(cat "$image/compiler-selected")" = ${selected}/bin/cc
        for payload in embedded-resource embedded-library embedded-command; do
          ${spec.patchelf}/bin/patchelf --print-rpath "$image/jmods/$payload" > embedded-paths
          ${spec.python}/bin/python3 -c 'from pathlib import Path; paths = Path("embedded-paths").read_text().strip().split(":"); assert "${cups}/lib" in paths; assert all("unused" not in p for p in paths)'
        done
        test "$(${spec.patchelf}/bin/patchelf --print-interpreter "$image/bin/java")" = ${spec.base.compiler.libc}/lib/ld-linux-x86-64.so.2
        ${spec.patchelf}/bin/patchelf --print-rpath "$image/bin/java" > paths
        ${spec.python}/bin/python3 -c 'from pathlib import Path; assert "${cups}/lib" in Path("paths").read_text().strip().split(":")'
      done
      printf source-stage-ok
    '';
    expected = "source-stage-ok";
  };
in
assert
  builtins.all (x: x) (builtins.attrValues contracts)
  || throw "JDK source contracts: ${builtins.toJSON contracts}";
check
// {
  inherit contracts;
  support = {
    inherit
      seed
      selected
      source
      cups
      font
      overridden
      edited
      ;
  };
}

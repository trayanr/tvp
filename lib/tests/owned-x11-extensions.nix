# Pure override contracts and real installed source/tool/base/library/layout controls.
{ pkgs, tvp }:
let
  names = [
    "libxext"
    "libxrender"
    "libxfixes"
    "libxi"
    "libxtst"
    "libxrandr"
    "libxt"
  ];
  lib = pkgs.lib;
  first = tvp.packages.libxext;
  spec = first.specification;
  fixture = import ./prerequisite-fixture.nix {
    inherit tvp;
    package = first;
    tools = [
      spec.bash
      spec.gnumake
      spec.base.compiler
      spec.python
      spec.gnutar
      spec.xz
      spec.sed
    ];
  };
  wrappers = fixture {
    name = "x11-extension-control-tools";
    buildCommand = ''
      mkdir -p "$out/bin"
      cat > "$out/bin/bash" <<'EOF'
      #!${spec.bash}/bin/bash
      ${spec.bash}/bin/bash "$@"
      result=$?
      if [[ $result == 0 && " ''${*} " == *configure* && -n "''${out:-}" ]]; then
        ${spec.coreutils}/bin/mkdir -p "$out/nix-support"
        printf '%s\n' selected > "$out/nix-support/bash-control"
      fi
      exit "$result"
      EOF
      cat > "$out/bin/make" <<'EOF'
      #!${spec.bash}/bin/bash
      ${spec.gnumake}/bin/make "$@"
      result=$?
      if [[ $result == 0 && " ''${*} " == *' install '* ]]; then
        ${spec.coreutils}/bin/mkdir -p "$out/nix-support"
        printf '%s\n' selected > "$out/nix-support/make-control"
      fi
      exit "$result"
      EOF
      cat > "$out/bin/cc" <<'EOF'
      #!${spec.bash}/bin/bash
      exec ${spec.base.compiler}/bin/cc -DX11_BASE_CONTROL=1 "$@"
      EOF
      cat > "$out/bin/c++" <<'EOF'
      #!${spec.bash}/bin/bash
      exec ${spec.base.compiler}/bin/c++ -DX11_BASE_CONTROL=1 "$@"
      EOF
      cat > "$out/bin/cpp" <<'EOF'
      #!${spec.bash}/bin/bash
      exec ${spec.base.compiler}/bin/cpp -DX11_BASE_CONTROL=1 "$@"
      EOF
      chmod +x "$out/bin/"*
    '';
  };
  compiler = spec.base.compiler // {
    outPath = wrappers.outPath;
  };
  base = spec.base.override {
    name = "x11-extension-control";
    inherit compiler;
  };
  library =
    (fixture {
      name = "x11-extension-control-x11";
      buildCommand = ''
        mkdir -p "$out/lib/pkgconfig" "$out/nix-support"
        ln -s ${spec.libx11}/include "$out/include"
        for f in ${spec.libx11}/lib/lib*; do ln -s "$f" "$out/lib/"; done
        for f in ${spec.libx11}/lib/pkgconfig/*.pc; do
          ${spec.sed}/bin/sed "s|${spec.libx11}|$out|g" "$f" > "$out/lib/pkgconfig/''${f##*/}"
        done
      '';
    }).edit
      (
        s:
        s
        // {
          plan = s.plan ++ [
            (tvp.builder.outputs.development {
              python = spec.python;
              libraries = spec.libx11.development.libraries;
            })
          ];
        }
      );
  perFamily =
    name:
    let
      p = tvp.packages.${name};
      pc =
        {
          libxext = "xext";
          libxrender = "xrender";
          libxfixes = "xfixes";
          libxi = "xi";
          libxtst = "xtst";
          libxrandr = "xrandr";
          libxt = "xt";
        }
        .${name};
      soname =
        {
          libxext = "libXext";
          libxrender = "libXrender";
          libxfixes = "libXfixes";
          libxi = "libXi";
          libxtst = "libXtst";
          libxrandr = "libXrandr";
          libxt = "libXt";
        }
        .${name};
      source = fixture {
        name = "${name}-control-source.tar.xz";
        buildCommand = ''
          mkdir source
          ${spec.gnutar}/bin/tar -xJf ${p.src} --strip-components=1 -C source
          chmod -R u+w source
          printf '\nsource_control=selected\n' >> source/${pc}.pc.in
          # Compilation, rather than metadata alone, proves selected-base use.
          printf '\n#ifndef X11_BASE_CONTROL\n#error selected base required\n#endif\n' >> source/config.h.in
          ${spec.gnutar}/bin/tar -cJf "$out" source
        '';
      };
      args = {
        src = source;
        inherit base;
        bash = wrappers;
        gnumake = wrappers;
        libx11 = library;
        libraryDirectory = "lib/owned-control";
      };
      overridden = p.override args;
      edited = p.edit (s: s // args);
      step =
        package: suffix:
        builtins.head (builtins.filter (s: s.name == "${name}.${suffix}") package.buildSteps);
      has =
        needle: text:
        lib.hasInfix (builtins.unsafeDiscardStringContext needle) (
          builtins.unsafeDiscardStringContext text
        );
      retained = import (../../pkgs/libraries + "/${name}/legacy.nix") { inherit pkgs tvp; };
      public =
        (import (../../pkgs/libraries + "/${name}") { inherit pkgs tvp; })
        .recipes.${name}.extraArgs.mkTests;
      ids = builtins.mapAttrs (_: t: t.drvPath);
      selectedPkgs = pkgs // {
        runCommandWith = args: script: { selected = true; };
      };
      assertions = {
        owned = builtins.all (t: t.tvp.kind == "owned-test") (builtins.attrValues p.tests);
        legacyTests = ids (public retained.aliases.${name}) == ids retained.aliases.${name}.tests;
        callerPkgs =
          ((public.override { pkgs = selectedPkgs; }) retained.aliases.${name}).consumer.selected;
        bothRoutes = overridden.drvPath == edited.drvPath && overridden.drvPath != p.drvPath;
        sourceCommand = has (toString source) (builtins.head overridden.buildSteps).run;
        baseCommand = (step overridden "build").env.CC == "${wrappers}/bin/cc";
        bashCommand = has "${wrappers}/bin/bash" (step overridden "configure").run;
        makeCommand = has "${wrappers}/bin/make" (step overridden "install").run;
        libraryCommand = has "${library}/lib/pkgconfig" (step overridden "configure").env.PKG_CONFIG_LIBDIR;
        development = builtins.elem library.outPath (map toString overridden.development.libraries);
        testRebound =
          overridden.tests.api.package.outPath == overridden.outPath
          && overridden.tests.api.drvPath != p.tests.api.drvPath;
        testShell = builtins.elem wrappers.outPath (
          map toString overridden.tests.api.buildStepRunner.inputs
        );
        checksRetained = p.specification.doCheck && (step p "check").enabled;
      };
      installed = overridden.testContext.mkTest {
        package = overridden;
        name = "installed-controls";
        libraries = [ overridden ];
        tools = [
          spec.pkgConfig
          spec.patchelf
          spec.grep
        ];
        script = ''
          test "$(cat ${overridden}/nix-support/make-control)" = selected
          test "$(cat ${overridden}/nix-support/bash-control)" = selected
          test "$(pkg-config --variable=source_control ${pc})" = selected
          test "$(pkg-config --variable=libdir ${pc})" = ${overridden}/lib/owned-control
          test "$(pkg-config --variable=prefix x11)" = ${library}
          test ! -e ${overridden}/lib/${soname}.so
          test -e ${overridden}/lib/owned-control/${soname}.so
          patchelf --print-rpath ${overridden}/lib/owned-control/${soname}.so | ${spec.grep}/bin/grep -F ${library}/lib > selected-rpath
          "$CC" $(pkg-config --cflags ${pc}) -x c ${builtins.toFile "x11-base-consumer.c" ''
            #ifndef X11_BASE_CONTROL
            #error selected base required
            #endif
            #include <X11/Xlib.h>
            int main(void) { return XInitThreads() ? 0 : 1; }
          ''} $(pkg-config --libs ${pc} x11) -o selected-consumer
          env -i PATH=${spec.coreutils}/bin ${spec.coreutils}/bin/timeout 15 ./selected-consumer
          printf '%s\n' installed-controls-ok
        '';
        expected = "installed-controls-ok";
      };
    in
    {
      inherit
        assertions
        overridden
        edited
        installed
        ;
    };
  controls = lib.genAttrs names perFamily;
  contracts = builtins.mapAttrs (_: c: c.assertions) controls;
  passed = builtins.all (c: builtins.all (x: x) (builtins.attrValues c)) (
    builtins.attrValues contracts
  );
in
assert passed || throw "X11 extension contracts failed: ${builtins.toJSON contracts}";
(first.testContext.mkTest {
  package = first;
  name = "extension-contracts";
  script = "printf '%s' '${builtins.toJSON contracts}'";
  expected = builtins.toJSON contracts;
})
// {
  inherit contracts controls;
  support = {
    controlTools = wrappers;
    controlX11 = library;
  } // lib.mapAttrs' (name: c: lib.nameValuePair "${name}-control-source" c.overridden.src) controls;
}

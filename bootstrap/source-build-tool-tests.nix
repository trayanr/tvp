{
  bootstrap ? import ./. { },
}:
let
  tools = import ./source-build-tools.nix { inherit bootstrap; };
  chain = import ./source-consumers.nix { inherit bootstrap; };
  inherit (tools) pkgConfig ninja;
  inherit (tools.composition)
    lib
    base
    bash
    coreutils
    builder
    cc
    ;
  b = bootstrap;
  python = b.build-python;
  binutils = b.gnu-binutils;
  patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
  make =
    recipe:
    builder {
      inherit recipe;
      args = { };
      dependencyNames = [ ];
      metadata = { };
      selection.kind = "source-build-tool-test";
      mkTests = _: { };
    };
  prepared = base.environment {
    tools = [ pkgConfig ];
    libraries = [ chain.mpc ];
  };
  runtimeEdit = ninja.editRuntime (r: r // { libraries = [ chain.gmp ]; });
  rebound = import ./source-base.nix {
    inherit bootstrap;
    compiler = cc // {
      outPath = "${cc}-constructor-test";
    };
  };
  finalEnvEdit = pkgConfig.edit (
    s:
    s
    // {
      base = rebound.base;
      environment = s.environment // {
        overrides.values.OWNED_CALLBACK = "visible";
      };
    }
  );
  envStep = builtins.head (
    builtins.filter (s: s.name == "pkg-config.configure") finalEnvEdit.buildSteps
  );
  contracts = {
    providerExported = prepared.env.PKG_CONFIG == "${pkgConfig}/bin/pkg-config";
    providerEmpty = (base.environment { tools = [ pkgConfig ]; }).env.PKG_CONFIG_LIBDIR == "";
    publicClosure =
      map toString prepared.libraries == map toString [
        chain.mpc
        chain.gmp
        chain.mpfr
      ];
    providerDirectories =
      prepared.env.PKG_CONFIG_LIBDIR == lib.concatStringsSep ":" (
        lib.concatMap
          (p: [
            "${p}/lib/pkgconfig"
            "${p}/share/pkgconfig"
          ])
          [
            chain.mpc
            chain.gmp
            chain.mpfr
          ]
      );
    finalBase = envStep.env.CC == "${cc}-constructor-test/bin/cc";
    finalEnvironment = envStep.env.OWNED_CALLBACK == "visible";
    runtimeKeepsArtifact =
      runtimeEdit.artifact.drvPath == ninja.artifact.drvPath && runtimeEdit.drvPath != ninja.drvPath;
    recipeOverrideNoop = (pkgConfig.override { }).drvPath == pkgConfig.drvPath;
    stepsNoop = (ninja.editSteps (p: p)).drvPath == ninja.drvPath;
    checkEdit =
      !(builtins.any (s: s.name == "ninja.check") (
        builder.steps.active
          (builder.steps.partition (ninja.override { doCheck = false; }).buildSteps).first
      ));
  };
  # An alternate real archive, containing a distinct member; both recipe unpack
  # steps must read this archive after an ordinary src argument override.
  alternate = make (
    { }:
    {
      pname = "source-build-tool-alternate";
      version = "1";
      src = null;
      inherit base bash coreutils;
      plan = [
        {
          name = "alternate.pack";
          tools = [
            b.gnutar-latest
            b.gzip
          ];
          run = ''
            mkdir -p archive/source "$out"
            printf 'alternate archive member\n' > archive/source/override-marker
            ${b.gnutar-latest}/bin/tar -czf "$out/alternate.tar.gz" -C archive source
          '';
        }
      ];
    }
  );
  probe =
    name: package:
    ((package.override { src = "${alternate}/alternate.tar.gz"; }).edit (
      s: s // { pname = "source-${name}-override"; }
    )).editSteps
      (plan: [
        (builtins.head plan)
        {
          name = "override.verify";
          run = ''
            mkdir -p "$out"
            test "$(cat source/override-marker)" = 'alternate archive member'
            cp source/override-marker "$out/"
          '';
        }
      ]);
  sourceOverridePkgConfig = probe "pkg-config" pkgConfig;
  sourceOverrideNinja = probe "ninja" ninja;
  consumer = make (
    { }:
    final: {
      pname = "source-build-tool-project";
      version = "1";
      src = null;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment = {
        tools = [
          pkgConfig
          ninja
          python
        ];
        libraries = [ chain.mpc ];
      };
      runtime.libraries = (final.base.environment final.environment).libraries;
      plan = [
        (
          (final.base.environment final.environment)
          // {
            name = "project.build";
            run = ''
              mkdir -p "$out/bin" "$evidence"
              printf '%s\n' ${lib.escapeShellArg (builtins.toJSON contracts)} > "$evidence/contracts.json"
              ${python}/bin/python3 -B ${./source-build-tool-project.py} build "$evidence" \
                ${pkgConfig}/bin/pkg-config ${ninja}/bin/ninja ${ninja}/share/ninja ${bash}/bin/bash \
                ${./source-build-tool-project.c} ${./source-build-tool-project.cc} \
                ${cc.libc}/lib/ld-linux-x86-64.so.2 \
                ${
                  lib.escapeShellArg (
                    lib.concatStringsSep ":" (
                      map (p: "${p}/lib") [
                        chain.mpc
                        chain.mpfr
                        chain.gmp
                      ]
                    )
                  )
                }
            '';
          }
        )
        {
          name = "project.install";
          run = ''install -m755 c-consumer cxx-consumer "$out/bin/"'';
        }
        (builder.outputs.strip {
          inherit python binutils;
          paths = [ "bin" ];
        })
        (builder.outputs.rpaths {
          inherit python binutils patchelf;
          base = final.base;
          libraries = final.runtime.libraries;
          paths = [ "bin" ];
        })
        (builder.outputs.checkPaths {
          inherit python binutils patchelf;
          paths = [ "bin" ];
        })
        {
          name = "project.installed";
          tools = [ binutils ];
          run = ''
            for program in "$out"/bin/*; do
              name=''${program##*/}
              env -i "$program" > "$evidence/$name.installed"
              env -i LD_DEBUG=libs "$program" > /dev/null 2> "$evidence/$name.loader"
              ${cc.libc}/lib/ld-linux-x86-64.so.2 --list "$program" > "$evidence/$name.list"
              ${binutils}/bin/readelf -h -l -d "$program" > "$evidence/$name.elf"
            done
            env -i ${pkgConfig}/bin/pkg-config --version > "$evidence/pkg-config.version"
            env -i ${ninja}/bin/ninja --version > "$evidence/ninja.version"
            ${binutils}/bin/readelf -h -l -d ${pkgConfig}/bin/pkg-config ${ninja}/bin/ninja > "$evidence/tools.elf"
          '';
        }
      ];
    }
  );
in
assert builtins.all (x: x) (builtins.attrValues contracts);
{
  inherit
    tools
    chain
    contracts
    consumer
    alternate
    sourceOverridePkgConfig
    sourceOverrideNinja
    ;
}

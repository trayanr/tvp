{
  bootstrap ? import ./. { },
}:
let
  f = import ./source-cmake-prerequisites.nix { inherit bootstrap; };
  t = import ./source-build-tools.nix { inherit bootstrap; };
  b = bootstrap;
  inherit (f.composition)
    lib
    base
    bash
    coreutils
    builder
    cc
    ;
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
      selection.kind = "source-prerequisite-test";
      mkTests = _: { };
    };
  contracts = builtins.listToAttrs (
    lib.concatMap
      (
        name:
        let
          p = f.${name};
          envp = p.edit (
            s:
            s
            // {
              environment = s.environment // {
                overrides.values.OWNED_CALLBACK = "visible";
              };
            }
          );
          rebound = import ./source-base.nix {
            inherit bootstrap;
            compiler = cc // {
              outPath = "${cc}-constructor-test";
            };
          };
          basep = p.edit (s: s // { base = rebound.base; });
          q = p.editRuntime (r: r // { libraries = [ f.zlib ]; });
        in
        map
          (v: {
            name = "${name}-${v.name}";
            value = v.value;
          })
          [
            {
              name = "override";
              value = (p.override { }).drvPath == p.drvPath;
            }
            {
              name = "steps";
              value = (p.editSteps (x: x)).drvPath == p.drvPath;
            }
            {
              name = "base";
              value =
                (builtins.head (builtins.filter (x: x.name == "${name}.configure") basep.buildSteps)).env.CC
                == "${cc}-constructor-test/bin/cc";
            }
            {
              name = "environment";
              value =
                (builtins.head (builtins.filter (x: x.name == "${name}.configure") envp.buildSteps))
                .env.OWNED_CALLBACK == "visible";
            }
            {
              name = "runtimeRebuild";
              value = q.drvPath != p.drvPath;
            }
            {
              name = "checkEdit";
              value =
                !(builtins.any (x: x.name == "${name}.check") (
                  builder.steps.active (builder.steps.partition (p.override { doCheck = false; }).buildSteps).first
                ));
            }
          ]
      )
      [
        "perl"
        "openssl"
      ]
  );
  alternate = make (
    { }:
    {
      pname = "source-prerequisite-alternate";
      version = "1";
      src = null;
      inherit base bash coreutils;
      plan = [
        {
          name = "alternate.archive";
          tools = [
            b.gnutar-latest
            b.gzip
          ];
          run = ''
            mkdir -p data "$out"; printf 'alternate source\n' > data/marker
            ${b.gnutar-latest}/bin/tar -czf "$out/source.tar.gz" data
          '';
        }
      ];
    }
  );
  probe =
    name:
    ((f.${name}.override { src = "${alternate}/source.tar.gz"; }).edit (
      s:
      s
      // {
        pname = "source-${name}-override";
        outputs = [ "out" ];
      }
    )).editSteps
      (plan: [
        (builtins.head plan)
        {
          name = "override.verify";
          run = ''
            mkdir -p "$out"; test "$(cat source/marker)" = 'alternate source'; cp source/marker "$out/"
          '';
        }
      ]);
  consumer = make (
    { }:
    final: {
      pname = "source-prerequisite-consumer";
      version = "1";
      src = null;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment = {
        tools = [
          python
          t.pkgConfig
          f.perl
          b.gnu-tool-floor.gnu-make
          b.gnused
          b.build-grep
          b.gawk
          b.diffutils
          b.gnu-tool-floor.gnu-findutils
        ];
        libraries = [
          f.openssl
          f.zlib
          f.bzip2
          f.xz
          f.zstd
        ];
      };
      runtime.libraries = final.environment.libraries;
      plan = [
        (
          (final.base.environment final.environment)
          // {
            name = "consumer.build";
            run = ''
              mkdir -p "$out/bin" "$evidence"
              printf '%s\n' ${lib.escapeShellArg (builtins.toJSON contracts)} > "$evidence/contracts.json"
              ${python}/bin/python3 -B ${./source-prerequisite-consumers.py} "$out" "$evidence" \
                ${
                  lib.escapeShellArg (
                    builtins.toJSON {
                      packages = builtins.mapAttrs (_: p: toString p) {
                        inherit (f)
                          perl
                          openssl
                          zlib
                          bzip2
                          xz
                          zstd
                          ;
                      };
                      make = "${b.gnu-tool-floor.gnu-make}/bin/make";
                      shell = "${bash}/bin/bash";
                      gzip = "${b.gzip}/bin/gzip";
                      helperPath = lib.concatStringsSep ":" (
                        map (p: "${p}/bin") [
                          f.bzip2
                          f.xz
                          bash
                          coreutils
                          b.build-grep
                          b.gnused
                          b.diffutils
                        ]
                      );
                      codec = ./source-prerequisite-codec.c;
                      tls = ./source-prerequisite-tls.c;
                    }
                  )
                }
            '';
          }
        )
        (builder.outputs.rpaths {
          inherit python binutils patchelf;
          base = final.base;
          paths = [
            "bin/zlib-shared"
            "bin/zlib-static"
            "bin/bzip2-shared"
            "bin/bzip2-static"
            "bin/xz-shared"
            "bin/xz-static"
            "bin/zstd-shared"
            "bin/zstd-static"
            "bin/tls"
          ];
          libraries = final.runtime.libraries;
        })
        {
          name = "consumer.installed";
          tools = [
            python
            binutils
          ];
          run = ''
            ${python}/bin/python3 -B ${./source-prerequisite-consumers.py} installed "$evidence" "$out" ${cc.libc}/lib/ld-linux-x86-64.so.2 ${binutils}/bin/readelf
          '';
        }
      ];
    }
  );
in
assert builtins.all (x: x) (builtins.attrValues contracts);
{
  inherit
    f
    consumer
    contracts
    alternate
    ;
  sourceOverridePerl = probe "perl";
  sourceOverrideOpenssl = probe "openssl";
}

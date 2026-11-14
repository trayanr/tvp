{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  helpers = import ../native-steps.nix { inherit lib; };
  steps = import ../build-steps.nix;
  p = tvp.canonical.zstd_1_5_7;
  base = p.specification.base;
  ownedFixture = import ./prerequisite-fixture.nix {
    inherit tvp;
    package = p;
    tools = [
      tvp.packages.gnugrep
      tvp.packages.diffutils
    ];
  };
  make = ownedFixture {
    name = "native-make-trace";
    buildCommand = ''
      mkdir -p "$out/bin"
      cat > "$out/bin/make" <<'SCRIPT'
      #!${tvp.packages.bash}/bin/bash
      printf '%s\n' "$*" >> "$NIX_BUILD_TOP/make-invocations"
      exec ${tvp.packages.gnumake}/bin/make MAKE="$0" "$@"
      SCRIPT
      chmod +x "$out/bin/make"
    '';
  };
  fixture = tvp.builder {
    recipe =
      {
        base,
        bash,
        coreutils,
        make,
        doCheck ? true,
      }:
      {
        pname = "native-make-fixture";
        version = "1";
        src = null;
        inherit base bash coreutils;
        plan =
          [
            {
              name = "fixture.prepare";
              run = ''
                mkdir source
                cat > source/Makefile <<'MAKE'
                SHELL := ${bash}/bin/bash
                .RECIPEPREFIX := >
                default:
                >$(MAKE) child
                child:
                >printf 'built\n' > built
                check:
                >test -e built
                install:
                >mkdir -p $(out)
                >cp built $(out)/built
                MAKE
              '';
            }
          ]
          ++ helpers.make {
            name = "fixture";
            inherit make doCheck;
            env.PROBE = "selected";
          };
      };
    args = {
      inherit base;
      inherit (tvp.packages) bash coreutils;
      make = tvp.packages.gnumake;
    };
    dependencyNames = [
      "bash"
      "coreutils"
      "make"
    ];
    metadata.status.level = "ok";
    selection.kind = "fixture";
    mkTests = package: {
      run = ownedFixture {
        name = "native-make-customized-consumer";
        buildCommand = ''test "$(cat ${package}/replacement)" = once; test "$(cat ${package}/built)" = built; touch "$out"'';
      };
    };
  };
  insert = steps.insertAfter "fixture.install" [
    {
      name = "fixture.inserted";
      run = ''printf 'once\n' > "$out/inserted"'';
    }
  ];
  replace = steps.replace "fixture.inserted" (
    old:
    old
    // {
      run = ''test ! -e "$out/inserted"; printf 'once\n' > "$out/replacement"'';
    }
  );
  disable = steps.replace "fixture.check" (
    old:
    old
    // {
      enabled = false;
      run = throw "disabled Make check run";
      tools = throw "disabled Make check tools";
      libraries = throw "disabled Make check libraries";
    }
  );
  edits = value: ((value.editSteps insert).editSteps replace).editSteps disable;
  selected = (edits fixture).override { inherit make; };
  traced = selected.editSteps (
    steps.append [
      {
        name = "fixture.verify";
        tools = [ tvp.packages.gnugrep ];
        run = ''
          grep -F child "$NIX_BUILD_TOP/make-invocations"
          grep -F install "$NIX_BUILD_TOP/make-invocations"
          cp "$NIX_BUILD_TOP/make-invocations" "$out/make-invocations"
        '';
      }
    ]
  );
  zstdEdits =
    value:
    (
      (value.editSteps (
        steps.insertAfter "zstd.install" [
          {
            name = "local.marker";
            tools = [ tvp.packages.gnugrep ];
            run = ''printf 'inserted\n' > "$out/marker"'';
          }
        ]
      )).editSteps
      (
        steps.replace "local.marker" (
          old:
          old
          // {
            run = ''
              printf 'replaced\n' > "$out/marker"
              grep -F lib-release "$NIX_BUILD_TOP/make-invocations"
              grep -F install "$NIX_BUILD_TOP/make-invocations"
              cp "$NIX_BUILD_TOP/make-invocations" "$out/make-invocations"
            '';
          }
        )
      )
    ).editSteps
      (steps.replace "zstd.check" (old: old // { run = throw "disabled Zstd check"; }));
  customized = (zstdEdits p).override {
    gnumake = make;
    doCheck = false;
  };
  unpack = helpers.unpack {
    src = "fixture.tar.xz";
    tar = "tar";
    xz = "xz";
  };
  # Golden pre-extension .tar.xz record, including its exact command bytes.
  oldUnpack = [
    {
      name = "source.unpack";
      tools = [
        "tar"
        "xz"
      ];
      run = ''
        mkdir source
        tar -xJf fixture.tar.xz --strip-components=1 -C source
        chmod -R u+w source
        updateSourceDateEpoch source
        printf '%s\n' "$SOURCE_DATE_EPOCH" > source-date-epoch
      '';
    }
  ];
  archive = tvp.bases.default.stdenv.mkDerivation {
    name = "native-unpack-fixture";
    nativeBuildInputs = with tvp.packages; [
      gnutar
      gzip
      xz
    ];
    buildCommand = ''
      mkdir -p fixture "$out"
      printf 'preserved\n' > fixture/data
      touch -d @1700000000 fixture/data
      tar -cJf "$out/fixture.tar.xz" fixture
      tar -czf "$out/fixture.tar.gz" fixture
    '';
  };
  unpacked =
    compression:
    import ../native-build.nix { inherit lib; } {
      pname = "native-unpack-${compression}";
      version = "1";
      src = null;
      base = tvp.bases.default;
      inherit (tvp.packages) bash coreutils;
      plan =
        helpers.unpack {
          src = "${archive}/fixture.tar.${if compression == "xz" then "xz" else "gz"}";
          tar = tvp.packages.gnutar;
          inherit (tvp.packages) xz gzip;
          inherit compression;
        }
        ++ [
          {
            name = "fixture.verify";
            run = ''
              mkdir "$out"
              cp source/data source-date-epoch "$out/"
              test "$(cat "$out/data")" = preserved
              test "$(cat "$out/source-date-epoch")" = 1700000000
            '';
          }
        ];
    };
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  sourceEditFollows =
    package:
    let
      alternate = "/tvp-source-edit-contract.tar";
      edited = package.edit (s: s // { src = alternate; });
      overridden = package.override { src = alternate; };
      unpack = lib.findFirst (s: s.name == "source.unpack") null edited.buildSteps;
    in
    edited.src == alternate
    && lib.hasInfix alternate unpack.run
    && edited.artifact.drvPath != package.artifact.drvPath
    && edited.artifact.drvPath == overridden.artifact.drvPath
    && edited.drvPath != package.drvPath
    && edited.drvPath == overridden.drvPath;
  contracts = {
    packageSourceEdits = builtins.all sourceEditFollows [
      p
      tvp.canonical.json-c_0_19
      tvp.canonical.nghttp2_1_70_0
    ];
    gzipRequiresTool = rejects (
      helpers.unpack {
        src = "archive.gz";
        tar = "tar";
        compression = "gzip";
      }
    );
    unknownCompression = rejects (
      helpers.unpack {
        src = "archive";
        tar = "tar";
        compression = "unknown";
      }
    );
    oldUnpackExact = unpack == oldUnpack;
    replay = selected.drvPath == (edits (fixture.override { inherit make; })).drvPath;
    noOp = (fixture.override { }).drvPath == fixture.drvPath;
    disabledLazy = !(builtins.any (s: s.name == "fixture.check") (steps.active selected.buildSteps));
    absoluteMake =
      lib.hasInfix (builtins.unsafeDiscardStringContext "${make}/bin/make")
        (builtins.elemAt selected.buildSteps 1).run;
    packageReplay =
      customized.drvPath == (zstdEdits (
        p.override {
          gnumake = make;
          doCheck = false;
        }
      )).drvPath;
    metadataCurrent = customized.tvp.deps.gnumake == make;
    featuresCurrent = !customized.tvp.features.doCheck;
    sourceRetained = customized.src == p.src;
    selectionCurrent = customized.__tvpSelection.kind == "override";
    testsRebound =
      customized.tests.version.drvPath != p.tests.version.drvPath
      && builtins.any (
        input: input.outPath == customized.outPath
      ) customized.tests.version.tvp.deps.libraries;
    lazyTests = builtins.all (t: builtins.isString t.drvPath) (builtins.attrValues customized.tests);
  };
  failed = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
in
assert failed == [ ] || throw "Native Make contracts: ${lib.concatStringsSep ", " failed}";
(ownedFixture {
  name = "tvp-native-make-contracts";
  buildCommand = ''
    test -e ${fixture}/built
    test -e ${traced.tests.run}
    cat ${traced}/make-invocations
    diff -r ${unpacked "xz"} ${unpacked "gzip"}
    printf '%s\n' '${builtins.toJSON contracts}' > "$out"
  '';
})
// {
  passthru = {
    inherit contracts customized make;
  };
}

# Opt-in actual owned-builder recipes; source text is written by declared steps.
{
  adapter ? import ./gnu-environment.nix { },
}:
let
  inherit (adapter) lib bash coreutils;
  b = import ./. { };
  base = adapter.base // {
    environment = import ../lib/build-environment.nix { inherit lib base; };
  };
  builder = import ../lib/builder.nix { inherit lib; };
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection = {
        kind = "private-fixture";
      };
      mkTests = _: { };
    };
  prepare =
    final: name: run:
    let
      env = final.base.environment final.environment;
    in
    {
      inherit name run;
      inherit (env) tools libraries env;
    };
  flagTool = flags: coreutils // { buildEnvironment = _: { inherit flags; }; };
  aRecipe =
    {
      value ? 7,
    }:
    final: {
      pname = "tvp-private-discovery-a";
      version = toString value;
      src = null;
      inherit base bash coreutils;
      environment.tools = [ (flagTool { NIX_CFLAGS_COMPILE = [ "-DVALUE=${toString value}" ]; }) ];
      plan = [
        (prepare final "a.build" ''
          mkdir -p "$out/include" "$out/lib"
          printf '%s\n' '#define A_VALUE ${toString value}' 'int a_value(void);' > "$out/include/adapter_a.h"
          printf '%s\n' 'int a_value(void) { return VALUE; }' > a.c
          "$CC" -fPIC -shared a.c -o "$out/lib/libadapter_a.so"
          "$CC" -c a.c -o a.o
          "$AR" crD "$out/lib/libadapter_a.a" a.o
        '')
      ];
    };
  a = make aRecipe { };
  a11 = a.override { value = 11; };
  bRecipe =
    { library }:
    final: {
      pname = "tvp-private-discovery-b";
      version = "1";
      src = null;
      inherit base bash coreutils;
      environment.libraries = [ library ];
      plan = [
        (
          (prepare final "b.build" ''
            mkdir -p "$out/include" "$out/lib"
            printf '%s\n' '#include <adapter_a.h>' 'int b_value(void);' > "$out/include/adapter_b.h"
            printf '%s\n' '#include <adapter_a.h>' 'int b_value(void) { return a_value() + 1; }' > b.c
            "$CC" -fPIC -shared b.c -ladapter_a -o "$out/lib/libadapter_b.so"
            "$CC" -c b.c -o b.o
            "$AR" crD "$out/lib/libadapter_b.a" b.o
          '')
          // {
            developmentLibraries = [ library ];
          }
        )
      ];
    };
  libraryB = make bRecipe { library = a; };
  libraryB11 = libraryB.override { library = a11; };
  consumerRecipe =
    {
      library,
      expected ? 8,
    }:
    final: {
      pname = "tvp-private-discovery-consumer";
      version = toString expected;
      src = null;
      inherit base bash coreutils;
      environment = {
        libraries = [ library ];
        tools = [
          (flagTool {
            NIX_CFLAGS_COMPILE = [
              "-DEXPECT=${toString expected}"
            ];
          })
        ];
      };
      runtime = {
        expected = expected;
        libraries = [ library ];
      };
      plan = [
        (prepare final "consumer.build" ''
          mkdir -p "$out/bin"
          printf '%s\n' '#include <adapter_b.h>' '_Static_assert(A_VALUE + 1 == EXPECT, "public value");' 'int main(void) { return b_value() != EXPECT || a_value() != A_VALUE; }' > consumer.c
          "$CC" consumer.c -ladapter_b -ladapter_a -o "$out/bin/consumer"
          env -i "$out/bin/consumer"
          printf '%s\n' '${toString final.runtime.expected}' > "$out/runtime-expectation"
        '')
      ];
    };
  consumer = make consumerRecipe { library = libraryB; };
  override = consumer.override {
    library = libraryB11;
    expected = 12;
  };
  edited =
    (consumer.edit (
      s:
      s
      // {
        environment = s.environment // {
          libraries = [ libraryB11 ];
          tools = [
            (flagTool {
              NIX_CFLAGS_COMPILE = [
                "-DEXPECT=12"
              ];
            })
          ];
        };
      }
    )).editRuntime
      (
        r:
        r
        // {
          expected = 12;
          libraries = [ libraryB11 ];
        }
      );
  customized = consumer.editSteps (
    builder.steps.replace "consumer.build" (
      s:
      s
      // {
        run = s.run + ''printf 'custom step\n' > "$out/customized"'';
      }
    )
  );
  order =
    dirs:
    (base.environment {
      libraries = [
        {
          outPath = "/private-order-metadata";
          development = {
            includes = [ ];
            libraryDirectories = dirs;
          };
        }
      ];
    }).env.NIX_LDFLAGS;
  gmp = b.gnu-gmp // {
    development = { };
  };
  mpfr = b.gnu-mpfr // {
    development.libraries = [ gmp ];
  };
  mpfrConsumer = make (
    { }:
    final: {
      pname = "tvp-private-discovery-mpfr";
      version = "1";
      src = null;
      inherit base bash coreutils;
      environment.libraries = [ mpfr ];
      plan = [
        (prepare final "mpfr.build" ''
          mkdir -p "$out/bin"
          cat > mpfr.c <<'C'
          #include <gmp.h>
          #include <mpfr.h>
          int main(void) {
            mpfr_t x; mpz_t z; mpfr_init2(x, 80); mpz_init_set_ui(z, 42);
            mpfr_set_z(x, z, MPFR_RNDN);
            int bad = mpfr_cmp_ui(x, 42); mpz_clear(z); mpfr_clear(x); return bad;
          }
          C
          "$CC" mpfr.c -lmpfr -lgmp -o "$out/bin/mpfr-consumer"
          env -i "$out/bin/mpfr-consumer"
        '')
      ];
    }
  ) { };
  protocol = make (
    { }:
    final: {
      pname = "tvp-private-gnu-environment-contracts";
      version = "1";
      src = null;
      inherit base bash coreutils;
      environment = { };
      plan = [
        (prepare final "protocol.check" (
          ''
                  export PRIVATE_CC=${adapter.cc}/bin/cc PRIVATE_CXX=${adapter.cc}/bin/c++
                  export PRIVATE_CPP=${adapter.cc}/bin/cpp
                  export A=${a} B=${libraryB}
                  export ORDER12=${
                    lib.escapeShellArg (order [
                      "first"
                      "second"
                    ])
                  }
                  export ORDER21=${
                    lib.escapeShellArg (order [
                      "second"
                      "first"
                    ])
                  }
                  export FULL=${
                    lib.escapeShellArg (base.environment { libraries = [ libraryB ]; }).env.NIX_CFLAGS_COMPILE
                  }
            export MISSING=${lib.escapeShellArg (base.environment { }).env.NIX_CFLAGS_COMPILE}
                  export B_ONLY=${
                    lib.escapeShellArg
                      (base.environment { libraries = [ (libraryB // { development.libraries = [ ]; }) ]; })
                      .env.NIX_CFLAGS_COMPILE
                  }
                  export MPFR_ONLY=${
                    lib.escapeShellArg
                      (base.environment { libraries = [ (mpfr // { development.libraries = [ ]; }) ]; })
                      .env.NIX_CFLAGS_COMPILE
                  }
          ''
          + builtins.readFile ./gnu-environment-tests.sh
        ))
      ];
    }
  ) { };
  rejects = x: !(builtins.tryEval (builtins.deepSeq x true)).success;
  flags = key: words: (base.environment { overrides.flags.${key} = words; }).env;
in
{
  inherit
    a
    a11
    libraryB
    libraryB11
    consumer
    override
    edited
    customized
    mpfrConsumer
    protocol
    ;
  assertions = {
    actualFactory = consumer.tvp.customization.edits == 0;
    overrideRecomputes =
      override.drvPath != consumer.drvPath && override.buildSteps != consumer.buildSteps;
    fixedPointEnvironment = edited.buildSteps != consumer.buildSteps && edited.runtime.expected == 12;
    noOp = (consumer.edit (x: x)).drvPath == consumer.drvPath;
    stepsRecompute = customized.drvPath != consumer.drvPath;
    runtimeRecomputes = (consumer.editRuntime (r: r // { expected = 9; })).drvPath != consumer.drvPath;
    publicClosure =
      map toString (base.environment { libraries = [ libraryB ]; }).libraries == map toString [
        libraryB
        a
      ];
    noLibcTool = !(builtins.elem b.gnu-libc (base.environment { }).tools);
    noSetup = !(base.stdenv ? mkDerivation) && !(base.stdenv ? setup);
    whitespaceRejected = rejects (flags "NIX_CFLAGS_COMPILE" [ "-DNAME=a b" ]);
    commaRejected = rejects (flags "NIX_LDFLAGS" [ "a,b" ]);
    emptyRejected = rejects (flags "NIX_CFLAGS_LINK" [ "" ]);
    literalEncoding =
      (flags "NIX_CFLAGS_COMPILE" [ "-DX=$(touch-owned)" ]).NIX_CFLAGS_COMPILE == "-DX=$(touch-owned)";
  };
}

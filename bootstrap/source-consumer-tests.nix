# Installed consumers see only MPC's public interface; its development metadata
# supplies both transitive headers and library directories.
{
  bootstrap ? import ./. { },
}:
let
  chain = import ./source-consumers.nix { inherit bootstrap; };
  inherit (chain) gmp mpfr mpc;
  inherit (chain.composition)
    lib
    base
    bash
    coreutils
    builder
    cc
    ;
  b = bootstrap;
  profile = import ./gnu-target-profile.nix { inherit bootstrap; };
  python = b.build-python;
  binutils = b.gnu-binutils;
  patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
  provider = base.environment { libraries = [ mpc ]; };
  replacement = cc // {
    outPath = "${cc}-constructor-contract";
  };
  rebound = import ./source-base.nix {
    inherit bootstrap;
    compiler = replacement;
  };
  runtimeEdit = mpc.editRuntime (r: r // { dlopenDirectories = [ "${gmp}/lib" ]; });
  contracts = {
    publicDiscovery =
      map toString provider.libraries == map toString [
        mpc
        gmp
        mpfr
      ];
    transitiveIncludes = builtins.all (p: lib.hasInfix "${p}/include" provider.env.NIX_CFLAGS_COMPILE) [
      mpc
      mpfr
      gmp
    ];
    transitiveLinkDirs = builtins.all (p: lib.hasInfix "-L${p}/lib" provider.env.NIX_LDFLAGS) [
      mpc
      mpfr
      gmp
    ];
    indirectLinkDirs = builtins.all (p: lib.hasInfix "-rpath-link ${p}/lib" provider.env.NIX_LDFLAGS) [
      mpc
      mpfr
      gmp
    ];
    constructorRebinds = (rebound.base.environment { }).env.CC == "${replacement}/bin/cc";
    sameCompiler = cc.drvPath == (import ./gnu-target-driver.nix { inherit bootstrap; }).drvPath;
    sameRuntime = base.runtimeDirectories == cc.runtimeDirectories;
    runnerFloor =
      map toString base.stdenv.initialPath == map toString [
        bash
        coreutils
      ];
    overrideNoop = (mpc.override { }).drvPath == mpc.drvPath;
    disabledCheck =
      !(builtins.any (s: s.name == "mpc.check") (
        builder.steps.active (builder.steps.partition (mpc.override { doCheck = false; }).buildSteps).first
      ));
    runtimeKeepsArtifact =
      runtimeEdit.artifact.drvPath == mpc.artifact.drvPath && runtimeEdit.drvPath != mpc.drvPath;
    stepEditNoop = (gmp.editSteps (x: x)).drvPath == gmp.drvPath;
  };
  defines = lib.escapeShellArgs (
    map
      (
        name:
        "-D${name}=\"${
          {
            LIBC = profile.libc;
            LIBGCC = profile.libgcc;
            LIBCXX = profile.libstdcxx;
            GMP = gmp;
            MPFR = mpfr;
            MPC = mpc;
          }
          .${name}
        }\""
      )
      [
        "LIBC"
        "LIBGCC"
        "LIBCXX"
        "GMP"
        "MPFR"
        "MPC"
      ]
  );
  consumer = builder {
    recipe =
      { }:
      final: {
        pname = "source-arithmetic-consumers";
        version = "1";
        src = null;
        inherit base bash coreutils;
        outputs = [
          "out"
          "evidence"
        ];
        environment = {
          libraries = [ mpc ];
        };
        runtime.libraries = (final.base.environment final.environment).libraries;
        plan = [
          (
            (final.base.environment final.environment)
            // {
              name = "consumer.compile";
              run = ''
                mkdir -p "$out/bin" "$evidence"
                trap 'status=$?; if (( status != 0 )); then cat "$evidence"/*link.log; fi' EXIT
                cp ${./source-arithmetic.c} source-arithmetic.c
                cp ${./source-arithmetic.cc} source-arithmetic.cc
                cp ${./source-static.cc} source-static.cc
                cp ${./gnu-target-maps.h} gnu-target-maps.h
                printf '%s\n' ${lib.escapeShellArg (builtins.toJSON contracts)} > "$evidence/contracts.json"
                "$CC" -v -Wl,-t -Wl,-Map,c.map ${defines} source-arithmetic.c -lmpc -lmpfr -lgmp -o "$out/bin/arithmetic-c" > "$evidence/c-link.log" 2>&1
                "$CXX" -v -Wl,-t -Wl,-Map,cxx.map ${defines} source-arithmetic.cc -lmpc -lmpfr -lgmpxx -lgmp -o "$out/bin/arithmetic-cxx" > "$evidence/cxx-link.log" 2>&1
                # Real installed archives: static GMP/GMPXX with dynamic owned libc/C++.
                "$CXX" -v -Wl,-t -Wl,-Map,static.map \
                  '-DTARGET_LIBC="${profile.libc}"' '-DTARGET_GCC="${profile.libgcc}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0"' '-DTARGET_CXX="${profile.libstdcxx}"' source-static.cc \
                  ${gmp}/lib/libgmpxx.a ${gmp}/lib/libgmp.a -o "$out/bin/arithmetic-static-gmp" > "$evidence/static-link.log" 2>&1
                "$CC" -v -Wl,-Map,mpc-only.map ${../pkgs/libraries/mpc/tests/fixtures/owned.c} -lmpc -o "$out/bin/mpc-only" > "$evidence/mpc-only-link.log" 2>&1
                cp mpc-only.map c.map cxx.map static.map "$evidence/"
                "$CC" -E -v ${defines} source-arithmetic.c > /dev/null 2> "$evidence/includes.log"
                "$CC" --print-file-name=crt1.o > "$evidence/crt1"
              '';
            }
          )
          (builder.outputs.strip {
            inherit python binutils;
            paths = [ "bin" ];
          })
          (builder.outputs.rpaths {
            inherit
              python
              binutils
              patchelf
              ;
            base = final.base;
            libraries = final.runtime.libraries;
            paths = [ "bin" ];
          })
          (builder.outputs.checkPaths {
            inherit python binutils patchelf;
            paths = [ "bin" ];
          })
          {
            name = "consumer.installed";
            tools = [
              binutils
              b.build-grep
            ];
            run = ''
              for program in "$out"/bin/*; do
                name=''${program##*/}
                env -i "$program" > "$evidence/$name.maps"
                env -i LD_DEBUG=libs "$program" > /dev/null 2> "$evidence/$name.loader"
                ${profile.libc}/lib/ld-linux-x86-64.so.2 --list "$program" > "$evidence/$name.list"
                ${binutils}/bin/readelf -h -l -d "$program" > "$evidence/$name.elf"
                grep -F '${profile.libc}/lib/ld-linux-x86-64.so.2' "$evidence/$name.elf"
              done
              ! grep -E '\(NEEDED\).*libgmp' "$evidence/arithmetic-static-gmp.elf"
              grep -F 'libmpc.so.3' "$evidence/mpc-only.elf"
              ! grep -E '\(NEEDED\).*lib(mpfr|gmp)' "$evidence/mpc-only.elf"
              grep -F '${mpfr}/lib/libmpfr.so.6' "$evidence/mpc-only.list"
              grep -F '${gmp}/lib/libgmp.so.10' "$evidence/mpc-only.list"
              test -f ${gmp}/lib/libgmp.a
              test -f ${gmp}/lib/libgmpxx.a
              ! test -e ${mpfr}/lib/libmpfr.a
              ! test -e ${mpc}/lib/libmpc.a
              grep -F 'prefix=${gmp}' ${gmp}/lib/pkgconfig/gmp.pc
              grep -F 'prefix=${mpfr}' ${mpfr}/lib/pkgconfig/mpfr.pc
              grep -F 'prefix=${mpc}' ${mpc}/lib/pkgconfig/mpc.pc
              grep -F '${gmp}' ${mpc}/nix-support/propagated-build-inputs
              grep -F '${mpfr}' ${mpc}/nix-support/propagated-build-inputs
              ${binutils}/bin/ar t ${gmp}/lib/libgmp.a > "$evidence/archive-members"
              for library in ${gmp}/lib/libgmp.so.10 ${gmp}/lib/libgmpxx.so.4 ${mpfr}/lib/libmpfr.so.6 ${mpc}/lib/libmpc.so.3; do
                ${binutils}/bin/readelf -d "$library"
              done > "$evidence/library-dynamic.log"
              cp ${gmp}/lib/pkgconfig/*.pc ${mpfr}/lib/pkgconfig/*.pc ${mpc}/lib/pkgconfig/*.pc "$evidence/"
            '';
          }
        ];
      };
    args = { };
    dependencyNames = [ ];
    metadata = { };
    selection.kind = "source-base-consumer";
    mkTests = _: { };
  };
in
assert builtins.all (x: x) (builtins.attrValues contracts);
{
  inherit consumer contracts chain;
}

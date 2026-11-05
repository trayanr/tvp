# Focused opt-in target proofs; evidence and installed programs are separate.
{
  bootstrap ? import ./. { },
  profile ? import ./gnu-target-profile.nix { inherit bootstrap; },
}:
let
  b = bootstrap;
  adapter = import ./gnu-target-environment.nix { inherit bootstrap profile; };
  inherit (adapter)
    lib
    bash
    coreutils
    base
    ;
  cc = adapter.cc;
  rt = "${profile.libgcc}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0";
  builder = import ../lib/builder.nix { inherit lib; };
  oldFixtures = import ./gnu-environment-fixtures.nix { inherit adapter; };
  make =
    recipe:
    builder {
      inherit recipe;
      args = { };
      dependencyNames = [ ];
      metadata = { };
      selection.kind = "private-target";
      mkTests = _: { };
    };
  definitions = ''
    export TARGET_LIBC=${profile.libc} TARGET_GCC=${rt} TARGET_CXX=${profile.libstdcxx}
    export TARGET_CC=${cc}/bin/gcc TARGET_CXX_DRIVER=${cc}/bin/g++ TARGET_CPP=${cc}/bin/cpp
    export TARGET_READELF=${b.gnu-binutils}/bin/readelf
  '';
  probeSources = builtins.path {
    name = "tvp-gnu-target-probe-sources";
    path = ./.;
    filter =
      path: type:
      (type == "directory" && path == toString ./.)
      || builtins.elem (baseNameOf path) [
        "gnu-target-maps.h"
        "gnu-target-rtti.h"
        "gnu-target-plugin.cc"
        "gnu-target-rtti.cc"
        "gnu-target-locale.cc"
        "gnu-cancel.c"
        "consumer20.cc"
        "gnu-unwind.cc"
        "gnu-plugin.cc"
      ];
  };
  probe =
    b.bash.runCommand "tvp-capability-gnu-target-probes"
      {
        outputs = [
          "out"
          "evidence"
        ];
        nativeBuildInputs = [
          b.build-python
          b.gnu-binutils
        ];
      }
      (
        definitions
        + ''
          mkdir -p "$out/bin" "$out/lib" "$evidence"
          ${b.build-python}/bin/python3 -B ${./gnu-target-checks.py} ${probeSources} "$out" "$evidence" ${profile.gccSource.monorepoSrc}
        ''
      );
  installed = make (
    _: final: {
      pname = "tvp-capability-gnu-installed-cancellation";
      version = "1";
      src = null;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment = { };
      plan = [
        (
          (final.base.environment final.environment)
          // {
            name = "cancellation.build";
            run =
              definitions
              + ''
                mkdir -p "$out/bin" "$out/lib" "$evidence"
                cp ${./gnu-cancel.c} cancel.c
                # Check maps after libc has dynamically loaded the C-only unwinder.
                ${b.gnused}/bin/sed -i '/puts("GNU C-only/i\    target_maps(0, 1);' cancel.c
                "$CC" '-DTARGET_LIBC="${profile.libc}"' '-DTARGET_GCC="${rt}"' '-DTARGET_CXX="${profile.libstdcxx}"' \
                  -include ${./gnu-target-maps.h} -pthread -v -Wl,-Map,link.map cancel.c -o "$out/bin/cancel" > "$evidence/link.log" 2>&1
                cp link.map "$evidence/"
                printf '%s\n' 'int output_selector_object(void) { return 0; }' > selector.c
                "$CC" -c selector.c -o "$out/lib/selector.o"
                sha256sum "$out/lib/selector.o" > "$evidence/selector-before.sha256"
                ln -s cancel "$out/bin/cancel-alias"
              '';
          }
        )
        (builder.outputs.rpaths {
          python = b.build-python;
          binutils = b.gnu-binutils;
          patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
          base = final.base;
          libraries = [ ];
          paths = [
            "bin"
            "lib"
          ];
          elfKinds = [ "runtime" ];
          # C-only cancellation uses dlopen, so DT_NEEDED alone is insufficient.
          dlopenDirectories = [ rt ];
          forceRpath = true;
        })
        (builder.outputs.checkPaths {
          python = b.build-python;
          binutils = b.gnu-binutils;
          patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
          paths = [ "bin" ];
        })
        (builder.outputs.checkSymlinks {
          python = b.build-python;
          paths = [ "bin/cancel-alias" ];
        })
        {
          name = "cancellation.installed-proof";
          tools = [ b.gnu-binutils ];
          run = ''
            sha256sum --check "$evidence/selector-before.sha256"
            status=0
            env -i LD_DEBUG=libs "$out/bin/cancel" > "$evidence/maps.log" 2> "$evidence/loader.log" || status=$?
            cat "$evidence/maps.log" "$evidence/loader.log"
            test "$status" = 0
            ${b.gnu-binutils}/bin/readelf -l -d "$out/bin/cancel" > "$evidence/elf.log"
          '';
        }
      ];
    }
  );
in
{
  inherit probe installed;
  inherit (oldFixtures)
    a
    a11
    libraryB
    libraryB11
    consumer
    override
    edited
    customized
    protocol
    assertions
    ;
}

# Complete libxcrypt configure/build/install procedure. Tests consume a checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  perl,
  compileFlags ? [ ],
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name;
      run = ''
        export NIX_CFLAGS_COMPILE="${
          lib.concatStringsSep " " (
            lib.optionals (builtins.compareVersions final.base.compiler.version "15" >= 0) final.compileFlags
          )
        } $NIX_CFLAGS_COMPILE"
      ''
      + run;
      cwd = "source";
    };
  checkpoint = "nix-support/libxcrypt-build-tree";
  elfPaths = [ "lib/libcrypt.so.1.1.0" ];
in
{
  pname = "libxcrypt";
  inherit
    base
    src
    version
    perl
    compileFlags
    doCheck
    ;
  inherit (tools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  buildFeatures = {
    shared = true;
    static = true;
  };
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      final.perl
    ];
    libraries = [ ];
  };
  runtime = {
    shell = tools.bash;
    tools = [
      tools.coreutils
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ ];
    dlopenDirectories = [ ];
  };
  productionPlan = steps.sequence [
    (steps.unpack { src = final.src; })
    (
      (command "libxcrypt.prepare" ''
        ${tools.python}/bin/python3 -B ${../attr-crypt-production.py} libxcrypt ${tools.bash}/bin/bash ${final.perl}/bin/perl ${../compression-source-tree.py}
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
    (command "libxcrypt.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --enable-shared --enable-static
    '')
    (command "libxcrypt.build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "libxcrypt.install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "libxcrypt.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    (steps.restoreCheckpoint {
      name = "libxcrypt.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
  ];
  upstreamCheck =
    (command "libxcrypt.check" ''
      status=0
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check || status=$?
      cat test-suite.log
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "libxcrypt.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libxcrypt.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "libxcrypt.relocate-runtime";
      tools = [
        tools.python
        tools.binutils
        tools.patchelf
      ];
      run = ''${tools.python}/bin/python3 -B ${../ordinary-attr-crypt-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${tools.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            readelf = "${tools.binutils}/bin/readelf";
            requiredDirectories = [
              "lib"
              "share/man"
              "nix-support"
            ];
            requiredFiles = [
              "lib/libcrypt.a"
              "lib/libcrypt.la"
              "lib/libcrypt.so.1.1.0"
              "lib/pkgconfig/libxcrypt.pc"
            ];
            requiredRegular = [
              "lib/libcrypt.a"
              "lib/libcrypt.la"
              "nix-support/propagated-build-inputs"
            ];
            libtoolData = [ "lib/libcrypt.la" ];
            buildShell = "${tools.bash}/bin/bash";
            shell = "${final.runtime.shell}/bin/bash";
            paths = map (p: "${p}/bin") final.runtime.tools;
          }
        )
      }'';
    }
    {
      name = "output.manuals";
      tools = [
        tools.gzip
        tools.findutils
      ];
      run = ''
        while IFS= read -r -d $'\0' manual; do
          ${tools.gzip}/bin/gzip -n -9 "$manual"
        done < <(find "$out/share/man" -type f ! -name '*.gz' -print0)
        while IFS= read -r -d "" manual; do
          target=$(readlink "$manual")
          rm "$manual"
          ln -s "$target.gz" "$manual.gz"
        done < <(find "$out/share/man" -type l ! -name '*.gz' -print0)
      '';
    }
    (outputs.strip {
      paths = elfPaths;
      flags = [
        "-S"
        "-p"
      ];
    })
    (outputs.stripArchives { paths = [ "lib/libcrypt.a" ]; })
    (outputs.libtool { paths = [ "lib/libcrypt.la" ]; })
    ((import ../ordinary-attr-crypt-rpaths.nix { inherit lib; }) {
      inherit (tools) python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories;
      paths = elfPaths;
    })
    (outputs.development { libraries = [ ]; })
    (outputs.checkSymlinks {
      paths = [
        "lib/libcrypt.so"
        "lib/libcrypt.so.1"
        "lib/libxcrypt.so"
        "lib/libowcrypt.so"
        "lib/libowcrypt.so.1"
      ];
    })
    (outputs.checkLoaderPaths {
      inherit (tools) python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = final.buildFeatures;
  meta = {
    description = "Extended crypt library";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}

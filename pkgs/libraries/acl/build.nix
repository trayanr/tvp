# Complete acl configure/build/install procedure. Tests consume a checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  attr,
  installedInterface,
  upstreamProfile ? "run",
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  environment = final.base.environment final.environment;
  command = steps.command {
    environment = final.environment;
  };
  checkpoint = "nix-support/acl-build-tree";
  elfPaths = [
    "bin"
    "lib/${final.installedInterface.libraryFile}"
  ];
in
{
  pname = "acl";
  inherit
    base
    src
    version
    attr
    installedInterface
    upstreamProfile
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
    ];
    libraries = [ final.attr ];
  };
  # Attr headers are a build dependency in every release; runtime and public
  # propagation follow the measured interface facts in default.nix.
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
    libraries = lib.optional final.installedInterface.runtimeAttr final.attr;
    dlopenDirectories = [ ];
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (
      (command "acl.prepare" ''
        ${tools.python}/bin/python3 -B ${../attr-crypt-production.py} acl ${tools.bash}/bin/bash "-" ${../compression-source-tree.py}
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
    (command "acl.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --enable-shared --enable-static
    '')
    (command "acl.build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "acl.install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "acl.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    (steps.restoreCheckpoint {
      name = "acl.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
  ];
  upstreamCheck =
    (command "acl.check" ''
      status=0
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check || status=$?
      cat test-suite.log
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "acl.finalize")
    (outputs.copyArtifacts { })
    {
      name = "acl.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "acl.relocate-runtime";
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
              "bin"
              "lib"
              "share/man"
              "nix-support"
            ];
            requiredFiles = [
              "bin/chacl"
              "bin/getfacl"
              "bin/setfacl"
              "lib/libacl.a"
              "lib/libacl.la"
              "lib/${final.installedInterface.libraryFile}"
              "lib/pkgconfig/libacl.pc"
            ];
            requiredRegular = [
              "lib/libacl.a"
              "lib/libacl.la"
              "lib/pkgconfig/libacl.pc"
              "nix-support/propagated-build-inputs"
            ];
            libtoolData = [ "lib/libacl.la" ];
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
    (outputs.stripArchives { paths = [ "lib/libacl.a" ]; })
    (outputs.libtool { paths = [ "lib/libacl.la" ]; })
    ((import ../ordinary-attr-crypt-rpaths.nix { inherit lib; }) {
      inherit (tools) python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories;
      paths = elfPaths;
    })
    (outputs.development {
      libraries = lib.optional final.installedInterface.propagateAttr final.attr;
    })
    (outputs.checkSymlinks {
      paths = [
        "lib/libacl.so"
        "lib/libacl.so.1"
      ];
    })
    (outputs.checkLoaderPaths {
      inherit (tools) python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = final.buildFeatures;
  meta = {
    description = "Access control list utilities and library";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}

# Complete attr configure/build/install procedure. Tests consume a checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  installedInterface,
  upstreamProfile ? "run",
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
      run = '''' + run;
      cwd = "source";
    };
  checkpoint = "nix-support/attr-build-tree";
  elfPaths = [
    "bin"
    "lib/${final.installedInterface.libraryFile}"
  ];
in
{
  pname = "attr";
  inherit
    base
    src
    version
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
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (
      (command "attr.prepare" ''
        ${tools.python}/bin/python3 -B ${../attr-crypt-production.py} attr ${tools.bash}/bin/bash "-" ${../compression-source-tree.py}
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
    (command "attr.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --enable-shared --enable-static
    '')
    (command "attr.build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "attr.install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "attr.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    {
      name = "attr.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }
  ];
  upstreamCheck =
    (command "attr.check" ''
      status=0
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check || status=$?
      cat test-suite.log
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "attr.finalize")
    (outputs.copyArtifacts { })
    {
      name = "attr.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "attr.relocate-runtime";
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
              "bin/attr"
              "bin/getfattr"
              "bin/setfattr"
              "lib/libattr.a"
              "lib/libattr.la"
              "lib/${final.installedInterface.libraryFile}"
              "lib/pkgconfig/libattr.pc"
            ];
            requiredRegular = [
              "lib/libattr.a"
              "lib/libattr.la"
              "nix-support/propagated-build-inputs"
            ];
            libtoolData = [ "lib/libattr.la" ];
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
    (outputs.stripArchives { paths = [ "lib/libattr.a" ]; })
    (outputs.libtool { paths = [ "lib/libattr.la" ]; })
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
        "lib/libattr.so"
        "lib/libattr.so.1"
      ];
    })
    ((import ../ordinary-attr-crypt-check-paths.nix { inherit lib; }) {
      inherit (tools) python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = final.buildFeatures;
  meta = {
    description = "Extended attribute utilities and library";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}

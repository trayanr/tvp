# 2.15.4 complete production profile; U consumes its private compiled checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  zlib,
  installedInterface ? {
    sonameMajor = "16";
  },
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
      name = "libxml2.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  checkpoint = "nix-support/libxml2-build-tree";
  elfPaths = [
    "bin/xmllint"
    "bin/xmlcatalog"
    "lib/libxml2.so.16.1.4"
  ];
in
{
  pname = "libxml2";
  inherit
    base
    src
    version
    zlib
    installedInterface
    doCheck
    ;
  inherit (tools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  configureFlags = [
    "--without-python"
    "--with-zlib=${lib.getDev final.zlib}"
  ];
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      tools.pkg-config
    ];
    libraries = [ final.zlib ];

  };
  runtime = {
    libraries = [ final.zlib ];
    shell = tools.bash;
  };
  productionPlan = steps.sequence [
    (steps.unpack { src = final.src; })
    (steps.prepareAutotools { name = "libxml2.prepare"; })
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" ''${make}'')
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    {
      name = "libxml2.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }
  ];
  upstreamCheck =
    (command "check" ''
      ${make} check > make-check.log 2>&1
      cat make-check.log
      cat runsuite.log
      ${tools.python}/bin/python3 -B ${./native/check-upstream.py}
    '')
    // {
      enabled = final.doCheck;
      tools = environment.tools ++ [ tools.python ];
    };
  upstreamProfile = "native-known-corpus-audit";
  plan = final.productionPlan ++ [
    (steps.split "libxml2.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libxml2.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "libxml2.relocate";
      tools = [
        tools.python
        tools.binutils
        tools.patchelf
      ];
      run = ''
        mkdir finalize-helper
        cp ${./ordinary/finalize.py} finalize-helper/finalize.py
        cp ${./ordinary/elf.py} finalize-helper/elf.py
        ${tools.python}/bin/python3 -B finalize-helper/finalize.py "$out" "$TVP_ARTIFACT_ROOT" ${tools.binutils}/bin/readelf ${tools.patchelf}/bin/patchelf
      '';
    }
    (outputs.shebangs {
      paths = [ "bin/xml2-config" ];
      names = [
        "sh"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.strip {
      paths = elfPaths;
      flags = [
        "-S"
        "-p"
      ];
    })

    (outputs.rpaths {
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = final.runtime.libraries; })
    (outputs.checkSymlinks {
      paths = [
        "lib/libxml2.so"
        "lib/libxml2.so.16"
      ];
    })
    (outputs.checkPaths { paths = elfPaths; })
  ];
  tvp.features = {
    inherit (final) doCheck;
    xpath = true;
    lzma = false;
    shared = true;
    static = false;
    python = false;
  };
  meta = {
    description = "XML parsing library for C";
    homepage = "https://gitlab.gnome.org/GNOME/libxml2";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

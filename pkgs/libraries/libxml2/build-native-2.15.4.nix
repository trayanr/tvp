# 2.15.4 complete production profile; U consumes its private compiled checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  zlib,
  icu ? null,
  bindingPython ? null,
  doxygen ? null,
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
    name:
    steps.command {
      environment = final.environment;
    } "libxml2.${name}";
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  checkpoint = "nix-support/libxml2-build-tree";
  pythonEnabled = final.bindingPython != null;
  pythonLayout = "lib/python${lib.versions.majorMinor final.bindingPython.version}/site-packages";
  # Automake's bytecode rules otherwise embed the temporary install prefix.
  pythonMakeFlags = lib.optionalString pythonEnabled (
    " " + ''pythondir="$out/${pythonLayout}" pyexecdir="$out/${pythonLayout}" am__py_compile=:''
  );
  elfPaths = [
    "bin/xmllint"
    "bin/xmlcatalog"
    "lib/libxml2.so.16.1.4"
  ]
  ++ lib.optional pythonEnabled "${pythonLayout}/libxml2mod.so";
in
{
  pname = "libxml2";
  inherit
    base
    src
    version
    zlib
    icu
    bindingPython
    doxygen
    installedInterface
    doCheck
    ;
  inherit (tools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  configureFlags = [
    (if pythonEnabled then "--with-python" else "--without-python")
    "--with-zlib=${lib.getDev final.zlib}"
  ]
  ++ lib.optional (final.icu != null) "--with-icu";
  development =
    output:
    lib.optionalAttrs pythonEnabled {
      pythonModuleDirectory = "${output}/${pythonLayout}";
    };
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      tools.pkg-config
    ]
    ++ lib.optionals pythonEnabled [
      final.bindingPython
      final.doxygen
    ]
    ++ lib.optional (final.icu != null) final.icu;
    libraries = [
      final.zlib
    ]
    ++ lib.optional (final.icu != null) final.icu
    ++ lib.optional pythonEnabled final.bindingPython;

  };
  runtime = {
    libraries = [ final.zlib ] ++ lib.optional (final.icu != null) final.icu;
    shell = tools.bash;
  };
  productionPlan = steps.sequence [
    (steps.unpack { src = final.src; })
    (steps.prepareAutotools { name = "libxml2.prepare"; })
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      ${lib.optionalString pythonEnabled "export PYTHON=${final.bindingPython}/bin/python3\n"}./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" "${make}${pythonMakeFlags}")
    (command "install" ''
      ${make} install${pythonMakeFlags}
      ${lib.optionalString pythonEnabled ''
        test -f "$out/${pythonLayout}/libxml2.py"
        test -f "$out/${pythonLayout}/libxml2mod.so"
      ''}mkdir -p "$out/nix-support"
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
    (steps.restoreCheckpoint {
      name = "libxml2.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
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
    python = pythonEnabled;
    icu = final.icu != null;
  };
  meta = {
    description = "XML parsing library for C";
    homepage = "https://gitlab.gnome.org/GNOME/libxml2";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

# 2.8.0 complete production profile; U consumes its private compiled checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  zlib,
  icu ? null,
  bindingPython ? null,
  liblzma,
  cStandard ? "gnu89",
  cFlags ? [ ],
  patches ? [ ],
  installedInterface ? {
    sonameMajor = "2";
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
    "bin"
    "lib"
  ];
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
    liblzma
    cStandard
    cFlags
    patches
    installedInterface
    doCheck
    ;
  inherit (tools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  configureFlags = [
    (if pythonEnabled then "--with-python=${final.bindingPython}/bin/python3" else "--without-python")
    "--with-zlib=${lib.getDev final.zlib}"
    "--with-lzma=${lib.getDev final.liblzma}"
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
    ++ lib.optional (final.icu != null) final.icu
    ++ lib.optional pythonEnabled final.bindingPython;
    libraries = [
      final.zlib
      final.liblzma
    ]
    ++ lib.optional (final.icu != null) final.icu
    ++ lib.optional pythonEnabled final.bindingPython;
    overrides.values.CFLAGS = "-O2 -std=${final.cStandard} ${lib.concatStringsSep " " final.cFlags}";
  };
  runtime = {
    libraries = [
      final.zlib
      final.liblzma
    ]
    ++ lib.optional (final.icu != null) final.icu;
    shell = tools.bash;
  };
  productionPlan = steps.sequence [
    (steps.unpack { src = final.src; })
    (
      (command "prepare" (
        lib.optionalString (final.patches != [ ]) ''
          # Patch the shipped generator input and output together without
          # making Automake regenerate otherwise unchanged release files.
          timestamps="$(mktemp -d)"
          touch -r configure.ac "$timestamps/configure.ac"
          touch -r configure "$timestamps/configure"
          ${lib.concatMapStringsSep "\n" (
            p: "${tools.patch}/bin/patch --batch --fuzz=0 -p1 < ${p}"
          ) final.patches}
          touch -r "$timestamps/configure.ac" configure.ac
          touch -r "$timestamps/configure" configure
        ''
        + ''
          ${tools.python}/bin/python3 -B ${./ordinary/prepare.py} ${tools.bash}/bin/bash
        ''
      ))
      // {
        tools =
          environment.tools
          ++ [ tools.python ]
          ++ lib.optionals (final.patches != [ ]) [
            tools.coreutils
            tools.patch
          ];
      }
    )
    (lib.optional (pythonEnabled && lib.versionOlder final.version "2.9.8") (
      command "python-fd-compatibility" ''
        test "$(grep -Fxc '    if (!_PyVerify_fd(fd))' python/types.c)" = 1
        sed -i 's/if (!_PyVerify_fd(fd))/if (fd < 0)/' python/types.c
      ''
    ))
    (lib.optional (final.icu != null) (
      command "icu-boolean-compatibility" ''
        # ICU no longer exports the TRUE macro used by these converters.
        sed -i 's/0, TRUE, \&err);/0, 1, \&err);/' encoding.c
      ''
    ))
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ${lib.optionalString pythonEnabled "export PYTHON=${final.bindingPython}/bin/python3\n"}./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" (
      "${make} libxml2.la xmllint xmlcatalog"
      + lib.optionalString pythonEnabled (
        "\n"
        + ''
          ${make} -C python${pythonMakeFlags}
        ''
      )
    ))
    (command "install" ''
      # The root install target in 2.10 also generates testapi.c. Enter the
      # generated recursive installer directly; retain all installed directories.
      # Noninstalled programs/libraries are test/example targets, restored for U.
      ${make} noinst_PROGRAMS= noinst_LTLIBRARIES= install-recursive${pythonMakeFlags}
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
    {
      name = "libxml2.bind-configured-header";
      tools = [ tools.coreutils ];
      run = ''
        mkdir -p "$out/include/libxml2/libxml" "$out/nix-support"
        cp -- ${artifact}/include/libxml2/libxml/xmlversion.h "$out/include/libxml2/libxml/xmlversion.h"
      '';
    }
  ];
  upstreamCheck =
    (command "check" ''
      ${tools.python}/bin/python3 -B ${./ordinary/capture.py} "$out/nix-support/upstream-raw" \
        ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash \
        ${lib.escapeShellArg "CHECKER=${tools.python}/bin/python3 -B ${./ordinary/capture-command.py}"} check
      cat "$out/nix-support/upstream-raw/stdout"
      # The shared raw wrapper records the real make outcome as well. The
      # original signed exit remains byte-for-byte in the capture's exit.json.
      ${tools.python}/bin/python3 -c 'import json,sys; n=json.load(open(sys.argv[1]))["exit"]; sys.exit(n if n >= 0 else 128 - n)' "$out/nix-support/upstream-raw/exit.json"
    '')
    // {
      enabled = final.doCheck;
      tools = environment.tools ++ [ tools.python ];
    };
  upstreamProfile = "source-bound-capture";
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
    {
      name = "libxml2.repair-static-pkg-config";
      enabled = final.installedInterface.repairPrivateLzma or false;
      tools = [
        tools.grep
        tools.sed
      ];
      run = ''
        pc="$out/lib/pkgconfig/libxml-2.0.pc"
        test "$(grep -c '^Libs\.private:' "$pc")" = 1
        test "$(grep -c '^Libs\.private:.*[[:space:]]-llzma\([[:space:]]\|$\)' "$pc" || true)" = 0
        lzma_libs="$(sed -n 's/^LZMA_LIBS = //p' "$TVP_ARTIFACT_ROOT/${checkpoint}/source/Makefile")"
        test "$lzma_libs" = ${lib.escapeShellArg "-L${lib.getDev final.liblzma}/lib -llzma"}
        sed -i "/^Libs\\.private:/s|$| $lzma_libs|" "$pc"
      '';
    }
    (outputs.shebangs {
      paths = [ "bin/xml2-config" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.strip {
      paths = elfPaths;
      flags = [
        "-S"
        "-p"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives { paths = [ "lib/libxml2.a" ]; })
    (outputs.rpaths {
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      elfKinds = [ "runtime" ];
    })
    (outputs.development { libraries = final.runtime.libraries; })

    (outputs.checkPaths {
      paths = elfPaths;
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = {
    inherit (final) doCheck;
    libraryAbi = final.installedInterface.sonameMajor;
    xpath = true;
    lzma = true;
    shared = true;
    static = true;
    python = pythonEnabled;
    icu = final.icu != null;
    iconv = true;
    http = true;
  };
  meta = {
    description = "XML parsing library for C";
    homepage = "https://gitlab.gnome.org/GNOME/libxml2";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

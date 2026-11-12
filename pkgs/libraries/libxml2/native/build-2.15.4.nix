# Independent native 2.15.4 procedure. The observed upstream default is shared
# only; Python is separately packaged and LZMA was removed upstream.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnumake,
  gnutar,
  xz,
  gnused,
  gnugrep,
  gawk,
  diffutils,
  findutils,
  pkg-config,
  zlib,
  python,
  binutils,
  patchelf,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "libxml2.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'';
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
    bash
    coreutils
    ;
  environment = {
    tools = [
      gnumake
      gnused
      gnugrep
      gawk
      diffutils
      findutils
      pkg-config
    ];
    libraries = [ zlib ];
  };
  runtime.libraries = [ zlib ];
  artifactPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz findutils;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      inherit python bash;
      base = final.base;
      name = "libxml2.prepare";
    })
    (command "configure" ''
      export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash
      ./configure --prefix="$out" --without-python --with-zlib=${lib.getDev zlib}
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
  ];
  artifactName = "${final.pname}-${final.version}";
  finalizeHelper = ./../ordinary/finalize.py;
  inherit doCheck;
  upstreamPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz findutils;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      inherit python bash;
      base = final.base;
      name = "libxml2.prepare";
    })
    (command "configure" ''
      export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash
      ./configure --prefix="$out" --without-python --with-zlib=${lib.getDev zlib}
    '')
    (command "build" make)
  ];
  upstreamCheck =
    (
      (command "check" ''
        ${make} check > make-check.log 2>&1
        cat make-check.log
        cat runsuite.log
        ${python}/bin/python3 -B ${./check-upstream.py}
      '')
      // {
        enabled = final.doCheck;
      }
    );
  plan = steps.sequence (final.artifactPlan ++ [
    (steps.split "libxml2.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "libxml2.relocate";
      tools = [ python binutils patchelf ];
      run = ''
        mkdir finalize-helper
        cp ${final.finalizeHelper} finalize-helper/finalize.py
        cp ${../ordinary/elf.py} finalize-helper/elf.py
        ${python}/bin/python3 -B finalize-helper/finalize.py "$out" "$TVP_ARTIFACT_ROOT" ${binutils}/bin/readelf ${patchelf}/bin/patchelf'';
    }
    (outputs.shebangs {
      inherit python;
      paths = [ "bin/xml2-config" ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    (outputs.development {
      inherit python;
      libraries = [ zlib ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libxml2.so"
        "lib/libxml2.so.16"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ]);
  tvp.features = {
    inherit doCheck;
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
    platforms = lib.platforms.unix;
  };
}

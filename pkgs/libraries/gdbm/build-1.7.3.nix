# gdbm 1.7.3: complete production procedure; upstream checks consume its saved checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  file,
  doCheck ? true,
  cStandard ? "gnu89",
  commonSymbols ? false,
  patches ? [ ],
  sourceLayout ? {
    selections = [ "configure" ];
    libtoolAnchors = { };
    edits = [ ];
  },
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
    } "gdbm.${name}";
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash CFLAGS="-O2${
    lib.optionalString (final.cStandard != null) " -std=${final.cStandard}"
  }${lib.optionalString final.commonSymbols " -fcommon"}"'';
  checkpoint = "nix-support/gdbm-build-tree";
in
{
  pname = "gdbm";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    file
    doCheck
    cStandard
    commonSymbols
    patches
    sourceLayout
    ;
  inherit (tools) bash coreutils;
  buildFeatures = {
    shared = false;
    static = true;
    compatLib = false;
  };
  installedInterface = {
    roundtrip = false;
    cli = false;
    finalizerControls = false;
  };
  features = final.buildFeatures // final.installedInterface;
  configureFlags = [
    (if final.buildFeatures.shared then "--enable-shared" else "--disable-shared")
    (if final.buildFeatures.static then "--enable-static" else "--disable-static")
  ];
  environment = {
    tools = [
      tools.pkg-config
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      final.file
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
      tar = tools.gnutar;
      inherit (tools) gzip findutils;
      compression = "gzip";
    })
    (
      (command "prepare" ''
        ${tools.python}/bin/python3 -B ${../dbm-yaml-source.py} ${tools.bash}/bin/bash ${
          lib.escapeShellArg (
            builtins.toJSON (
              final.sourceLayout
              // {
                patches = map (p: "${p}") final.patches;
              }
            )
          )
        }
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      export CFLAGS="-O2${
        lib.optionalString (final.cStandard != null) " -std=${final.cStandard}"
      }${lib.optionalString final.commonSymbols " -fcommon"}"
      touch gdbm.info
      ./configure --host=${final.base.platform.config} --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" make)
    (command "install" ''
      mkdir -p "$out/lib" "$out/include" "$out/share/man/man3" "$out/share/info"
      ${make} install install-compat prefix="$out" libdir="$out/lib" includedir="$out/include" man3dir="$out/share/man/man3" infodir="$out/share/info"
      mkdir -p "$out/include/gdbm"
      ln -s ../dbm.h ../gdbm.h ../ndbm.h "$out/include/gdbm/"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
  ];
  upstreamUnavailable = "These pre-Automake releases have no check target; installed store/ndbm controls remain registered, including known failures.";
  plan = final.productionPlan ++ [
    (steps.split "gdbm.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText {
      python = tools.python;
      paths =
        if final.features.shared then
          [
            "lib/libgdbm.la"
            "lib/libgdbm_compat.la"
          ]
        else
          [ ];
    })
    {
      name = "gdbm.manuals";
      tools = [
        tools.gzip
        tools.findutils
        final.file
      ];
      run = ''
        while IFS= read -r -d "" p; do
          ${tools.gzip}/bin/gzip -n -9 "$p"
        done < <(${tools.findutils}/bin/find "$out/share/man" -type f ! -name '*.gz' -print0)
        while IFS= read -r -d "" p; do
          target=$(readlink "$p"); rm "$p"; ln -s "$target.gz" "$p.gz"
        done < <(${tools.findutils}/bin/find "$out/share/man" -type l ! -name '*.gz' -print0)
      '';
    }
    (outputs.strip {
      inherit (tools) python binutils;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      inherit (tools) python binutils;
      paths = [ "lib/libgdbm.a" ] ++ lib.optional final.features.compatLib "lib/libgdbm_compat.a";
    })
    (outputs.libtool {
      inherit (tools) python;
      paths =
        if final.features.shared then
          [
            "lib/libgdbm.la"
            "lib/libgdbm_compat.la"
          ]
        else
          [ ];
    })
    ((import ./ordinary/rpaths.nix { inherit lib; }) {
      inherit (tools) python binutils patchelf;
      inherit (final) base;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
      selfLibraryDirectory = true;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      inherit (tools) python;
      libraries = [ ];
    })
    (outputs.checkLoaderPaths {
      inherit (tools) python binutils patchelf;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = final.features // {
    doCheck = final.doCheck;
  };
  meta = {
    description = "GNU dbm key/value database library";
    homepage = "https://www.gnu.org/software/gdbm/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
}

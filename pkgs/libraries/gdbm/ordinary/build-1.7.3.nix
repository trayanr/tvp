# Independent 1.7.3 static-only / 1.8.1 compat-library boundary.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  pkgConfig,
  gnumake,
  gnutar,
  gzip,
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  file,
  doCheck ? true,
  cStandard ? null,
  commonSymbols ? false,
  touchTestsuite ? false,
  patches ? [ ],
  preparation,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "gdbm.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash CFLAGS="-O2${
    lib.optionalString (final.cStandard != null) " -std=${final.cStandard}"
  }${lib.optionalString final.commonSymbols " -fcommon"}"'';
in
{
  pname = "gdbm";
  inherit
    base
    src
    version
    bash
    coreutils
    pkgConfig
    gnumake
    gnutar
    gzip
    python
    binutils
    patchelf
    sed
    grep
    gawk
    diffutils
    findutils
    file
    doCheck
    cStandard
    commonSymbols
    touchTestsuite
    patches
    preparation
    ;
  dependencyProviders = { inherit (final) bash coreutils pkgConfig gnumake gnutar gzip python binutils patchelf sed grep gawk diffutils findutils file; };
  features = {
    shared = lib.versionAtLeast final.version "1.8.0";
    static = true;
    compatLib = lib.versionAtLeast final.version "1.8.1";
  };
  upstreamUnavailable = "These pre-Automake releases have no check target; installed store/ndbm controls remain registered, including known failures.";
  configureFlags = [
    (if final.features.shared then "--enable-shared" else "--disable-shared")
    (if final.features.static then "--enable-static" else "--disable-static")
  ];
  environment = {
    tools = [
      final.pkgConfig
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.file
    ];
    libraries = [ ];
  };
  runtime.shell = final.bash;
  runtime.tools = [
    final.coreutils
    final.sed
    final.grep
    final.gawk
    final.diffutils
    final.findutils
  ];
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      inherit (final) gzip findutils;
      compression = "gzip";
    })
    (command "prepare" ''
      ${final.python}/bin/python3 -B ${./source.py} ${final.bash}/bin/bash ${
        lib.escapeShellArg (
          builtins.toJSON (
            final.preparation
            // {
              patches = map (p: "${p}") final.patches;
            }
          )
        )
      }
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
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
    (steps.split "gdbm.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (outputs.relocateText {
      python = final.python;
      paths = if final.features.shared then [ "lib/libgdbm.la" "lib/libgdbm_compat.la" ] else [ ];
    })
    {
      name = "gdbm.manuals";
      tools = [
        final.gzip
        final.findutils
        final.file
      ];
      run = ''
        while IFS= read -r -d "" p; do
          ${final.gzip}/bin/gzip -n -9 "$p"
        done < <(${final.findutils}/bin/find "$out/share/man" -type f ! -name '*.gz' -print0)
        while IFS= read -r -d "" p; do
          target=$(readlink "$p"); rm "$p"; ln -s "$target.gz" "$p.gz"
        done < <(${final.findutils}/bin/find "$out/share/man" -type l ! -name '*.gz' -print0)
      '';
    }
    (outputs.strip {
      inherit (final) python binutils;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      inherit (final) python binutils;
      paths = [ "lib/libgdbm.a" ] ++ lib.optional final.features.compatLib "lib/libgdbm_compat.a";
    })
    (outputs.libtool {
      inherit (final) python;
      paths = if final.features.shared then [ "lib/libgdbm.la" "lib/libgdbm_compat.la" ] else [ ];
    })
    ((import ./rpaths.nix { inherit lib; }) {
      inherit (final)
        python
        binutils
        patchelf
        base
        ;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
      selfLibraryDirectory = true;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      inherit (final) python;
      libraries = [ ];
    })
    ((import ./check-paths.nix { inherit lib; }) {
      inherit (final) python binutils patchelf;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = final.features;
  meta = {
    description = "GNU dbm key/value database library";
    homepage = "https://www.gnu.org/software/gdbm/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
}

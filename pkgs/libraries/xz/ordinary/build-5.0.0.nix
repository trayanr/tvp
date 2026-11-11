# XZ 5.0.0–5.0.8: configure accepts threads=yes/no, before the 5.2 POSIX
# threading contract and multithreaded encoder API. Preserve the upstream default.
# Keep library ABI filenames upstream-owned and finalize installed helpers after split.
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
  gzip,
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  less,
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;

in
final:
let
  elfPaths = [
    "bin/xz"
    "bin/xzdec"
    "bin/lzmadec"
    "bin/lzmainfo"
    "lib"
  ];
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  rpaths =
    {
      python,
      binutils,
      patchelf,
      base,
      paths,
      libraries,
      dlopenDirectories ? [ ],
    }:
    {
      name = "output.rpaths";
      tools = [
        python
        binutils
        patchelf
      ];
      run = ''${python}/bin/python3 -B ${../../ordinary-compression-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            inherit paths dlopenDirectories;
            elfKinds = null;
            libraries = lib.concatMap (
              p: (p.development or { }).libraryDirectories or [ "${lib.getLib p}/lib" ]
            ) libraries;
            baseDirectories = base.runtimeDirectories;
            readelf = "${binutils}/bin/readelf";
            patchelf = "${patchelf}/bin/patchelf";
          }
        )
      } ${../../../../lib/native-output}'';
    };

in
{
  pname = "xz";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  tools = {
    inherit
      gnumake
      gnutar
      gzip
      findutils
      python
      binutils
      patchelf
      sed
      grep
      gawk
      diffutils
      ;
  };
  libraries = { };
  inherit doCheck;
  stripFlags = [
    "-S"
    "-p"
  ];
  dependencyProviders = final.tools // final.libraries // { less = final.runtime.less; };
  environment = {
    tools = [
      final.tools.gnumake
      final.tools.sed
      final.tools.grep
      final.tools.gawk
      final.tools.diffutils
      final.tools.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
    shell = final.bash;
    pager = final.coreutils;
    inherit less;
    tools = [
      final.coreutils
      final.tools.sed
      final.tools.grep
      final.tools.diffutils
    ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      gzip = final.tools.gzip;
      findutils = final.tools.findutils;
      tar = final.tools.gnutar;
      compression = "gzip";
    })
    {
      name = "xz.prepare";
      cwd = "source";
      tools = [ final.tools.python ];
      env = environment.env;
      run = ''
        ${final.tools.python}/bin/python3 -B ${./validate.py} source "$PWD"
        ${final.tools.python}/bin/python3 -B ${../../ordinary-compression-source.py} xz ${final.bash}/bin/bash
      '';
    }
    (command "xz.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --enable-shared --enable-static --enable-threads=yes \
        gl_cv_posix_shell=${final.bash}/bin/bash
    '')
    (command "xz.build" make)
    ((command "xz.check" "${make} check") // { enabled = final.doCheck; })
    (command "xz.install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "xz.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "xz.relocate-runtime";
      tools = [
        final.tools.python
        final.tools.patchelf
        final.tools.binutils
      ];
      run = ''
        ${final.tools.python}/bin/python3 -B ${./validate.py} output "$out"
        ${final.tools.python}/bin/python3 -B ${../../ordinary-compression-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.tools.patchelf}/bin/patchelf ${
          lib.escapeShellArg (
            builtins.toJSON {
              family = "xz";
              readelf = "${final.tools.binutils}/bin/readelf";
              buildShell = "${final.bash}/bin/bash";
              shell = "${final.runtime.shell}/bin/bash";
              pager = "${final.runtime.pager}/bin/cat";
              paths = map (p: "${p}/bin") final.runtime.tools;
            }
          )
        }
        ${final.tools.python}/bin/python3 -B ${./bind-less.py} "$out" ${final.runtime.less}/bin/less
      '';
    }
    (outputs.strip {
      flags = final.stripFlags;
      python = final.tools.python;
      binutils = final.tools.binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      python = final.tools.python;
      binutils = final.tools.binutils;
      paths = [ "lib/liblzma.a" ];
    })
    (outputs.libtool {
      python = final.tools.python;
      paths = [ "lib/liblzma.la" ];
    })
    (outputs.shebangs {
      python = final.tools.python;
      paths = [
        "bin/xzdiff"
        "bin/xzgrep"
        "bin/xzmore"
        "bin/xzless"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (rpaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      python = final.tools.python;
      libraries = [ ];
    })
    {
      name = "output.manuals";
      tools = [
        final.tools.gzip
        final.tools.findutils
      ];
      run = ''
        find "$out/share/man" -type f -name '*.1' -print0 | while IFS= read -r -d "" path; do
          ${final.tools.gzip}/bin/gzip -n -9 "$path"
        done
        find "$out/share/man" -type l -name '*.1' -print0 | while IFS= read -r -d "" path; do
          target=$(readlink "$path")
          rm "$path"
          ln -s "$target.gz" "$path.gz"
        done
      '';
    }
    (outputs.checkSymlinks {
      python = final.tools.python;
      paths = [
        "lib/liblzma.so"
        "lib/liblzma.so.5"
        "bin/unxz"
        "bin/xzcat"
        "bin/lzma"
        "bin/unlzma"
        "bin/lzcat"
        "bin/xzcmp"
        "bin/lzgrep"
      ];
    })
    (outputs.checkPaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = {
    threaded = false;
  };
  meta = {
    description = "XZ Utils — general-purpose data compression with the LZMA2 algorithm";
    homepage = "https://tukaani.org/xz/";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.unix;
  };
}

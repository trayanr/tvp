# 5.8.4 only. Keep one stage: configured shell helpers contain their prefix.
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
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
  elfPaths = [
    "bin/xz"
    "bin/xzdec"
    "bin/lzmadec"
    "bin/lzmainfo"
    "lib/liblzma.so.5.8.4"
  ];
in
final:
let
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'';
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
  environment = {
    tools = [ gnumake ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
    shell = bash;
  };
  plan = steps.sequence [
    (steps.unpack {
      inherit src gzip;
      tar = gnutar;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "xz.prepare";
      inherit bash python;
      base = final.base;
    })
    (steps.shebangs {
      name = "xz.check-shells";
      inherit python;
      paths = [
        "tests"
        "build-aux"
      ];
      names = [ "sh" ];
      interpreter = "${bash}/bin/bash";
    })
    (command "xz.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      ./configure --prefix="$out" --enable-shared --enable-static --enable-threads=posix \
        gl_cv_posix_shell=${final.runtime.shell}/bin/bash
    '')
    (command "xz.build" make)
    ((command "xz.check" "${make} check") // { enabled = doCheck; })
    (command "xz.install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib/liblzma.a" ];
    })
    (outputs.libtool {
      inherit python;
      paths = [ "lib/liblzma.la" ];
    })
    (outputs.shebangs {
      inherit python;
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
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    {
      name = "output.manuals";
      tools = [ gzip ];
      run = ''
        find "$out/share/man" -type f -name '*.1' -print0 | while IFS= read -r -d "" path; do
          ${gzip}/bin/gzip -n -9 "$path"
        done
        find "$out/share/man" -type l -name '*.1' -print0 | while IFS= read -r -d "" path; do
          target=$(readlink "$path")
          rm "$path"
          ln -s "$target.gz" "$path.gz"
        done
      '';
    }
    (outputs.checkSymlinks {
      inherit python;
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
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = {
    threaded = true;
  };
  meta = {
    description = "XZ Utils — general-purpose data compression with the LZMA2 algorithm";
    homepage = "https://tukaani.org/xz/";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "xz";
  };
}

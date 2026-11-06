# Native source-GNU catalogue route; retained bootstrap procedure stays independent.
# 1.3.2 only. zlib's handwritten configure rejects Autoconf platform flags.
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
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
  elfPaths = [ "lib/libz.so.1.3.2" ];
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
  pname = "zlib";
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
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      inherit src gzip findutils;
      tar = gnutar;
      compression = "gzip";
    })
    (steps.shebangs {
      name = "zlib.prepare";
      inherit python;
      paths = [ "configure" ];
      names = [ "sh" ];
      interpreter = "${bash}/bin/bash";
    })
    (command "zlib.configure" ''./configure --prefix="$out" --shared'')
    (command "zlib.build" make)
    ((command "zlib.check" "${make} check") // { enabled = doCheck; })
    (command "zlib.install" ''
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
      paths = [ "lib/libz.a" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    {
      name = "output.manuals";
      tools = [
        gzip
        findutils
      ];
      run = ''${gzip}/bin/gzip -n -9 "$out/share/man/man3/zlib.3"'';
    }
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libz.so"
        "lib/libz.so.1"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp = {
    reportedVersion = version;
    features = {
      libName = "z";
      versionFunction = true;
      compress2 = true;
      pkgConfig = true;
      static = true;
    };
  };
  meta = {
    description = "Lossless data-compression library implementing the DEFLATE algorithm";
    homepage = "https://zlib.net/";
    license = lib.licenses.zlib;
    platforms = [ "x86_64-linux" ];
  };
}

# Zlib 0.71–0.99: no configure or install target, and the archive is libgz.a.
# Keep the original source and GCC4.9 selection. Its cast-as-lvalue expression
# requires GCC <= 3.3, so these releases remain explicitly broken.
{
  tvp,
  lib,
  base,
  src,
  version,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command =
    name:
    steps.command {
      environment = final.environment;
    } "zlib.${name}";
in
{
  pname = "zlib";
  inherit base src version;
  inherit (tools) bash coreutils;
  environment = {
    tools = [ tools.gnumake ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
    tools = [ ];
  };
  # `static` is the historical optional libz.a sibling capability. The sole
  # libgz.a archive here does not enable the libz.a-specific static test.
  installedInterface = {
    libName = "gz";
    versionFunction = false;
    compress2 = false;
    pkgConfig = false;
    static = false;
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (command "build" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash CC=cc libgz.a
    '')
    (command "install" ''
      mkdir -p "$out/lib" "$out/include"
      cp libgz.a "$out/lib"
      cp zlib.h zconf.h "$out/include"
    '')
  ];
  # No upstream protocol is authored for these releases. Installed consumers
  # remain independent tests; in particular, none masks the compiler failure.
  plan = final.productionPlan ++ [
    (steps.split "zlib.finalize")
    (outputs.copyArtifacts { })
    (outputs.strip {
      paths = [ "lib" ];
      flags = [
        "-S"
        "-p"
      ];
    })
    (outputs.development { libraries = [ ]; })
  ];
  tvp = {
    reportedVersion = final.version;
    features = final.installedInterface;
  };
  meta = {
    description = "Lossless data-compression library implementing the DEFLATE algorithm";
    homepage = "https://zlib.net/";
    license = lib.licenses.zlib;
    platforms = lib.platforms.unix;
  };
}

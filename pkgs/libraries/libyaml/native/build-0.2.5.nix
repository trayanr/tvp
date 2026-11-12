# 0.2.5: owned source-GNU procedure; historical releases retain build-0.0.1.
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
final:
let
  inherit (tvp.builder) steps outputs;
  env = final.base.environment final.environment;
  command =
    name: run:
    env
    // {
      inherit name run;
      cwd = "source";
    };
in
{
  pname = "libyaml";
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
      python
      binutils
      patchelf
      sed
      grep
      gawk
      diffutils
      findutils
      ;
  };
  environment = {
    tools = with final.tools; [
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
  development = output: {
    includeDirectories = [ "include" ];
    libraryDirectories = [ "${output}/lib" ];
    pkgconfig = [ "${output}/lib/pkgconfig" ];
  };
  artifactPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.tools.gnutar;
      inherit (final.tools) gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "libyaml.prepare";
      bash = final.bash;
      inherit (final.tools) python;
      base = final.base;
    })
    (command "libyaml.configure" ''./configure --prefix="$out" --enable-shared --enable-static'')
    (command "libyaml.build" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "libyaml.install" ''${final.tools.gnumake}/bin/make install'')
  ];
  inherit doCheck;
  upstreamPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.tools.gnutar;
      inherit (final.tools) gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "libyaml.prepare";
      bash = final.bash;
      inherit (final.tools) python;
      base = final.base;
    })
    (command "libyaml.configure" ''./configure --prefix="$out" --enable-shared --enable-static'')
    (command "libyaml.build" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
  ];
  upstreamCheck =
    (
      (command "libyaml.check" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check'')
      // {
        enabled = final.tvp.features.doCheck;
      }
    );
  plan = steps.sequence (final.artifactPlan ++ [
    (steps.split "libyaml.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (outputs.relocateText {
      inherit python;
      paths = ["lib/pkgconfig" "lib/libyaml.la"];
    })
    (outputs.strip {
      inherit (final.tools) python binutils;
      paths = [ "lib/libyaml-0.so.2.0.9" ];
    })
    (outputs.stripArchives {
      inherit (final.tools) python binutils;
      paths = [ "lib/libyaml.a" ];
    })
    (outputs.libtool {
      inherit (final.tools) python;
      paths = [ "lib/libyaml.la" ];
    })
    (outputs.rpaths {
      inherit (final.tools) python binutils patchelf;
      base = final.base;
      paths = [ "lib/libyaml-0.so.2.0.9" ];
      libraries = final.runtime.libraries;
    })
    (outputs.development {
      inherit (final.tools) python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      inherit (final.tools) python;
      paths = [
        "lib/libyaml.so"
        "lib/libyaml-0.so.2"
      ];
    })
    (outputs.checkPaths {
      inherit (final.tools) python binutils patchelf;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
  ]);
  tvp.features = {
    document = true;
    pkgConfig = true;
    inherit doCheck;
  };
  meta = {
    description = "C library for parsing and emitting YAML";
    homepage = "https://pyyaml.org/wiki/LibYAML";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

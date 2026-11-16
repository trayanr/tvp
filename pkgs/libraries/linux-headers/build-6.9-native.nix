# 6.9: native x86 UAPI export only, with an explicit platform and host compiler.
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
  inherit (context) steps outputs;
  baseTools = context.tools;
  inherit (final)
    bash
    coreutils
    gnumake
    gnutar
    xz
    sed
    grep
    gawk
    diffutils
    findutils
    perl
    ;
  platform = tvp.lib.platforms.mkNative {
    buildPlatform = final.base.platform;
    hostPlatform = final.base.platform;
    targetPlatform = final.base.platform;
  };
  command =
    name:
    steps.command {
      environment = final.environment;
    } "headers.${name}";
in
{
  pname = "linux-headers";
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  xz = baseTools.xz;
  sed = baseTools.sed;
  grep = baseTools.grep;
  gawk = baseTools.gawk;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  perl = baseTools.perl;

  inherit
    base
    src
    version
    ;
  tools = {
    inherit
      gnumake
      gnutar
      xz
      findutils
      perl
      sed
      grep
      gawk
      diffutils
      ;
  };
  dependencyProviders = final.tools;
  environment = {
    tools = with final.tools; [
      gnumake
      findutils
      perl
      sed
      grep
      gawk
      diffutils
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  development = {
    includeDirectories = [ "include" ];
    libraryDirectories = [ ];
    pkgconfig = [ ];
    libraries = [ ];
  };
  inherit platform;
  passthru = {
    inherit platform;
  };
  plan =
    assert final.runtime.libraries == [ ];
    steps.sequence [
      (steps.unpack {
        src = final.src;
        tar = final.tools.gnutar;
        inherit (final.tools) xz findutils;
        compression = "xz";
      })
      (command "export" ''
        ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" headers \
          ARCH=${final.platform.linuxHeadersArch} SHELL=${final.bash}/bin/bash \
          CONFIG_SHELL=${final.bash}/bin/bash CC="$CC" HOSTCC="$CC"
      '')
      (command "install" ''
        mkdir -p "$out/include" "$out/share/licenses/linux-headers"
        cp -r usr/include/. "$out/include/"
        cp COPYING "$out/share/licenses/linux-headers/"
        cp -r LICENSES "$out/share/licenses/linux-headers/"
        test -f "$out/include/linux/version.h"
      '')
      (steps.split "headers.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      {
        name = "headers.prune";
        tools = [ final.tools.findutils ];
        run = ''${final.tools.findutils}/bin/find "$out/include" -type f ! -name '*.h' -delete'';
      }
    ];
  meta = {
    description = "Linux userspace API headers";
    homepage = "https://kernel.org/";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
}

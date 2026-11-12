# 6.9: native x86 UAPI export only, with an explicit platform and host compiler.
{
  tvp,
  lib,
  platforms,
  base,
  src,
  version,
  bash,
  coreutils,
  gnumake,
  gnutar,
  xz,
  findutils,
  perl,
  sed,
  grep,
  gawk,
  diffutils,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  platform = platforms.mkNative {
    buildPlatform = final.base.platform;
    hostPlatform = final.base.platform;
    targetPlatform = final.base.platform;
  };
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "headers.${name}";
      cwd = "source";
      inherit run;
    };
in
{
  pname = "linux-headers";
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
      xz
      findutils
      perl
      sed
      grep
      gawk
      diffutils
      ;
  };
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

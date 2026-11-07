# Native ordinary 3.12 boundary: complete source-GNU procedure for 3.12 only.
# Earlier releases and captured construction generations retain independent routes.
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
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  xz,
  pcre2,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command = name: run: (final.base.environment final.environment) // {
    name = "gnugrep.${name}";
    cwd = "source";
    inherit run;
  };
in
{
  pname = "gnugrep";
  inherit base src version bash coreutils;
  environment = {
    tools = [ gnumake sed grep gawk diffutils findutils ];
    libraries = [ pcre2 ];
  };
  runtime.libraries = [ pcre2 ];
  plan = steps.sequence [
    (steps.unpack { src = final.src; tar = gnutar; inherit xz findutils; compression = "xz"; })
    (steps.prepareAutotools { name = "gnugrep.prepare"; bash = final.bash; inherit python; base = final.base; })
    (steps.shebangs { name = "gnugrep.source-shells"; inherit python; paths = ["build-aux" "tests"]; names = [ "sh" "bash" ]; interpreter = "${final.bash}/bin/bash"; })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      ./configure --prefix="$out" --enable-nls --enable-perl-regexp
      grep '^#define HAVE_LIBPCRE 1' config.h
      grep '^#define ENABLE_NLS 1' config.h
    '')
    (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    ((command "check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check'') // { enabled = doCheck; })
    (command "install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp config.h "$out/nix-support/config.h"
      grep -Ex 'gt_cv_func_gnugettext[0-9]+_libc=yes' config.log > "$out/nix-support/gettext-libc"
    '')
    (outputs.shebangs { inherit python; paths = [ "bin" ]; names = [ "sh" "bash" ]; interpreter = "${final.bash}/bin/bash"; })
    (outputs.strip { inherit python binutils; paths = [ "bin" ]; })
    (outputs.rpaths { inherit python binutils patchelf; base = final.base; libraries = final.runtime.libraries; dlopenDirectories = final.runtime.dlopenDirectories or [ ]; paths = [ "bin" ]; })
    (outputs.development { inherit python; libraries = [ ]; })
    (outputs.checkPaths { inherit python binutils patchelf; paths = [ "bin" ]; })
  ];
  tvp.features = { pcre = true; nls = true; };
  meta.platforms = [ "x86_64-linux" ];
}

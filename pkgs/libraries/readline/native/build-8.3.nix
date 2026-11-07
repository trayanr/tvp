# Native ordinary 8.3 boundary: complete source-GNU procedure for 8.3 only.
# Earlier releases and captured construction generations retain independent routes.
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
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  gzip,
  ncurses,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command = name: run: (final.base.environment final.environment) // {
    name = "readline.${name}";
    cwd = "source";
    inherit run;
  };
in
{
  pname = "readline";
  inherit base src version bash coreutils;
  environment = {
    tools = [ pkgConfig gnumake sed grep gawk diffutils findutils ];
    libraries = [ ncurses ];
  };
  runtime.libraries = [ ncurses ];
  plan = steps.sequence [
    (steps.unpack { src = final.src; tar = gnutar; inherit gzip findutils; compression = "gzip"; })
    (steps.prepareAutotools { name = "readline.prepare"; bash = final.bash; inherit python; base = final.base; })
    (steps.shebangs { name = "readline.source-shells"; inherit python; paths = ["support" "shlib"]; names = [ "sh" "bash" ]; interpreter = "${final.bash}/bin/bash"; })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      ./configure --prefix="$out" --with-curses --enable-shared --disable-static
    '')
    (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash SHLIB_LIBS=-lncursesw'')
    ((command "check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash SHLIB_LIBS=-lncursesw check'') // { enabled = doCheck; })
    (command "install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash SHLIB_LIBS=-lncursesw install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.shebangs { inherit python; paths = [ "lib" ]; names = [ "sh" "bash" ]; interpreter = "${final.bash}/bin/bash"; })
    (outputs.strip { inherit python binutils; paths = [ "lib" ]; })
    (outputs.rpaths { inherit python binutils patchelf; base = final.base; libraries = final.runtime.libraries; dlopenDirectories = final.runtime.dlopenDirectories or [ ]; paths = [ "lib" ]; })
    (outputs.development { inherit python; libraries = [ ]; })
    (outputs.checkPaths { inherit python binutils patchelf; paths = [ "lib" ]; })
  ];
  tvp.features = { shared = true; history = true; static = false; };
  meta.platforms = [ "x86_64-linux" ];
}

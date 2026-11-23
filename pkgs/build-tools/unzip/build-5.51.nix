# Historical Unix Makefile procedure. These releases predate unix/configure.
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
  command = steps.command { environment = final.environment; };
  # Keep the upstream fallback banner instead of embedding the build host's uname.
  make = ''
    ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" -f unix/Makefile \
      SHELL=${tools.bash}/bin/bash CC=cc LF2= HOST_VERSINFO= \
      prefix="$out" BINDIR="$out/bin" MANDIR="$out/share/man/man1"'';
  elfPaths = [
    "bin/unzip"
    "bin/funzip"
    "bin/unzipsfx"
  ];
in
{
  pname = "unzip";
  inherit base src version;
  inherit (tools) bash coreutils;
  environment = {
    tools = [ tools.gnumake ];
    libraries = [ ];
    overrides.flags.NIX_CFLAGS_COMPILE = [
      "-fcommon"
      "-std=gnu17"
      "-Wno-error=implicit-int"
      "-Wno-error=implicit-function-declaration"
    ];
  };
  runtime = {
    libraries = [ ];
    shell = tools.bash;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (command "unzip.build" ''${make} generic'')
    (command "unzip.install" ''
      ${make} install
      install -Dm644 ${./setup-hook.sh} "$out/nix-support/setup-hook"
    '')
    (steps.split "unzip.finalize")
    (outputs.copyArtifacts { })
    (outputs.shebangs {
      paths = [ "bin/zipgrep" ];
      names = [ "sh" ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.strip { paths = elfPaths; })
    (outputs.rpaths {
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    {
      name = "output.manuals";
      tools = [ tools.gzip ];
      run = ''for path in "$out"/share/man/man1/*.1; do gzip -n -9 "$path"; done'';
    }
    {
      name = "output.zipinfo-link";
      run = ''
        test ! -L "$out/bin/zipinfo"
        ln -f "$out/bin/unzip" "$out/bin/zipinfo"
        test "$out/bin/unzip" -ef "$out/bin/zipinfo"
      '';
    }
    (outputs.checkPaths { paths = elfPaths; })
  ];
  tvp.features = {
    bzip2 = false;
    encryption = true;
    zip64 = false;
    largeFiles = false;
  };
  meta = {
    description = "Info-ZIP archive extractor";
    homepage = "https://infozip.sourceforge.net/";
    license = lib.licenses.info-zip;
    platforms = [ "x86_64-linux" ];
    mainProgram = "unzip";
  };
}

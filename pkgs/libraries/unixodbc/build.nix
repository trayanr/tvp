{
  tvp,
  lib,
  base,
  src,
  version,

}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  elfPaths = [
    "bin"
    "lib"
  ];
in
{
  pname = "unixodbc";
  inherit base src version;
  inherit (tools) bash coreutils;

  # Compiled configuration and tool paths require equal-width store prefixes.
  artifactName = "${final.pname}-${final.version}";
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      tools.pkg-config
    ];
    libraries = [ ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools { name = "unixodbc.prepare"; })
    (command "unixodbc.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" --enable-shared --disable-static \
        --with-included-ltdl --disable-readline --disable-drivers --disable-driver-config
    '')
    (command "unixodbc.build" "${make} all")
    (command "unixodbc.install" ''
      ${make} install
      find "$out/lib" -maxdepth 1 -name '*.la' -delete
      install -Dm644 COPYING "$out/share/licenses/unixodbc/COPYING"
    '')
    (steps.split "unixodbc.finalize")
    (outputs.copyArtifacts { })
    {
      name = "unixodbc.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (outputs.strip { paths = elfPaths; })
    (outputs.rpaths {
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths { paths = elfPaths; })
  ];
  meta = {
    description = "ODBC driver manager for Unix";
    homepage = "https://www.unixodbc.org/";
    license = lib.licenses.lgpl2;
    platforms = [ "x86_64-linux" ];
  };
}

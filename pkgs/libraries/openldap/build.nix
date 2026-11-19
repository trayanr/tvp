{
  tvp,
  lib,
  base,
  src,
  version,
  openssl,
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
  pname = "openldap";
  inherit
    base
    src
    version
    openssl
    ;
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
    libraries = [ final.openssl ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools { name = "openldap.prepare"; })
    (command "openldap.select-client" ''
      # The client profile builds the SDK and tools. The manpage transformation
      # requires soelim, and the server and its test tree are outside this profile.
      grep -Fx 'SUBDIRS= include libraries clients servers tests doc' Makefile.in
      sed -i 's/^SUBDIRS= include libraries clients servers tests doc$/SUBDIRS= include libraries clients/' Makefile.in
    '')
    (command "openldap.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" --enable-shared --disable-static \
        --disable-slapd --without-cyrus-sasl --with-tls=openssl
    '')
    (command "openldap.depend" "${make} depend")
    (command "openldap.build" "${make} all")
    (command "openldap.install" ''
      ${make} install
      find "$out/lib" -maxdepth 1 -name '*.la' -delete
      install -Dm644 LICENSE "$out/share/licenses/openldap/LICENSE"
    '')
    (steps.split "openldap.finalize")
    (outputs.copyArtifacts { })
    {
      name = "openldap.relocate";
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
    description = "OpenLDAP client libraries and command-line tools";
    homepage = "https://www.openldap.org/";
    license = lib.licenses.openldap;
    platforms = [ "x86_64-linux" ];
  };
}

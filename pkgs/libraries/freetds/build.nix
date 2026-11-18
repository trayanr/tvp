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
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  elfPaths = [
    "bin"
    "lib"
  ];
in
{
  pname = "freetds";
  inherit
    base
    src
    version
    openssl
    ;
  inherit (tools) bash coreutils;

  # The client library and tsql embed the configuration directory. Keep each
  # stage's store prefix the same width so those strings can be relocated.
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
  runtime.libraries = [ final.openssl ];

  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools { name = "freetds.prepare"; })
    (command "freetds.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" \
        --enable-shared --disable-static --with-openssl --without-gnutls \
        --enable-sybase-compat --disable-odbc --disable-krb5 --disable-sspi \
        --disable-server --disable-pool

      # Install the generated man pages separately from the DocBook targets,
      # which can regenerate release documentation from a Git checkout.
      grep -Eq '^SUBDIRS[[:space:]]*=[[:space:]]*include src doc samples win32 vms misc$' Makefile
      sed -i 's/^SUBDIRS[[:space:]]*=.*/SUBDIRS = include src/' Makefile
    '')
    (command "freetds.build" "${make} all")
    (command "freetds.install" ''
      ${make} install
      for page in bsqldb datacopy defncopy fisql freebcp tsql; do
        install -Dm644 "doc/$page.1" "$out/share/man/man1/$page.1"
      done
      install -Dm644 doc/freetds.conf.5 "$out/share/man/man5/freetds.conf.5"
      mkdir -p "$out/share/licenses/freetds"
      cp COPYING_LIB.txt COPYING.txt "$out/share/licenses/freetds/"
    '')
    (steps.split "freetds.finalize")
    (outputs.copyArtifacts { })
    {
      name = "freetds.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    {
      name = "freetds.drop-odbc-helper";
      tools = [ final.coreutils ];
      run = ''${final.coreutils}/bin/rm -f -- "$out/bin/osql"'';
    }
    (outputs.strip { paths = elfPaths; })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      paths = elfPaths;
    })
    (outputs.checkPaths { paths = elfPaths; })
  ];
  tvp.features = {
    tls = true;
    odbc = false;
    sybaseCompat = true;
  };
  meta = {
    description = "FreeTDS client libraries and tools for Sybase and Microsoft SQL Server";
    homepage = "https://www.freetds.org/";
    license = [
      lib.licenses.lgpl2Plus
      lib.licenses.gpl2Plus
    ];
    platforms = [ "x86_64-linux" ];
  };
}

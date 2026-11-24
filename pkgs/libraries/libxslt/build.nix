{
  tvp,
  lib,
  base,
  src,
  version,
  libxml2,
  libgcrypt ? null,
  withPython ? true,
  patches ? [ ],
  linkLibxml2Compression ? false,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  cryptoEnabled = final.libgcrypt != null;
  bindingPython = final.libxml2.specification.bindingPython or null;
  pythonEnabled = final.withPython && lib.versionAtLeast final.version "1.1.35" && bindingPython != null;
  legacyPythonProbe = lib.versionOlder final.version "1.1.36";
  pythonLayout = "lib/python${lib.versions.majorMinor bindingPython.version}/site-packages";
  pythonMakeFlags = lib.optionalString pythonEnabled (
    " " + ''pythondir="$out/${pythonLayout}" pyexecdir="$out/${pythonLayout}" am__py_compile=:''
  );
  pythonFlag =
    if !pythonEnabled then "--without-python"
    else if legacyPythonProbe then "--with-python=${bindingPython}/bin/python3"
    else "--with-python";
  paths = [
    "bin"
    "lib"
  ];
in
{
  pname = "libxslt";
  inherit
    base
    src
    version
    libxml2
    libgcrypt
    withPython
    patches
    linkLibxml2Compression
    ;
  inherit (tools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  environment = {
    tools = [
      tools.gnumake
      tools.pkg-config
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ] ++ lib.optional cryptoEnabled final.libgcrypt ++ lib.optional pythonEnabled bindingPython;
    libraries = [ final.libxml2 ] ++ lib.optional cryptoEnabled final.libgcrypt ++ lib.optional pythonEnabled bindingPython;
  };
  runtime = {
    # Older configure scripts use xml2-config --libs and link its compression
    # providers directly. Include those providers when finalizing their ELF files.
    libraries =
      [ final.libxml2 ]
      ++ lib.optionals final.linkLibxml2Compression final.libxml2.specification.runtime.libraries
      ++ lib.optional cryptoEnabled final.libgcrypt;
    shell = tools.bash;
  };
  installedInterface.pkgconfig = true;
  development = output: lib.optionalAttrs pythonEnabled {
    pythonModuleDirectory = "${output}/${pythonLayout}";
  };
  tvp.features = {
    crypto = cryptoEnabled;
    python = pythonEnabled;
  };
  plan = steps.sequence [
    (steps.unpack { src = final.src; })
    (lib.optional (final.patches != [ ]) (
      steps.command { environment.tools = [ tools.patch ]; } "libxslt.patch" ''
        for patch in ${lib.escapeShellArgs (map (file: "${file}") final.patches)}; do
          ${tools.patch}/bin/patch --batch --fuzz=0 -p1 < "$patch"
        done
      ''
    ))
    (steps.prepareAutotools { name = "libxslt.prepare"; })
    (lib.optional cryptoEnabled (
      command "libxslt.crypto-declaration" ''
        # The gcrypt code uses the C string API.
        if ! grep -Fqx '#include <string.h>' libexslt/crypto.c; then
          sed -i '1i #include <string.h>' libexslt/crypto.c
        fi
      ''
    ))
    (command "libxslt.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ${lib.optionalString pythonEnabled ''
        export PYTHON=${bindingPython}/bin/python3
        export PYTHONPATH=${final.libxml2.development.pythonModuleDirectory}
      ''}
      ./configure --prefix="$out" ${lib.escapeShellArg pythonFlag} ${if cryptoEnabled then "--with-crypto" else "--without-crypto"} --disable-static
      ${lib.optionalString cryptoEnabled "grep -Fxq '#define HAVE_GCRYPT 1' config.h"}
    '')
    (command "libxslt.build" "${make}${pythonMakeFlags}")
    (command "libxslt.install" ''
      ${make} install${pythonMakeFlags}
      ${lib.optionalString pythonEnabled ''
        test -f "$out/${pythonLayout}/libxslt.py"
        test -f "$out/${pythonLayout}/libxsltmod.so"
      ''}
      test -x "$out/bin/xsltproc"
      test -f "$out/include/libxslt/xslt.h"
      test -f "$out/lib/pkgconfig/libxslt.pc"
    '')
    (steps.split "libxslt.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libxslt.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (outputs.shebangs {
      paths = [ "bin/xslt-config" ];
      names = [ "sh" ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.strip { inherit paths; })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = [ final.libxml2 ] ++ lib.optional cryptoEnabled final.libgcrypt; })
    (outputs.checkPaths { inherit paths; })
  ];
  meta = {
    description = "XSLT processor and libraries based on libxml2";
    homepage = "https://gitlab.gnome.org/GNOME/libxslt";
    license = lib.licenses.mit;
    mainProgram = "xsltproc";
    platforms = [ "x86_64-linux" ];
  };
}

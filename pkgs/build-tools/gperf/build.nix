# Gperf 3.1–3.3: shipped generated files, one complete C++ production procedure.
{
  tvp,
  lib,
  base,
  src,
  version,
  libstdcxx ? null,
  doCheck ? true,
  configureFlags ? [ ],
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  checkpoint = "nix-support/gperf-build-tree";
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
in
{
  pname = "gperf";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    libstdcxx
    doCheck
    configureFlags
    ;
  inherit (tools) bash coreutils;
  sourceLayout.generated = true;
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ ];
  };
  # The default C++ ABI comes from the effective base compiler. Preserve the
  # explicit runtime override without capturing an unrelated candidate profile.
  runtime.libraries = lib.optional (final.libstdcxx != null) final.libstdcxx;
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools { name = "gperf.prepare"; })
    (command "gperf.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "gperf.build" make)
    (command "gperf.install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (command "gperf.save-build-tree" ''
      ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
    '')
  ];
  upstreamPlan = artifact: [
    {
      name = "gperf.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }
  ];
  upstreamCheck =
    (command "gperf.check" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      status=0
      ${make} TESTSUITEFLAGS="-j$NIX_BUILD_CORES" check || status=$?
      ${tools.findutils}/bin/find . \( -name '*suite.log' -o -name 'test-suite.log' \) -exec ${tools.coreutils}/bin/cat {} \; >&2
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "gperf.finalize")
    (outputs.copyArtifacts { })
    {
      name = "gperf.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "gperf.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" '{}' ${../../../lib/installed-tree.py}'';
    }
    (outputs.strip { paths = [ "bin" ]; })
    (outputs.rpaths {
      paths = [ "bin" ];
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development { libraries = [ ]; })
    (outputs.checkPaths { paths = [ "bin" ]; })
  ];
  meta = {
    homepage = "https://www.gnu.org/software/gperf/";
    description = "GNU perfect hash function generator";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "gperf";
  };
}

# GN's construction Python is an independent source-owned tool, not runtime ABI.
{
  lib,
  tvp,
  base,
  src,
  version,
  bash,
  coreutils,
  python,
  ninja,
  binutils,
  patchelf,
  revision,
  hardeningDisable,
  allowWarnings,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      name = "gn.${name}";
      cwd = "source";
      run = ''
        export NIX_HARDENING_ENABLE=${lib.escapeShellArg (lib.concatStringsSep " " (lib.subtractLists final.hardeningDisable final.base.compiler.defaultHardeningFlags))}
        ${run}
      '';
    };
in
{
  pname = "gn";
  inherit
    base
    src
    version
    bash
    coreutils
    python
    revision
    hardeningDisable
    allowWarnings
    ;
  environment.tools = [
    python
    ninja
  ];
  runtime.libraries = environment.libraries;
  tvp = {
    cc = final.base.compiler;
    revision = final.revision;
  };
  plan = steps.sequence [
    {
      name = "source.copy";
      tools = [ coreutils ];
      run = ''cp -R ${final.src} source; chmod -R u+w source'';
    }
    (command "configure" ''
      ${python}/bin/python3 build/gen.py --no-last-commit-position --no-static-libstdc++ --no-strip ${lib.optionalString final.allowWarnings "--allow-warnings"}
      printf '%s\n' '#define LAST_COMMIT_POSITION_NUM 0' ${lib.escapeShellArg ''#define LAST_COMMIT_POSITION "${final.revision}"''} > out/last_commit_position.h
    '')
    (command "build" ''${ninja}/bin/ninja -C out -j"$NIX_BUILD_CORES"'')
    ((command "check" ''out/gn_unittests'') // { enabled = doCheck; })
    (command "install" ''
      install -Dm755 out/gn "$out/bin/gn"
      install -Dm644 LICENSE "$out/share/licenses/gn/LICENSE"
    '')
    (outputs.strip {
      inherit python binutils;
      paths = [ "bin" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      paths = [ "bin" ];
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "bin" ];
    })
  ];
  meta = {
    description = "GN meta-build system at the exact revision required by Dart";
    homepage = "https://gn.googlesource.com/gn/";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "gn";
  };
}

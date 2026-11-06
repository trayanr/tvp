# One source-only PEP 517 procedure, shared by explicit package definitions.
# Backends are executed as declared; no package manager or dependency resolution.
{
  lib,
  base,
  bash,
  coreutils,
  tvp,
  python,
  gnutar,
  gzip,
  findutils,
  pname,
  version,
  src,
  buildModules ? [ ],
  runtimeModules ? [ ],
  backend ? null,
  environmentValues ? { },
  patches ? [ ],
  patch,
}:
final:
let
  modules = xs: lib.unique (lib.concatMap (p: [ p ] ++ (p.pythonRuntimeModules or [ ])) xs);
  sites = xs: lib.concatStringsSep ":" (map (p: "${p}/lib/python3.12/site-packages") (modules xs));
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
in
{
  inherit patches;
  inherit
    pname
    version
    src
    base
    bash
    coreutils
    ;
  passthru.pythonRuntimeModules = modules runtimeModules;
  environment = {
    tools = [
      python
      patch
    ];
    libraries = [ ];
    overrides.values = environmentValues;
  };
  plan = tvp.builder.steps.sequence [
    (tvp.builder.steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (command "python.patch" (
      lib.concatMapStringsSep "\n" (p: "${patch}/bin/patch -p1 < ${p}") final.patches
    ))
    (command "python.build" ''
      export PYTHONPATH=${lib.escapeShellArg (sites buildModules)}
      export PYTHONNOUSERSITE=1 PYTHONDONTWRITEBYTECODE=1
      export SOURCE_DATE_EPOCH=315532800 HOME="$TMPDIR"
      ${python}/bin/python3 -B ${./pep517.py} build ${
        lib.escapeShellArg (if backend == null then "" else backend)
      } ${lib.escapeShellArg final.version}
    '')
    (command "python.install" ''
      ${python}/bin/python3 -I -B ${./pep517.py} install "$out" \
        ${lib.escapeShellArg (sites runtimeModules)} ${python}/bin/python3 ${bash}/bin/bash
    '')
  ];
  meta = {
    description = "Source-built ${pname} for the selected GCC Python harness";
    platforms = [ "x86_64-linux" ];
  };
}

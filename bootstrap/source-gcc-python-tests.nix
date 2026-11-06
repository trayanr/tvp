# Explicit opt-in source Python packages; all earlier endpoints are reused.
{
  bootstrap ? import ./. { },
}:
let
  harness = import ./source-gcc-test-harness.nix { inherit bootstrap; };
  inherit (harness) tools;
  inherit (harness.composition)
    lib
    base
    bash
    coreutils
    builder
    ;
  sources = builtins.mapAttrs (_: import <nix/fetchurl.nix>) (
    builtins.fromJSON (builtins.readFile ./source-gcc-python-sources.json)
  );
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-gcc-python";
      mkTests = _: { };
    };
  package =
    name: version: buildModules: runtimeModules: environmentValues:
    make (import ./recipes/python/pep517.nix) {
      inherit
        lib
        base
        bash
        coreutils
        version
        buildModules
        runtimeModules
        environmentValues
        ;
      tvp = {
        inherit builder;
      };
      python = tools.python;
      gnutar = tools.tar;
      inherit (tools) gzip findutils;
      patch = tools.patch;
      patches = lib.optional (
        name == "check-jsonschema"
      ) ./recipes/python/patches/check-jsonschema-draft-id.patch;
      pname = "source-python-${name}";
      src = sources.${name};
    };
  packages = rec {
    json5 = package "json5" "0.9.25" [
      packages.setuptools
      packages.wheel
    ] [ ] { };
    rfc3987 = package "rfc3987" "1.3.8" [
      packages.setuptools
      packages.wheel
    ] [ ] { };
    "pygments" = package "pygments" "2.18.0" [ packages.hatchling ] [ ] { };
    "Cython" = package "Cython" "3.0.11" [
      packages.setuptools
      packages.wheel
    ] [ ] { NO_CYTHON_COMPILE = "true"; };
    "typing_extensions" = package "typing_extensions" "4.12.2" [ packages."flit_core" ] [ ] { };
    "PyYAML" = package "PyYAML" "6.0.2" [
      packages.Cython
      packages."setuptools"
      packages."wheel"
    ] [ ] { PYYAML_FORCE_LIBYAML = "0"; };
    "arrow" = package "arrow" "1.3.0" [ packages."flit_core" ] [
      packages."python-dateutil"
      packages."types-python-dateutil"
    ] { };
    "attrs" = package "attrs" "23.2.0" [
      packages."hatchling"
      packages."hatch-vcs"
      packages."hatch-fancy-pypi-readme"
    ] [ ] { };
    "calver" = package "calver" "2022.6.26" [
      packages."setuptools"
      packages."wheel"
    ] [ ] { };
    "certifi" = package "certifi" "2024.7.4" [
      packages."setuptools"
      packages."wheel"
    ] [ ] { };
    "charset-normalizer" = package "charset-normalizer" "3.3.2" [
      packages."setuptools"
      packages."wheel"
    ] [ ] { CHARSET_NORMALIZER_USE_MYPYC = "0"; };
    "check-jsonschema" =
      package "check-jsonschema" "0.23.3"
        [
          packages."setuptools"
          packages."wheel"
        ]
        [
          packages.json5
          packages.rfc3987
          packages."ruamel.yaml"
          packages."jsonschema"
          packages."requests"
          packages."click"
          packages."fqdn"
          packages."isoduration"
          packages."jsonpointer"
          packages."rfc3339-validator"
          packages."rfc3986-validator"
          packages."uri-template"
          packages."webcolors"
        ]
        { };
    "click" = package "click" "8.1.7" [
      packages."setuptools"
      packages."wheel"
    ] [ ] { };
    "flit_core" = package "flit_core" "3.9.0" [ ] [ ] { };
    "fqdn" = package "fqdn" "1.5.1" [
      packages."setuptools"
      packages."wheel"
    ] [ ] { };
    "hatch-fancy-pypi-readme" = package "hatch-fancy-pypi-readme" "24.1.0" [ packages."hatchling" ] [
      packages."hatchling"
    ] { };
    "hatch-vcs" = package "hatch-vcs" "0.4.0" [ packages."hatchling" ] [
      packages."hatchling"
      packages."setuptools-scm"
    ] { };
    "hatchling" =
      package "hatchling" "1.25.0"
        [
          packages."packaging"
          packages."pathspec"
          packages."pluggy"
          packages."trove-classifiers"
        ]
        [
          packages."packaging"
          packages."pathspec"
          packages."pluggy"
          packages."trove-classifiers"
        ]
        { };
    "idna" = package "idna" "3.7" [ packages."flit_core" ] [ ] { };
    "iniconfig" = package "iniconfig" "2.0.0" [
      packages."hatchling"
      packages."hatch-vcs"
    ] [ ] { };
    "isoduration" = package "isoduration" "20.11.0" [
      packages."setuptools"
      packages."wheel"
    ] [ packages."arrow" ] { };
    "jsonpointer" = package "jsonpointer" "3.0.0" [
      packages."setuptools"
      packages."wheel"
    ] [ ] { };
    "jsonschema" =
      package "jsonschema" "4.17.3"
        [
          packages."hatchling"
          packages."hatch-vcs"
          packages."hatch-fancy-pypi-readme"
        ]
        [
          packages."attrs"
          packages."pyrsistent"
        ]
        { };
    "packaging" = package "packaging" "24.1" [ packages."flit_core" ] [ ] { };
    "pathspec" = package "pathspec" "0.12.1" [ packages."flit_core" ] [ ] { };
    "pluggy" = package "pluggy" "1.5.0" [
      packages."setuptools"
      packages."wheel"
      packages."setuptools-scm"
    ] [ ] { };
    "pyrsistent" = package "pyrsistent" "0.19.3" [
      packages."setuptools"
      packages."wheel"
    ] [ ] { PYRSISTENT_SKIP_EXTENSION = "1"; };
    "pytest" =
      package "pytest" "8.3.2"
        [
          packages."setuptools"
          packages."wheel"
          packages."setuptools-scm"
        ]
        [
          packages."iniconfig"
          packages."packaging"
          packages."pluggy"
        ]
        { };
    "python-dateutil" = package "python-dateutil" "2.9.0.post0" [
      packages."setuptools"
      packages."wheel"
      packages."setuptools-scm"
    ] [ packages."six" ] { };
    "requests" =
      package "requests" "2.32.3"
        [
          packages."setuptools"
          packages."wheel"
        ]
        [
          packages."urllib3"
          packages."certifi"
          packages."charset-normalizer"
          packages."idna"
        ]
        { };
    "responses" =
      package "responses" "0.23.1"
        [
          packages."setuptools"
          packages."wheel"
        ]
        [
          packages."requests"
          packages."urllib3"
          packages."PyYAML"
          packages."types-PyYAML"
        ]
        { };
    "rfc3339-validator" = package "rfc3339-validator" "0.1.4" [
      packages."setuptools"
      packages."wheel"
    ] [ packages."six" ] { };
    "rfc3986-validator" = package "rfc3986-validator" "0.1.1" [
      packages."setuptools"
      packages."wheel"
    ] [ ] { };
    "ruamel.yaml" = package "ruamel.yaml" "0.17.32" [
      packages."setuptools"
      packages."wheel"
    ] [ ] { };
    "setuptools" = package "setuptools" "69.5.1" [ packages."wheel" ] [ ] { };
    "setuptools-scm" =
      package "setuptools-scm" "7.1.0"
        [
          packages."setuptools"
          packages."wheel"
          packages."packaging"
          packages."typing_extensions"
        ]
        [
          packages."packaging"
          packages."setuptools"
          packages."typing_extensions"
        ]
        { };
    "six" = package "six" "1.16.0" [
      packages."setuptools"
      packages."wheel"
    ] [ ] { };
    "trove-classifiers" = package "trove-classifiers" "2024.7.2" [
      packages."setuptools"
      packages."wheel"
      packages."calver"
    ] [ ] { };
    "types-PyYAML" = package "types-PyYAML" "6.0.12.20240917" [
      packages."setuptools"
      packages."wheel"
    ] [ ] { };
    "types-python-dateutil" = package "types-python-dateutil" "2.9.0.20240906" [
      packages."setuptools"
      packages."wheel"
    ] [ ] { };
    "uri-template" = package "uri-template" "1.3.0" [
      packages."setuptools"
      packages."wheel"
      packages."setuptools-scm"
    ] [ ] { };
    "urllib3" = package "urllib3" "2.2.2" [ packages."hatchling" ] [ ] { };
    "webcolors" = package "webcolors" "24.8.0" [
      packages."setuptools"
      packages."wheel"
    ] [ ] { };
    "wheel" = package "wheel" "0.44.0" [ packages."flit_core" ] [ ] { };
  };
  profile = make (
    { }:
    final: {
      pname = "source-gcc-python-profile";
      version = "1";
      src = null;
      inherit base bash coreutils;
      environment = {
        tools = [ tools.python ];
        libraries = [ ];
      };
      pythonModules = lib.unique (
        lib.concatMap (p: [ p ] ++ p.pythonRuntimeModules) [
          packages.pytest
          packages."check-jsonschema"
        ]
      );
      plan = [
        (
          (final.base.environment final.environment)
          // {
            name = "python.profile";
            run =
              let
                paths = lib.concatStringsSep ":" (map (p: "${p}/lib/python3.12/site-packages") final.pythonModules);
              in
              ''
                mkdir -p "$out/bin"
                cat > "$out/bin/python3" <<'SCRIPT'
                #!${bash}/bin/bash
                export PYTHONNOUSERSITE=1
                export PYTHONPATH=${lib.escapeShellArg paths}''${PYTHONPATH:+:$PYTHONPATH}
                exec ${tools.python}/bin/python3 -s "$@"
                SCRIPT
                chmod +x "$out/bin/python3"
                ln -s ${packages.pytest}/bin/pytest "$out/bin/pytest"
                ln -s ${packages."check-jsonschema"}/bin/check-jsonschema "$out/bin/check-jsonschema"
              '';
          }
        )
      ];
    }
  ) { };
in
{
  inherit
    harness
    tools
    sources
    packages
    profile
    ;
  composition = harness.composition;
}

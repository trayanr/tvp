# Native ordinary 1.70.0: lib-only Autotools, raw upstream make check,
# shared/static/pkg-config install; the former stdenv procedure stays frozen.
{
  tvp,
  lib,
  base,
  src,
  version,
  binutils,
  doCheck ? true,
}@args:

final:
let
  inherit (final)
    base
    src
    version
    bash
    coreutils
    ;
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs;
  baseTools = context.tools;
  inherit (final)
    gnumake
    gnutar
    xz
    pkg-config
    sed
    grep
    gawk
    diffutils
    findutils
    python
    patchelf
    ;
  productionMake =
    target:
    lib.concatMapStringsSep "\n"
      (
        directory:
        let
          localTarget =
            if directory == "." then (if target == "all" then "all-am" else "install-am") else target;
        in
        ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" -C ${lib.escapeShellArg directory} SHELL=${final.bash}/bin/bash ${localTarget}''
      )
      [
        "lib"
        "doc"
        "."
      ];
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "nghttp2.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'';
in
{
  pname = "nghttp2";
  inherit doCheck;
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  xz = baseTools.xz;
  pkg-config = baseTools.pkg-config;
  sed = baseTools.sed;
  grep = baseTools.grep;
  gawk = baseTools.gawk;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  python = baseTools.python;
  patchelf = baseTools.patchelf;

  inherit (args)
    base
    src
    version
    ;
  environment = {
    tools = [
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
      pkg-config
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  upstreamCheck =
    (builtins.head (
      builtins.filter (
        step: step.name == "nghttp2.check" || step.name == "nghttp2.check-upstream" || step.name == "check"
      ) (steps.partition final.originalPlan).first
    ))
    // {
      enabled = final.doCheck;
    };
  originalPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz findutils;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      inherit python base bash;
      name = "nghttp2.prepare";
    })
    (command "configure" ''
      export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash
      ./configure --prefix="$out" --enable-lib-only
    '')
    (command "build" (productionMake "all"))
    ((command "check" "${make} check") // { enabled = doCheck; })
    (command "install" ''
      ${productionMake "install"}
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "nghttp2.finalize")
    (outputs.copyArtifacts { inherit coreutils; })
    (outputs.relocateText {
      inherit python;
      paths = [
        "lib/pkgconfig/libnghttp2.pc"
        "lib/libnghttp2.la"
      ];
    })
    (outputs.strip {
      inherit python binutils;
      paths = [ "lib" ];
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [ "lib" ];
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libnghttp2.so"
        "lib/libnghttp2.so.14"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "lib" ];
    })
  ];
  tvp.features = {
    inherit doCheck;
    libOnly = true;
    shared = true;
    static = true;
    pkgConfig = true;
  };
  meta = {
    description = "HTTP/2 C library with HPACK compression";
    homepage = "https://nghttp2.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
  upstreamPlan = artifact: [
    {
      name = "nghttp2.restore-build-tree";
      tools = [ baseTools.python ];
      run = ''
        ${baseTools.python}/bin/python3 -B ${../../build-tools/utilities-restore.py} ${artifact}/nix-support/nghttp2-build-tree "$TVP_SOURCE_ROOT"
        printf '%s\n' ${artifact} > "$TVP_SOURCE_ROOT/production-artifact"
      '';
    }
  ];
  plan =
    let
      parts = steps.partition final.originalPlan;
      production = builtins.filter (step: !(builtins.elem step.name [ "nghttp2.check" ])) parts.first;
    in
    production
    ++ [
      {
        name = "nghttp2.save-build-tree";
        tools = [
          baseTools.python
          final.coreutils
        ];
        run = ''
          ${baseTools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/nix-support/nghttp2-build-tree"
        '';
      }
    ]
    ++ (lib.optional parts.split (steps.split "nghttp2.finalize"))
    ++ [
      (builtins.head parts.second)
      {
        name = "nghttp2.drop-build-tree";
        tools = [ final.coreutils ];
        run = ''${final.coreutils}/bin/rm -rf -- "$out/nix-support/nghttp2-build-tree"'';
      }
    ]
    ++ builtins.tail parts.second;

}

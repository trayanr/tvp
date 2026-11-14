# Bzip2 1.0.6–1.0.8 share Makefiles, PIC/static/shared build order and ABI.
{
  tvp,
  lib,
  base,
  src,
  version,
  doCheck ? true,
  helperInterface ? "caller-tools",
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  checkpoint = "nix-support/bzip2-build-tree";
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash CC=cc'';
  elfPaths = [
    "bin/bzip2"
    "bin/bunzip2"
    "bin/bzcat"
    "bin/bzip2recover"
    "lib/libbz2.so.${final.version}"
  ];
in
{
  pname = "bzip2";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    doCheck
    helperInterface
    ;
  inherit (tools) bash coreutils;
  installedInterface = {
    soname = "libbz2.so.1.0";
    helpers = final.helperInterface;
  };
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
  runtime = {
    libraries = [ ];
    shell = tools.bash;
    pager = tools.coreutils;
    tools = [
      tools.coreutils
      tools.sed
      tools.grep
      tools.diffutils
    ];
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    {
      name = "bzip2.prepare";
      cwd = "source";
      tools = [ tools.python ];
      # The shared production-only helper is supplied by the XZ candidate.
      # The original combined helper remains exact for earlier callers.
      run = ''${tools.python}/bin/python3 -B ${../../libraries/ordinary-compression-production.py} bzip2 ${tools.bash}/bin/bash ${../../libraries/compression-source-tree.py}'';
    }
    (command "bzip2.build" ''
      # Upstream static objects intentionally reuse the shared build's PIC objects.
      ${make} -f Makefile-libbz2_so
      ${make} libbz2.a bzip2 bzip2recover
    '')
    (command "bzip2.install" ''
      ${make} install PREFIX="$out"
      for pair in 'bzegrep bzgrep' 'bzfgrep bzgrep' 'bzless bzmore' 'bzcmp bzdiff'; do
        set -- $pair
        ln -sfn "$2" "$out/bin/$1"
      done
      cp libbz2.so.${final.version} "$out/lib/"
      ln -s libbz2.so.${final.version} "$out/lib/libbz2.so.1.0"
      ln -s libbz2.so.1.0 "$out/lib/libbz2.so.1"
      ln -s libbz2.so.1.0 "$out/lib/libbz2.so"
      mkdir -p "$out/nix-support" "$out/share"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (command "bzip2.save-build-tree" ''
      ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
    '')
  ];
  upstreamPlan = artifact: [
    {
      name = "bzip2.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }
  ];
  upstreamCheck = (command "bzip2.check" "${make} check") // {
    enabled = final.doCheck;
  };
  plan =
    assert builtins.elem final.helperInterface [
      "caller-tools"
      "declared-tools"
    ];
    final.productionPlan
    ++ [
      (steps.split "bzip2.finalize")
      # Upstream installs hardlinked manual aliases. F owns each mutable payload.
      (outputs.copyArtifacts { preserveHardlinks = false; })
      {
        name = "bzip2.drop-build-tree";
        tools = [ tools.coreutils ];
        run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
      }
      {
        name = "bzip2.relocate";
        tools = [ tools.python ];
        run = ''${tools.python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" '{}' ${../../../lib/installed-tree.py}'';
      }
      {
        name = "bzip2.manual-layout";
        run = ''mv "$out/man" "$out/share/man"'';
      }
      {
        name = "bzip2.bind-helpers";
        tools = [ tools.python ];
        run = ''${tools.python}/bin/python3 -B ${./bind-helpers.py} "$out" ${
          lib.escapeShellArg (
            builtins.toJSON {
              declared = final.installedInterface.helpers == "declared-tools";
              shell = "${final.runtime.shell}/bin/bash";
              pager = "${final.runtime.pager}/bin/cat";
              paths = map (p: "${p}/bin") final.runtime.tools;
            }
          )
        }'';
      }
      (outputs.strip { paths = elfPaths; })
      (outputs.stripArchives { paths = [ "lib/libbz2.a" ]; })
      (outputs.rpaths {
        paths = elfPaths;
        libraries = final.runtime.libraries;
        dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      })
      (outputs.development { libraries = [ ]; })
      {
        name = "output.manuals";
        tools = [
          tools.gzip
          tools.findutils
        ];
        run = ''for path in "$out"/share/man/man1/*.1; do ${tools.gzip}/bin/gzip -n -9 "$path"; done'';
      }
      (outputs.checkSymlinks {
        paths = [
          "lib/libbz2.so"
          "lib/libbz2.so.1"
          "lib/libbz2.so.1.0"
          "bin/bzegrep"
          "bin/bzfgrep"
          "bin/bzless"
          "bin/bzcmp"
        ];
      })
      (outputs.checkPaths { paths = elfPaths; })
    ];
  tvp.features = {
    shared = true;
    static = true;
  };
  meta = {
    description = "Bzip2 compression utility and library";
    license = lib.licenses.bsdOriginal;
    platforms = [ "x86_64-linux" ];
    mainProgram = "bzip2";
  };
}

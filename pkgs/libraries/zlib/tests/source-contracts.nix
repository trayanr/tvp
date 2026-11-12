# Pure evaluation controls for the whole eligible migration. No realization.
# nix eval --impure --json --expr 'let pkgs = ...; tvp = import ./. { inherit pkgs; }; in import ./pkgs/libraries/zlib/tests/source-contracts.nix { inherit pkgs tvp; }'
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps;
  family = lib.filterAttrs (name: _: lib.hasPrefix "zlib_" name) tvp.canonical;
  eligible = lib.filterAttrs (
    _: p: p.tvp.status.level != "broken" && (lib.versionOlder p.version "1.2.3" || p.version == "1.3.2")
  ) family;
  plain = builtins.unsafeDiscardStringContext;
  inspect =
    name: p:
    let
      s = p.specification;
      parts = steps.partition s.plan;
      disabled = p.override { doCheck = false; };
      stripped = p.edit (old: old // { stripFlags = [ "-S" ]; });
      marker = p.editSteps (
        steps.insertAfter "output.copy-artifacts" [
          {
            name = "contract.final-only";
            run = ''printf marker > "$out/final-marker"'';
          }
        ]
      );
      runtime = p.editRuntime (r: r // { tools = r.tools ++ [ s.tools.gawk ]; });
      source = p.override { src = builtins.toFile "zlib-source-differential" "source sentinel"; };
      build = p.editSteps (
        steps.replace "zlib.build" (old: old // { run = old.run + "\nprintf build-sentinel\n"; })
      );
      compilerTool = p.override { gnumake = s.tools.grep; };
      upstreamSteps = p.tests.upstream.buildSteps;
      check = builtins.elemAt upstreamSteps (builtins.length upstreamSteps - 1);
      testEdit = p.tests.upstream.editSteps (
        steps.replace "test.compare" (old: old // { run = "printf test-only-sentinel"; })
      );
      finalNames = map (step: step.name) parts.second;
    in
    assert parts.split;
    assert
      map (step: step.name) parts.first == [
        "source.unpack"
        "zlib.prepare"
        "zlib.configure"
        "zlib.build"
        "zlib.install"
      ];
    assert builtins.head finalNames == "output.copy-artifacts";
    assert builtins.elem "zlib.relocate-runtime" finalNames;
    assert builtins.elem "output.strip" finalNames;
    assert builtins.elem "output.rpaths" finalNames;
    assert p.artifact.drvPath != p.drvPath;
    assert stripped.artifact.drvPath == p.artifact.drvPath && stripped.drvPath != p.drvPath;
    assert marker.artifact.drvPath == p.artifact.drvPath && marker.drvPath != p.drvPath;
    assert runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    assert disabled.artifact.drvPath == p.artifact.drvPath && disabled.drvPath == p.drvPath;
    assert !(disabled.tests ? upstream);
    assert source.artifact.drvPath != p.artifact.drvPath;
    assert build.artifact.drvPath != p.artifact.drvPath;
    assert compilerTool.artifact.drvPath != p.artifact.drvPath;
    assert
      map (step: step.name) upstreamSteps == [
        "source.unpack"
        "zlib.prepare"
        "zlib.configure"
        "zlib.build"
        "test.compare"
      ];
    assert lib.hasInfix "make -j1" check.run && lib.hasInfix "upstream-check.log" check.run;
    assert lib.hasInfix ''exit "$status"'' check.run;
    assert testEdit.drvPath != p.tests.upstream.drvPath;
    # Test-only payload edits cannot enter either production runner context.
    assert
      !(builtins.hasAttr (plain p.tests.upstream.drvPath) (builtins.getContext p.artifact.drvPath));
    assert !(builtins.hasAttr (plain p.tests.upstream.drvPath) (builtins.getContext p.drvPath));
    {
      artifact = plain p.artifact.drvPath;
      final = plain p.drvPath;
      upstream = plain p.tests.upstream.drvPath;
      pass = true;
    };
in
assert builtins.length (builtins.attrNames family) == 75;
assert builtins.length (builtins.attrNames eligible) == 31;
lib.mapAttrs inspect eligible

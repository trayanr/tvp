{ pkgs, tvp }:
let
  source = ../..;
  names = [
    "xorgproto"
    "xtrans"
    "xcb-proto"
    "libxau"
    "libxdmcp"
    "libxcb"
    "libice"
    "libsm"
    "libx11"
  ];
  ids = builtins.mapAttrs (_: p: p.drvPath);
  has =
    needle: haystack:
    pkgs.lib.hasInfix (builtins.unsafeDiscardStringContext needle) (
      builtins.unsafeDiscardStringContext haystack
    );
  control =
    name:
    let
      p = tvp.packages.${name};
      retained = import (source + "/pkgs/libraries/${name}/legacy.nix") { inherit pkgs tvp; };
      base = p.specification.base.override { name = "x11-override-base"; };
      bash = p.specification.bash // {
        outPath = "/nix/store/00000000000000000000000000000000-bash-control";
      };
      tool = p.specification.gnumake // {
        outPath = "/nix/store/11111111111111111111111111111111-make-control";
      };
      changed = p.override {
        inherit base bash;
        gnumake = tool;
      };
      edited = p.edit (
        s:
        s
        // {
          inherit base bash;
          gnumake = tool;
          src = builtins.toFile "x11-source-control" "control";
        }
      );
      toolProvider = p.override { pkgConfig = tool; };
      changedSrc = p.override { src = builtins.toFile "x11-source-override" "control"; };
      unpack = q: builtins.head q.buildSteps;
      configure = q: builtins.head (builtins.filter (s: s.name == "${name}.configure") q.buildSteps);
      install = q: builtins.head (builtins.filter (s: s.name == "${name}.install") q.buildSteps);
      selectedPkgs = {
        runCommandWith = args: script: { selectedTestPkgs = true; };
      };
      publicFactory =
        (import (source + "/pkgs/libraries/${name}") { inherit pkgs tvp; })
        .recipes.${name}.extraArgs.mkTests;
      retainedPackage = retained.aliases.${name};
      libChanged = p.edit (
        s:
        s
        // {
          environment = s.environment // {
            libraries = [ tvp.packages.zlib ];
          };
        }
      );
    in
    {
      legacyTestsExact = ids (publicFactory retainedPackage) == ids retainedPackage.tests;
      callerPkgsOverride =
        ((publicFactory.override { pkgs = pkgs // selectedPkgs; }) retainedPackage)
        .consumer.selectedTestPkgs or false;
      srcOverride =
        changedSrc.drvPath != p.drvPath
        && has (toString changedSrc.specification.src) (unpack changedSrc).run;
      srcEdit = has (toString edited.specification.src) (unpack edited).run;
      baseOverride = changed.tvp.base == "x11-override-base" && changed.testContext != null;
      bashOverride = has "${bash}/bin/bash" (configure changed).run;
      bashEdit = has "${bash}/bin/bash" (configure edited).run;
      toolOverride = has "${tool}/bin/make" (install changed).run;
      toolEdit = has "${tool}/bin/make" (install edited).run;
      toolProviderOverride = builtins.elem tool.outPath (map toString (configure toolProvider).tools);
      libraryEdit =
        builtins.any (l: l.outPath == tvp.packages.zlib.outPath)
          (configure libChanged).libraries;
      testShell = builtins.elem bash.outPath (map toString changed.tests.consumer.buildStepRunner.inputs);
      ownedRegularTests = builtins.all (t: (t.tvp.kind or "") == "owned-test") (
        builtins.attrValues p.tests
      );
      publicDevelopment = map toString p.development.libraries;
    };
  contracts = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = control name;
    }) names
  );
  failed = builtins.filter (
    name:
    !(builtins.all (value: !builtins.isBool value || value) (builtins.attrValues contracts.${name}))
  ) names;
in
assert failed == [ ] || throw "Owned X11 contracts: ${builtins.concatStringsSep ", " failed}";
(tvp.packages.xorgproto.testContext.mkTest {
  package = tvp.packages.xorgproto;
  name = "source-contracts";
  script = "printf '%s' '${builtins.toJSON contracts}'";
  expected = builtins.toJSON contracts;
})
// {
  inherit contracts;
}

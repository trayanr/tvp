{
  lib,
  fetchGit ? null,
}:
let
  genericRecipe = import ./build-gem.nix;
  genericArguments = builtins.functionArgs genericRecipe;
  commonDefaults = {
    dependencies = [ ];
    libraries = [ ];
    tools = [ ];
    buildFlags = [ ];
    patches = [ ];
    sourceType = "gem";
    sourceSubdir = ".";
    platform = "ruby";
  };
  definitionsFor =
    tvp:
    import ./definitions {
      inherit lib;
      helpers.writePatch =
        final: name: text:
        tvp.builder {
          recipe = { base, text }: {
            pname = "ruby-gem-${name}";
            version = "1";
            src = null;
            inherit base;
            bash = base.shell;
            coreutils = base.coreutils;
            plan = [
              {
                name = "gem.patch";
                run = ''printf '%s' ${lib.escapeShellArg text} > "$out"'';
              }
            ];
          };
          args = {
            inherit text;
            base = final.base;
          };
          dependencyNames = [ ];
          metadata = {
            definition = name;
            kind = "ruby-gem-patch";
            status.level = "ok";
          };
          selection.kind = "generated";
          mkTests = _: { };
        };
    };
in
{
  # The same definition is selected for direct and locked-bundle builds.
  buildGem =
    arguments@{
      tvp,
      ruby,
      name,
      version,
      src,
      ...
    }:
    let
      definitions = definitionsFor tvp;
      definition = definitions.${name} or { };
      inputs = definition.inputs or { };
      configure = definition.configure or (_: { });
      declared = genericArguments // builtins.mapAttrs (_: _: true) inputs;
      recipe = lib.setFunctionArgs (
        args: final:
        let
          generic = genericRecipe (builtins.intersectAttrs genericArguments args) final;
        in
        generic
        // (builtins.intersectAttrs inputs args)
        // (builtins.removeAttrs (configure final) (builtins.attrNames genericArguments))
        // {
          passthru = generic.passthru // {
            nativeProviders = builtins.intersectAttrs inputs final;
          };
        }
      ) declared;
    in
    assert builtins.match "[A-Za-z0-9][A-Za-z0-9_.-]*" name != null;
    tvp.builder {
      inherit recipe;
      args = (builtins.removeAttrs arguments [ "name" ]) // {
        inherit lib;
        gemName = name;
      };
      argumentDefaults =
        { arguments, specification }:
        (builtins.mapAttrs (name: fallback: (configure specification).${name} or fallback) commonDefaults)
        // builtins.mapAttrs (_: value: value arguments) inputs
        // {
          base = arguments.ruby.specification.base;
        };
      dependencyNames = [ "ruby" ] ++ builtins.attrNames inputs;
      metadata = {
        builder = "build-gem.nix";
        definition =
          if builtins.hasAttr name definitions then "ruby-gem-${name}" else "custom-ruby-${name}";
        kind = "ruby-gem";
        status.level = "ok";
      };
      selection = {
        kind = "custom";
        category = "ruby-gem";
      };
      mkTests = definition.mkTests or (_: { });
      testContext = package: package.ruby.testContext;
    };

  definitions = definitionsFor;
  bundlerEnv = import ./bundler-env.nix { inherit lib fetchGit; };
  application = import ./application.nix { inherit lib; };
}

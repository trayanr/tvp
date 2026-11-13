# Bind helper implementation inputs once. Explicit call arguments still win.
{
  builder,
  base,
}:
let
  providers = import ./tool-providers.nix;
  tools = builtins.mapAttrs providers.tag (
    (base.standardTools or { })
    // {
      bash = base.shell;
      coreutils = base.coreutils;
      binutils = base.compiler.bintools;
    }
  );
  defaults = tools // {
    inherit base;
    tar = tools.gnutar;
  };
  bind =
    helpers:
    builtins.mapAttrs (
      _: helper:
      if builtins.isFunction helper && builtins.functionArgs helper != { } then
        args:
        helper (
          builtins.mapAttrs (
            name: value:
            let
              role = if name == "tar" then "gnutar" else name;
            in
            providers.tag role value
          ) (builtins.intersectAttrs (builtins.functionArgs helper) defaults // args)
        )
      else if builtins.isAttrs helper then
        bind helper
      else
        helper
    ) helpers;
in
{
  inherit tools;
  steps = bind builder.steps;
  outputs = bind builder.outputs;
}

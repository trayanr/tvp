# Decorate the PHP interface without changing its engine derivation or sources.
{
  lib,
  tvp,
  php,
  catalogue,
}:
let
  engine = php.unwrapped or php;
  decorate =
    value:
    value
    // {
      unwrapped = engine;
      extensions = catalogue.forPHP engine;
      withExtensions =
        {
          extensions ? [ ],
          settings ? { },
        }:
        import ./with-extensions.nix {
          inherit lib tvp settings;
          php = engine;
          extensions =
            if builtins.isFunction extensions then extensions (catalogue.forPHP engine) else extensions;
        };
    }
    //
      lib.genAttrs
        (builtins.filter (name: value ? ${name}) [
          "override"
          "edit"
          "editSteps"
          "editRuntime"
        ])
        (
          name: change:
          import ./interface.nix {
            inherit lib tvp catalogue;
            php = value.${name} change;
          }
        );
  outputs = lib.genAttrs php.outputs (name: decorate php.${name} // outputs);
in
decorate php // outputs

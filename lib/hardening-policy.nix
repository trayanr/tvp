# Native GNU consumer policy, deliberately separate from compiler construction.
{
  defaults ? [ ],
  enable ? [ ],
  disable ? [ ],
}:
let
  supported = [
    "bindnow"
    "fortify"
    "format"
    "pic"
    "relro"
    "stackprotector"
    "strictoverflow"
  ];
  valid =
    xs: builtins.isList xs && builtins.all (x: builtins.isString x && builtins.elem x supported) xs;
  selected = builtins.filter (
    x: builtins.elem x (defaults ++ enable) && !(builtins.elem x disable)
  ) supported;
in
assert
  valid defaults && valid enable && valid disable
  || throw "TVP hardening: expected lists of supported native GNU protection names";
{
  inherit supported selected;
}

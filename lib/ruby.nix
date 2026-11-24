# Derivation-affecting Ruby project helpers use the selected interpreter's base.
{
  lib,
  pkgs ? null,
}:
import ../pkgs/runtimes/ruby/gems { inherit lib pkgs; }

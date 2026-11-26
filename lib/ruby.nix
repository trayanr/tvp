# Derivation-affecting Ruby project helpers use the selected interpreter's base.
{ lib }:
import ../pkgs/runtimes/ruby/gems { inherit lib; }

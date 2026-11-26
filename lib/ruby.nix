# Derivation-affecting Ruby project helpers use the selected interpreter's base.
{
  lib,
  fetchGit ? null,
}:
import ../pkgs/runtimes/ruby/gems { inherit lib fetchGit; }

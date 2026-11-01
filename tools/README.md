# Repository tools

The six apps use TVP's existing Python and shell utilities for their explicit
runtime inputs. Ruby's extension tests separately retain an owned GCC 13
consumer compiler as a cross-compiler control against GCC 16-built Ruby.

The tools still call the host Nix API. jq remains borrowed because the catalogue
has no jq package. The dependencies and test-runner wrappers use owned Bash;
the four `writeShellApplication` scripts retain that helper's runtime shell.
Generic builders, hooks and bootstrap closures are separate from these explicit
runtime choices.

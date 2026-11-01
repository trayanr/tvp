# Repository tools

All six apps are copied by `tools/lib/owned-cli.nix`, a direct derivation run by
TVP Bash with TVP coreutils. It installs explicit Bash shebangs and checks each
script with `bash -n` and ShellCheck (a borrowed build-time validator). It uses
no stdenv setup, wrapper hooks or compiler. Text manifests use `builtins.toFile`.

The four shell commands retain `errexit`, `nounset` and `pipefail`, and prepend
their declared tools in order to the caller's PATH. The Python entrypoints exec
TVP Python, forward every argument, and set `TVP_DEPENDENCIES_SYSTEM` or
`TVP_TEST_SYSTEM` from the selected native platform. They leave PATH alone.
The helper supports these scripts only; it is not a general packaging API.

Explicit runtime utilities and interpreters are TVP packages except jq, which
has no TVP recipe. Commands that query Nix use the caller's host Nix API.
Inherited bootstrap closures and the test runner's external strace boundary
remain separate from this packaging change. Ruby's extension tests retain an
owned GCC 13 consumer compiler as a control against GCC 16-built Ruby.

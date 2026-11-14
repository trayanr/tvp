# Retained Make procedure

These notes describe the retained [owned procedure](build-4.4.1.nix), which is
unsplit. The public [definition](../default.nix) selects the split
[native procedure](../native/build-4.4.1.nix). For new recipes, follow the
[current authoring guide](../../../../lib/NATIVE-RECIPES.md).

The retained procedure keeps its configured installation prefix in one stage.
Its native default shell is the declared runtime Bash; the upstream harness uses that same shell
for its diagnostic probe.

The archive's regression suite is run in full. Case 9 of misc/general4 fails
because libc's default PATH points at absent system directories in the Nix
sandbox. The raw failure stays visible; the check requires that exact missing
echo diagnostic and rejects any additional failure. No runtime Coreutils is
added to hide this inherited behavior. Guile load API and VMS cases remain
unavailable as reported by the upstream harness.

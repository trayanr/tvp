This isolated internal fixture consumes the edited build plan once, and runs
only known active fields. It is not a package builder or public API.

Each step gets fresh owned Bash with errexit, nounset, pipefail and
inherit_errexit. Files persist in one prepared source root; relative cwd is
resolved from that root when the step starts. Scripts execute at top level.
Bash deliberately handled failures (conditions, `!`, nonfinal AND/OR terms)
remain handled; errexit is not an error detector for those expressions.

The existing owned native base setup is deliberately sourced in each child.
Input/environment setup hooks remain underneath this fixture. Environment dumps
and setup's legacy EXIT handler are disabled before the step body. Selected tools
are nativeBuildInputs and libraries are buildInputs, with the existing native
setup's propagation and search hooks, not a newly implemented search policy.
The common base floor/compiler remains available. The union is a Nix dependency,
never a global execution PATH. Caller environment is cleared except HOME,
TMPDIR, NIX_BUILD_TOP and out (the caller supplies the normal Nix output path
for compiler use); step env is applied after setup. Compiler settings
such as CC/CXX/CFLAGS and NIX_CFLAGS_COMPILE/NIX_CFLAGS_LINK/NIX_LDFLAGS
are allowed; shell/loader/logging
controls and base setup selectors are reserved. No genericBuild, named phase
selection, fixup pipeline or installation policy is supplied by this runner.
This is not complete legacy removal, a smaller bootstrap closure, an independent
stdenv, or evidence of package equivalence.

Stderr carries one @tvp-step JSON start and one terminal event per selected step.
Each event begins with a newline to frame it after partial child stderr. Child
streams are inherited; the runner does not capture, buffer or tee them. A usable NIX_LOG_FD additionally gets the existing
@nix setPhase protocol. Logging failure never replaces a step status.
Bash supplies numeric wait status only: exit 143 and SIGTERM can both produce
143. No child raw-signal provenance is claimed. Actual external INT/TERM/HUP
is forwarded to the current owned process group, with two bounded one-second
grace periods followed by KILL and leader reaping. Runner cancellation is
re-raised to its caller (Python reports a negative signal number). Ordinary
non-detaching descendants are covered; detached/daemonizing processes are not.
No supervisor or Python is part of runner runtime. Python is the test harness.

Fixtures compile a small C consumer through the selected existing owned wrapper.
They do not reimplement or freshly validate every response-file, hardening,
RPATH or fixup contract, and do not rebuild GCC.

# Installed-command filesystem behavior, gated only by independent libc/kernel
# capability. A fixture failure after preflight is never reclassified as a skip.
{ package, operation }:
let
  deps = package.tvp.declaredDependencies;
  acl = deps.acl;
in
{
  installed-acl = (import ./recorded.nix) {
    inherit package;
    name = "installed-acl";
    tools = package.specification.environment.tools ++ [
      package.tvp.cc
      deps.binutils
      acl
    ];
    libraries = [ acl ];
    script = ''
      mkdir "$out"
      "$CC" ${./filesystem-capabilities.c} -o preflight
      "$CC" ${../../pkgs/build-tools/gnutar/tests/features.c} -lacl -o fixture
      rc=0
      ./preflight acls > "$out/preflight.log" 2>&1 || rc=$?
      case "$rc" in
        0) ;;
        77) echo 'SKIP independent kernel ACL preflight unavailable' > "$out/status"; exit 0 ;;
        *) cat "$out/preflight.log" >&2; exit "$rc" ;;
      esac
      printf 'old\n' > sample
      ./fixture set acl sample
      ${operation}
      ./fixture get acl sample
      echo PASS > "$out/status"
    '';
  };
}

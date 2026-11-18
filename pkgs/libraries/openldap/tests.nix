{ package, context, ... }:
context.mkSuite {
  inherit package;
  tests.version = {
    script = ''
      ${package}/bin/ldapsearch -VV 2>version
      case "$(<version)" in
        *"OpenLDAP: ldapsearch ${package.version} ("*"(LDAP library: OpenLDAP "*) printf '%s' openldap-ready ;;
        *) cat version >&2; exit 1 ;;
      esac
    '';
    expected = "openldap-ready";
  };
}

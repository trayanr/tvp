{ tvp }:
{
  package,
  lib,
  context,
}:
let
  runtime = import ../../with-extensions.nix {
    inherit lib tvp;
    php = package.php;
    extensions = [ package ];
  };
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = ''${runtime}/bin/php -r 'echo phpversion("ldap");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        LDAPNOINIT=1 ${runtime}/bin/php -r '
          // Creating a handle and reading its options require no server connection.
          $ldap = ldap_connect("ldap://localhost");
          if (!$ldap instanceof LDAP\Connection ||
              !ldap_set_option($ldap, LDAP_OPT_PROTOCOL_VERSION, 3) ||
              !ldap_get_option($ldap, LDAP_OPT_PROTOCOL_VERSION, $protocol) ||
              $protocol !== 3 ||
              !ldap_unbind($ldap)) {
            throw new RuntimeException("OpenLDAP connection option roundtrip failed");
          }
          echo ldap_escape("uid=(*)", "", LDAP_ESCAPE_FILTER);
        '
      '';
      expected = "uid=\\28\\2a\\29";
    };
  };
}

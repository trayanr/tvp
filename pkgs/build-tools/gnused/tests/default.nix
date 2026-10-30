{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    acl = {
      script = ''
        LD_DEBUG=libs ${package}/bin/sed --version >/dev/null 2> loader
        grep -F 'calling init: ${pkgs.lib.getLib package.tvp.deps.acl}/lib/libacl.so.1' loader >/dev/null

        printf 'old\n' > sample
        chmod 640 sample
        ${package.tvp.deps.acl}/bin/getfacl -cn sample > before
        grep -Fx 'group::r--' before >/dev/null
        grep -Fx 'other::---' before >/dev/null
        ${package}/bin/sed -i 's/old/new/' sample
        ${package.tvp.deps.acl}/bin/getfacl -cn sample > after
        cmp before after
        test "$(cat sample)" = new
        echo 'ACL linked and permissions preserved'
      '';
      expected = "ACL linked and permissions preserved";
    };
    version = {
      script = ''
        ${package}/bin/sed --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sed -n '1p'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf 'old old\n' > sample
        ${package}/bin/sed -i 's/old/new/g' sample
        cat sample
      '';
      expected = "new new";
    };
  };
}

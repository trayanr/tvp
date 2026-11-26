{ lib, ... }:
let
  check = import ../test.nix { inherit lib; };
in
{
  inputs.postgresql = args: args.tvp.packages.postgresql_16;
  configure = final: {
    libraries = [ final.postgresql ];
    tools = [ final.postgresql ];
    buildFlags = [ "--with-pg-config=${final.postgresql}/bin/pg_config" ];
    # rb_rescue supplies both the callback argument and exception. Newer C
    # compilers reject the historical one-argument callback declaration.
    patches = lib.optionals (final.version == "0.21.0" && lib.versionAtLeast final.ruby.version "2.7") [
      ./ruby-rescue-callback.patch
    ];
  };
  mkTests = package: {
    load = check package {
      name = "client-library";
      script = ''
        ${package.ruby}/bin/ruby -rpg -e 'abort "libpq did not load" unless PG.library_version > 0; print "pg-loaded"'
      '';
      expected = "pg-loaded";
    };
  };
}

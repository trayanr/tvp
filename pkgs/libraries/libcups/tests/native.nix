{ package }:
let
  p = package;
  d = p.specification;
in
p.testContext.mkSuite {
  inherit package;
  tools = [
    d.pkg-config
    d.binutils
    d.grep
  ];
  libraries = [ p ];
  tests = {
    client-profile = {
      script = "cc ${./fixtures/client-profile.c} -lcups -o client-profile; ./client-profile";
      expected = "uri-options-raster";
    };
    consumer = {
      script = ''
        cc $(${p}/bin/cups-config --cflags) ${./fixtures/consumer.c} $(${p}/bin/cups-config --ldflags --libs) -o consumer
        ./consumer
      '';
      expected = p.version;
    };
    discovery-profile = {
      script = ''
        test "$(pkg-config --modversion cups)" = ${p.version}
        cc $(pkg-config --cflags cups) ${./fixtures/consumer.c} $(pkg-config --libs cups) -o consumer
        ./consumer
        readelf -d ${p}/lib/libcups.so.2 > dynamic
        for dependency in libssl.so libcrypto.so libz.so libdns_sd.so; do
          grep -F "$dependency" dynamic >/dev/null
        done
        test ! -e ${p}/sbin/cupsd
        test ! -e ${p}/lib/libcups.a
      '';
      expected = p.version;
    };
    helper-path = {
      script = ''
        export PATH=${d.coreutils}/bin
        test "$(${p}/bin/cups-config --version)" = ${p.version}
        ${p}/bin/cups-config --cflags --ldflags --libs >/dev/null
        test "$(${p}/bin/cups-config --datadir)" = ${p}/share/cups
        test "$(${p}/bin/cups-config --serverroot)" = ${p}/etc/cups
        printf '%s\n' helper-bounded-path
      '';
      # Use the installed absolute path after removing the package from PATH.
      expected = "helper-bounded-path";
    };
  };
}

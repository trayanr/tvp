{
  package,
  lib,
  context,
}:
let
  tools = (package.specification.base.tools or { }) // {
    binutils = package.specification.base.compiler.bintools;
  };
  p = package;
  d = p.specification;
in
context.mkSuite {
  inherit package;
  tools = [
    tools.binutils
    tools.grep
  ];
  libraries = [ p ];
  tests = {
    txt-record = {
      script = "cc ${./fixtures/txt-record.c} -ldns_sd -o txt-record; ./txt-record";
      expected = "txt-record-roundtrip";
    };
    consumer = {
      script = "cc ${./fixtures/consumer.c} -ldns_sd -o consumer; ./consumer";
      expected = "TVP\\032Printer._ipp._tcp.local.";
    };
    client-profile = {
      script = ''
        test -s ${p}/include/dns_sd.h
        test -s ${p}/share/licenses/libdns_sd/dnssd_clientlib.c
        test ! -e ${p}/bin/mdnsd
        test ! -e ${p}/sbin/mdnsd
        nm -D ${p}/lib/libdns_sd.so > symbols
        for symbol in DNSServiceBrowse DNSServiceResolve DNSServiceRegister DNSServiceQueryRecord DNSServiceRefDeallocate; do
          grep -w "$symbol" symbols >/dev/null
        done
        printf '%s\n' client-api-no-daemon
      '';
      expected = "client-api-no-daemon";
    };
  };
}

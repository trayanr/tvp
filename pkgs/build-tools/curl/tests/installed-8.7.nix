{
  package,
  lib,
  tools,
}:
let
  inherit (package.specification.installedInterface) libraryFile soname;
  inherit (package.tvp) deps;
  caBundle = "${deps.ca-certificates}/etc/ssl/certs/ca-bundle.crt";
  providerLibraries = {
    openssl = [
      "libssl.so.3"
      "libcrypto.so.3"
    ];
    zlib = [ "libz.so.1" ];
    zstd = [ "libzstd.so.1" ];
    brotli = [ "libbrotlidec.so.1" ];
    nghttp2 = [ "libnghttp2.so.14" ];
    openldap = [
      "libldap.so.2"
      "liblber.so.2"
    ];
    krb5 = [ "libgssapi_krb5.so.2" ];
  };
in
{
  script = ''
    test "$(pkg-config --modversion libcurl)" = ${package.version}
    test "$(curl-config --version)" = 'libcurl ${package.version}'
    test "$(curl-config --prefix)" = ${package}
    test "$(curl-config --ca)" = ${caBundle}
    test "$(head -n1 ${package}/bin/curl-config)" = '#!${package.specification.bash}/bin/bash'
    test -s ${package}/share/man/man1/curl.1
    test -s ${package}/share/man/man1/curl-config.1
    test -s ${package}/share/man/man3/curl_easy_init.3
    curl --manual > manual
    grep -F -- '--compressed' manual >&2
    test ! -e ${package}/lib/libcurl.a
    test "$(readlink ${package}/lib/libcurl.so)" = ${libraryFile}
    test "$(readlink ${package}/lib/${soname})" = ${libraryFile}
    grep -Fx ${lib.escapeShellArg "dependency_libs='' #pruned"} ${package}/lib/libcurl.la >&2
    grep '^Libs\.private: ' ${package}/lib/pkgconfig/libcurl.pc | grep -F -- '-lgssapi_krb5' >&2

    cc -Wall -Wextra -Werror ${./fixtures/consumer.c} $(pkg-config --cflags --libs libcurl) -o consumer
    test "$(env -i ./consumer)" = ${package.version}
    cc -Wall -Wextra -Werror ${./fixtures/trust.c} $(curl-config --cflags --libs) -o trust
    test "$(env -i ./trust)" = ${caBundle}
    env -i LD_DEBUG=libs ${package}/bin/curl --version > version 2> loader
    grep -E '^curl ${lib.escapeRegex package.version} .*libcurl/${lib.escapeRegex package.version}( |$)' version >&2
    grep -F 'calling init: ${package}/lib/${soname}' loader >&2
    readelf -d ${package}/lib/${libraryFile} > dynamic
    grep -F '(SONAME)' dynamic | grep -F '[${soname}]' >&2
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        provider: sonames:
        lib.concatMapStringsSep "\n" (name: ''
          grep -F '(NEEDED)' dynamic | grep -F '[${name}]' >&2
          grep -F 'calling init: ${deps.${provider}}/lib/${name}' loader >&2
        '') sonames
      ) providerLibraries
    )}
    curl-config --features > features
    for feature in SSL HTTP2 libz zstd brotli GSS-API SPNEGO AsynchDNS; do
      grep -Fx "$feature" features >&2
    done
    curl-config --protocols > protocols
    for protocol in HTTP HTTPS LDAP LDAPS FILE; do
      grep -Fx "$protocol" protocols >&2
    done
    printf installed-provider-ok
  '';
  expected = "installed-provider-ok";
  tools = [
    package.tvp.cc
    deps.pkg-config
    deps.binutils
  ]
  ++ tools;
}

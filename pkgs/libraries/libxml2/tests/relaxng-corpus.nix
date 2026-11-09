{ pkgs, libxml2 }:
let
  script = ''
    cp ${./fixtures/relaxng-corpus.c} relaxng-corpus.c
    cp ${./fixtures/relaxng-corpus-cases.h} relaxng-corpus-cases.h
    # PIC makes dladdr see the DSO implementation instead of an executable PLT.
    cc -fPIC -std=c99 -Wall -Wextra -Werror relaxng-corpus.c $(${libxml2}/bin/xml2-config --cflags --libs) -ldl -o relaxng-corpus
    ./relaxng-corpus ${libxml2}/lib/libxml2.so ${libxml2.version} results.json >&2
    cat results.json >&2
    printf corpus-compatible
  '';
in
if libxml2 ? testContext then
  libxml2.testContext.mkTest {
    package = libxml2;
    name = "relaxng-corpus";
    inherit script;
    expected = "corpus-compatible";
    tools = [ libxml2.tvp.cc ];
    libraries = [ libxml2 ];
  }
else
  pkgs.runCommandWith
    {
      name = "libxml2-${libxml2.version}-relaxng-corpus";
      stdenv = libxml2.stdenv;
      derivationArgs = {
        nativeBuildInputs = [ libxml2.stdenv.cc ];
        buildInputs = [ libxml2 ] ++ pkgs.lib.attrValues libxml2.tvp.deps;
        passthru = {
          package = libxml2;
          testName = "relaxng-corpus";
        };
      };
    }
    ''
      set -euo pipefail
      mkdir -p "$out"
      {
        cp ${./fixtures/relaxng-corpus.c} relaxng-corpus.c
        cp ${./fixtures/relaxng-corpus-cases.h} relaxng-corpus-cases.h
        cc -std=c99 -Wall -Wextra -Werror \
          relaxng-corpus.c \
          $(${libxml2}/bin/xml2-config --cflags --libs) \
          ${pkgs.lib.optionalString libxml2.stdenv.hostPlatform.isLinux "-ldl"} \
          -o relaxng-corpus
        ./relaxng-corpus ${libxml2}/lib/libxml2.so ${libxml2.version} "$out/results.json"
      } 2>&1 | tee "$out/results.log"
    ''

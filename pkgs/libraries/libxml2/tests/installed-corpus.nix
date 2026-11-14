{
  package,
  lib,
  context,
}:
let
  script = ''
    cp ${./fixtures/relaxng-corpus.c} relaxng-corpus.c
    cp ${./fixtures/relaxng-corpus-cases.h} relaxng-corpus-cases.h
    # PIC makes dladdr see the DSO implementation instead of an executable PLT.
    cc -fPIC -std=c99 -Wall -Wextra -Werror relaxng-corpus.c $(${package}/bin/xml2-config --cflags --libs) -ldl -o relaxng-corpus
    ./relaxng-corpus ${package}/lib/libxml2.so ${package.version} results.json >&2
    cat results.json >&2
    printf corpus-compatible
  '';
in
context.mkTest {
  inherit package script;
  name = "relaxng-corpus";
  expected = "corpus-compatible";
  tools = [ package.tvp.cc ];
  libraries = [ package ];
}

{
  package,
  lib,
  context,
}:

let
  u = import ../upstream.nix;
  filenames = [
    "gawk-1.01.tar.gz"
    "gawk-5.3.0.tar.xz"
    "gawk-5.3.0.tar.bz2"
    "gawk-5.3.0.tar.lz"
    "gawk-doc-5.3.0.tar.xz"
    "gawk-5.3.0-doc.tar.xz"
    "gawk-5.3.0-ps.tar.gz"
    "gawk-5.3.0.tar.xz.sig"
    "gawk-5.3.0.tar.xz.junk"
    "prefix-gawk-5.3.0.tar.xz"
    "gawk-5.3.0-rc1.tar.xz"
    "gawk-5.3.0a.tar.xz"
    "gawk-5.3.0.tar.zst"
    "gawk-5.3.0.diff.gz"
    "README-gawk-5.3.0.tar.xz"
    "gawk-.5.3.0.tar.xz"
    "gawk-5..3.tar.xz"
    "gawk-5.3.0.tar.xz/"
    "subdir/gawk-5.3.0.tar.xz"
    "README"
  ];
  raw = map (f: ''href="${f}"'') filenames;
  normalized = map u.normalise raw;
  valid = builtins.filter (v: v != null) normalized;
  html = lib.concatMapStringsSep "\n" (f: ''<a href="${f}">${f}</a>'') filenames;
in
assert
  normalized == [
    "1.01"
    "5.3.0"
    "5.3.0"
    "5.3.0"
  ]
  ++ builtins.genList (_: null) 16;
assert
  lib.unique valid == [
    "1.01"
    "5.3.0"
  ];
context.mkSuite {
  inherit package;
  tools = package.specification.environment.tools;
  tests.upstream-fixtures = {
    script = ''
      printf '%s\n' ${lib.escapeShellArg html} | grep -oE ${lib.escapeShellArg u.pattern}
    '';
    expected = builtins.concatStringsSep "\n" raw;
  };
}

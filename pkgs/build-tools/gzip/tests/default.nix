{
  pkgs,
  tvpLib,
  package,
  coreutils,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    helpers = {
      script = ''
        for helper in ${package}/bin/*; do
          test -x "$helper"
          basename "$helper"
        done | LC_ALL=C sort
      '';
      expected = "gunzip\ngzexe\ngzip\nuncompress\nzcat\nzcmp\nzdiff\nzegrep\nzfgrep\nzforce\nzgrep\nzmore\nznew";
    };
    zmore = {
      # PAGER remains a runtime choice; cat is a real, noninteractive choice.
      script = ''
        printf 'preserved\n' > plain
        ${package}/bin/gzip -nc plain > plain.gz
        PAGER=${coreutils}/bin/cat ${package}/bin/zmore plain.gz
        PAGER=${coreutils}/bin/cat ${package}/bin/zmore plain
        PAGER='${coreutils}/bin/cat -n' ${package}/bin/zmore < plain.gz
      '';
      expected = "preserved\npreserved\n     1\tpreserved";
    };
    zgrep-pin = {
      script = ''
        grep -Fq '${package.tvp.deps.gnugrep}/bin/grep' ${package}/bin/zgrep
        printf pinned
      '';
      expected = "pinned";
    };
    version = {
      script = ''
        ${package}/bin/gzip --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf preserved | ${package}/bin/gzip -n > sample.gz
        ${package}/bin/gzip -t sample.gz
        ${package}/bin/gzip -dc sample.gz
      '';
      expected = "preserved";
    };
    zgrep = {
      script = ''
        printf 'before\npreserved\nafter\n' | ${package}/bin/gzip -n > lines.gz
        ${package}/bin/zgrep '^preserved$' lines.gz
      '';
      expected = "preserved";
    };
  };
}

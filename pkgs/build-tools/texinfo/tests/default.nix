{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''makeinfo --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' '';
      expected = package.version;
    };
    formats = {
      script = ''
        makeinfo ${./fixtures/manual.texi} -o manual.info
        makeinfo --html --no-split ${./fixtures/manual.texi} -o manual.html
        makeinfo --plaintext ${./fixtures/manual.texi} -o manual.txt
        grep -q 'TVP preserves build tools' manual.html
        grep -q 'TVP preserves build tools' manual.txt
        # Also exercises the Info reader and its declared curses linkage.
        info --file=./manual.info --output=read.txt
        grep -q 'TVP preserves build tools' read.txt
        echo ok
      '';
      expected = "ok";
    };
    perl-xs = {
      script = ''
        TEXINFO_XS=required makeinfo --plaintext ${./fixtures/manual.texi} -o manual.txt
        grep -q 'TVP preserves build tools' manual.txt
        echo ok
      '';
      expected = "ok";
    };
    tex-support = {
      script = ''
        test -s ${package}/texmf-dist/tex/texinfo/texinfo.tex
        echo ok
      '';
      expected = "ok";
    };
  };
}

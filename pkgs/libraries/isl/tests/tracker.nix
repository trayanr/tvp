{ pkgs, isl }:
let
  normalise = isl.tvp.upstream.normalise;
  accepted = [
    {
      href = ''href="isl-0.07.tar.bz2"'';
      version = "0.07";
    }
    {
      href = ''href="isl-0.28.tar.gz"'';
      version = "0.28";
    }
    {
      href = ''href="isl-0.28.tar.bz2"'';
      version = "0.28";
    }
    {
      href = ''href="isl-0.28.tar.xz"'';
      version = "0.28";
    }
    {
      href = ''href="isl-10.02.003.tar.xz"'';
      version = "10.02.003";
    }
    {
      href = ''href="https://libisl.sourceforge.io/isl-0.28.tar.xz"'';
      version = "0.28";
    }
    {
      href = ''href="/releases/isl-0.07.tar.bz2"'';
      version = "0.07";
    }
  ];
  rejected = [
    ''href="isl-0.28.tar.xz/"''
    ''href="isl-0.28.tar.xz//"''

    ''href="README"''
    ''href="isl-0.28.tar.xz.sig"''
    ''href="isl-0.28.tar.xz.asc"''
    ''href="isl-0.28.tar.xz.junk"''
    ''href="not-isl-0.28.tar.xz"''
    ''href="isl-0.28rc1.tar.xz"''
    ''href="isl-0.28-rc1.tar.xz"''
    ''href="isl-.28.tar.xz"''
    ''href="isl-0.28..tar.xz"''
    ''href="isl-0.28.tar.zip"''
    ''href="isl-0.28.tar.xz?download=1"''
    ''junkhref="isl-0.28.tar.xz"''
    ''href="isl-0.28.tar.xz"junk''
  ];
  versions = pkgs.lib.unique (map (row: normalise row.href) accepted);
in
assert builtins.all (row: normalise row.href == row.version) accepted;
assert builtins.all (href: normalise href == null) rejected;
assert builtins.length versions == 3;
assert builtins.elem "0.07" versions;
pkgs.runCommand "isl-${isl.version}-tracker"
  {
    passthru = {
      package = isl;
      testName = "tracker";
    };
  }
  ''
    echo 'PASS strict complete archive hrefs, exact version spelling, compression deduplication and rejected junk' | tee "$out"
  ''

{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''
        ${package}/bin/file --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf '#!/bin/sh\necho preserved\n' > sample.sh
        ${package}/bin/file --mime-type -b sample.sh
      '';
      expected = "text/x-shellscript";
    };
  };
}
// tvpLib.tests.mkSuite {
  inherit package;
  # New compiled/runtime checks follow each canonical or bootstrap package's base.
  # Keep the original version/operation leaves above unchanged.
  pkgs = tvpLib.tests.withBase {
    inherit pkgs;
    base.stdenv = package.stdenv;
  };
  tests = {
    stdin = {
      script = ''
        printf '#!/bin/sh\necho preserved\n' > sample.sh
        test "$(${package}/bin/file --mime-type -b - < sample.sh)" = text/x-shellscript
        test "$(cat sample.sh | ${package}/bin/file --mime-type -b -)" = text/x-shellscript
        echo stdin-ok
      '';
      expected = "stdin-ok";
    };
    libmagic-compression = {
      extraInputs = [ package.tvp.cc ] ++ builtins.attrValues package.tvp.deps;
      script = ''
        printf '#!/bin/sh\necho preserved\n' > sample.sh
        cc -Wall -Wextra -Werror ${./libmagic.c} -lmagic -lz -o consumer
        ${package.tvp.deps.bzip2}/bin/bzip2 -c sample.sh > sample.bz2
        ${package.tvp.deps.xz}/bin/xz -c sample.sh > sample.xz
        ${package.tvp.deps.zstd}/bin/zstd -q -c sample.sh > sample.zst
        ./consumer sample.sh sample.gz sample.bz2 sample.xz sample.zst
        readelf -d ./consumer | grep -Fq '[libmagic.so.1]'
        readelf -d ./consumer | grep -Fq '${package}/lib'
        readelf -d ${package}/lib/libmagic.so > linkage
        grep -Fq '[libz.so.1]' linkage
        grep -Fq '[libbz2.so.1.0]' linkage
        grep -Fq '[liblzma.so.5]' linkage
        grep -Fq '[libzstd.so.1]' linkage
        ${pkgs.lib.concatMapStringsSep "\n" (dep: "grep -Fq '${dep}/lib' linkage") (
          builtins.attrValues package.tvp.deps
        )}
        for input in sample.gz sample.bz2 sample.xz sample.zst; do
          test "$(${package}/bin/file -Zb --mime-type "$input")" = text/x-shellscript
          test "$(${package}/bin/file -Zb --mime-type - < "$input")" = text/x-shellscript
          test "$(cat "$input" | ${package}/bin/file -Zb --mime-type -)" = text/x-shellscript
        done
        echo libmagic-compression-ok
      '';
      expected = "libmagic-compression-ok";
    };
  };
}

{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  p = package;
  d = p.tvp.deps;
  c = p.testContext;
  upstream = p.editSteps (
    tvp.builder.steps.insertAfter "file.build" [
      (
        (p.specification.base.environment p.specification.environment)
        // {
          name = "file.upstream";
          cwd = "source";
          run = ''${d.gnumake}/bin/make -j"$NIX_BUILD_CORES" check >&2; mkdir -p "$out/nix-support"; printf passed > "$out/nix-support/upstream"'';
        }
      )
    ]
  );
  rebound = p.override { zlib = p.tvp.declaredTestDependencies.alternateZlib; };
  changed = p.editRuntime (r: r // { dlopenDirectories = [ "${d.zlib}/lib" ]; });
  sourceProbe =
    (p.override { src = "${p.tvp.declaredTestDependencies.alternateSource}/source.tar.gz"; }).edit
      (
        s:
        let
          base = s.base.override { compiler = p.tvp.declaredTestDependencies.sentinel; };
        in
        s
        // {
          inherit base;
          plan = [
            (builtins.head s.plan)
            (
              (base.environment s.environment)
              // {
                name = "file.source-base";
                run = ''
                  test "$(cat source/marker)" = 'alternate source'
                  printf 'int main(void) { return 0; }\n' > probe.c
                  "$CC" probe.c -o probe
                  env -i ./probe
                  test "$(cat selected-compiler)" = selected
                  mkdir "$out"; cp source/marker "$out/marker"
                '';
              }
            )
          ];
        }
      );
  compress = ''
    printf '#!/bin/sh\necho preserved\n' > sample.sh
    ${d.bzip2}/bin/bzip2 -c sample.sh > sample.bz2
    ${d.xz}/bin/xz -c sample.sh > sample.xz
    ${d.zstd}/bin/zstd -q -c sample.sh > sample.zst
  '';
in
c.mkSuite {
  inherit package;
  tools = [
    d.grep
    d.sed
    d.gawk
  ];
  tests = {
    version = {
      script = ''file --version | head -1 | sed 's/^file-//' '';
      expected = p.version;
    };
    operation = {
      script = ''printf '#!/bin/sh\necho preserved\n' > sample.sh; file --mime-type -b sample.sh'';
      expected = "text/x-shellscript";
    };
    libmagic-compression = {
      libraries = [
        p
        d.zlib
      ];
      script = ''
        ${compress}
        "$CC" -Wall -Wextra -Werror ${./libmagic.c} -lmagic -lz -o consumer
        env -i ./consumer sample.sh sample.gz sample.bz2 sample.xz sample.zst
        readelf -d ./consumer > consumer.elf
        grep -Fq '[libmagic.so.1]' consumer.elf
        grep -Fq '${p}/lib' consumer.elf
        readelf -d ${p}/lib/libmagic.so > linkage
        ${pkgs.lib.concatMapStringsSep "\n" (dep: "grep -Fq '${dep}/lib' linkage") [
          d.zlib
          d.xz
          d.bzip2
          d.zstd
        ]}
        for lib in libz.so.1 libbz2.so.1.0 liblzma.so.5 libzstd.so.1; do grep -Fq "[$lib]" linkage; done
        for input in sample.gz sample.bz2 sample.xz sample.zst; do
          test "$(file -Zb --mime-type "$input")" = text/x-shellscript
          test "$(file -Zb --mime-type - < "$input")" = text/x-shellscript
          test "$(cat "$input" | file -Zb --mime-type -)" = text/x-shellscript
        done
        printf compression
      '';
      expected = "compression";
    };
    development = {
      tools = [
        d.sed
        d.grep
        p.tvp.declaredTestDependencies.pkgconfig
      ];
      libraries = [
        p
        d.zlib
        d.xz
        d.bzip2
        d.zstd
      ];
      script = ''
        test -f ${p}/lib/libmagic.a
        test -f ${p}/lib/libmagic.la
        pkg-config --exists libmagic
        printf '#!/bin/sh\necho preserved\n' > sample.sh
        "$CC" ${./libmagic.c} $(pkg-config --cflags libmagic) ${p}/lib/libmagic.a $(pkg-config --libs --static libmagic | sed 's/-lmagic//g') -o static-consumer
        env -i ./static-consumer sample.sh
        if readelf -d static-consumer | grep -q libmagic.so; then exit 1; fi
        printf development
      '';
      expected = "development";
    };
    magic-override = {
      script = ''
        printf '0 string TVP! tvp-custom-magic\n' > custom
        file -C -m custom
        printf 'TVP!data' > data
        test "$(MAGIC="$PWD/custom.mgc" file -b data)" = tvp-custom-magic
        printf '#!/bin/sh\necho preserved\n' | file -b --mime-type - | grep -qx text/x-shellscript
        test -s ${p}/share/misc/magic.mgc
        printf magic
      '';
      expected = "magic";
    };
    constructor = {
      expected =
        assert (p.override { }).drvPath == p.drvPath;
        assert (p.edit (s: s)).drvPath == p.drvPath;
        assert rebound.tests.version.package.outPath == rebound.outPath;
        assert !(p ? stdenv) && !(p ? overrideAttrs);
        "qualified";
      libraries = [
        rebound
        d.zlib
      ];
      script = ''
        test -s ${sourceProbe}/marker
        printf '#!/bin/sh\necho preserved\n' > sample.sh
        "$CC" ${./libmagic.c} -lmagic -lz -o consumer
        env -i ./consumer sample.sh
        readelf -d ${rebound}/lib/libmagic.so | grep -Fq '${p.tvp.declaredTestDependencies.alternateZlib}/lib'
        ${changed}/bin/file -b --mime-type sample.sh | grep -qx text/x-shellscript
        printf qualified
      '';
    };
    upstream = {
      script = ''test -s ${upstream}/nix-support/upstream; printf upstream'';
      expected = "upstream";
    };
  };
}

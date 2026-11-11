# Extend the common ordinary suite without changing already-owned producers/tests.
{
  pkgs,
  tvpLib,
  xz,
  pkg-config,
  referenceOlder,
  referenceNewer,
}:
(import ./ordinary-default.nix {
  inherit
    pkgs
    tvpLib
    xz
    pkg-config
    referenceOlder
    referenceNewer
    ;
})
// xz.testContext.mkSuite {
  package = xz;
  tools = with xz.tvp.declaredDependencies; [
    binutils
    grep
    diffutils
  ];
  libraries = [ xz ];
  tests = {
    guards = {
      tools = [ xz.tvp.deps.python ];
      script = ''
        ${xz.tvp.deps.python}/bin/python3 -B ${./older-guards.py} ${../ordinary/validate.py}
      '';
      expected = "guards 10";
    };
    pager = {
      script = ''
        mkdir empty
        printf 'pager roundtrip\n' > plain
        ${xz}/bin/xz -c plain > plain.xz
        env -i PATH="$PWD/empty" ${xz}/bin/xzless --show-preproc-error plain.xz > paged
        cmp plain paged
        printf pager
      '';
      expected = "pager";
    };
    abi-pkgconfig = {
      tools = [
        pkg-config
        xz.tvp.cc
        xz.tvp.deps.binutils
        xz.tvp.deps.grep
      ];
      script = ''
        unset NIX_CFLAGS_COMPILE NIX_CFLAGS_LINK NIX_LDFLAGS
        export PKG_CONFIG_LIBDIR=${xz}/lib/pkgconfig
        "$CC" ${./fixtures/version.c} $(pkg-config --cflags --libs liblzma) -Wl,-rpath,${xz}/lib -o shared
        ./shared
        "$CC" ${./fixtures/version.c} $(pkg-config --cflags liblzma) -Wl,-Bstatic $(pkg-config --static --libs liblzma) -Wl,-Bdynamic -o static
        ./static
        readelf -d ${xz}/lib/liblzma.so.5 | grep -F 'Library soname: [liblzma.so.5]' >/dev/null
        nm -D --defined-only ${xz}/lib/liblzma.so.5 | grep -w lzma_code >/dev/null
      '';
      expected = "${xz.version}\n${xz.version}";
    };
    formats-errors = {
      script = ''
        printf 'formats and integrity\n' > plain
        for format in xz lzma raw; do
          options=()
          if test "$format" = raw; then options=(--lzma2); fi
          ${xz}/bin/xz --format="$format" "''${options[@]}" -c plain > data
          ${xz}/bin/xz --format="$format" "''${options[@]}" -dc data > decoded
          cmp plain decoded
        done
        ${xz}/bin/xz -c plain > data.xz
        ${xz}/bin/xz -t data.xz
        head -c 10 data.xz > broken
        if ${xz}/bin/xz -t broken >/dev/null 2>&1; then exit 1; fi
        if ${xz}/bin/xz --definitely-invalid >/dev/null 2>&1; then exit 1; fi
        printf formats
      '';
      expected = "formats";
    };
  };
}

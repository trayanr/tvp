{
  pkgs,
  tvpLib,
  zstd,
  gzip,
}:
let
  cc = [ zstd.tvp.cc ];
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = zstd;
  tests = {
    version = {
      script = ''
        cc ${./fixtures/version.c} -lzstd -o version
        ./version
      '';
      expected = zstd.version;
      extraInputs = cc;
    };
    compress = {
      script = ''
        cc ${./fixtures/roundtrip.c} -lzstd -o roundtrip
        ./roundtrip
      '';
      expected = "tvp preserved";
      extraInputs = cc;
    };
    static = {
      script = ''
        cc ${./fixtures/roundtrip.c} ${zstd}/lib/libzstd.a -pthread -o roundtrip
        ./roundtrip
      '';
      expected = "tvp preserved";
      extraInputs = cc;
    };
    cli = {
      script = ''printf 'tvp' | zstd -q -c | zstd -q -d -c'';
      expected = "tvp";
    };
    gzip = {
      script = ''printf 'tvp' | zstd --format=gzip -q -c | ${gzip}/bin/gzip -dc'';
      expected = "tvp";
    };
    xz = {
      script = ''printf 'tvp' | zstd --format=xz -q -c | ${zstd.tvp.deps.xz}/bin/xz -dc'';
      expected = "tvp";
    };
  };
}

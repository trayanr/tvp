{
  pkgs,
  tvpLib,
  headers,
}:
let
  parts = pkgs.lib.splitString "." headers.version;
  patch = if builtins.length parts > 2 then pkgs.lib.toInt (builtins.elemAt parts 2) else 0;
  versionCode = toString (
    (pkgs.lib.toInt (builtins.elemAt parts 0)) * 65536
    + (pkgs.lib.toInt (builtins.elemAt parts 1)) * 256
    + pkgs.lib.min patch 255
  );
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = headers;
  tests = {
    version = {
      script = ''
        test "$(awk '/^#define LINUX_VERSION_CODE / { print $3 }' ${headers}/include/linux/version.h)" = "${versionCode}"
        echo ${headers.version}
      '';
      expected = headers.version;
    };
    compile = {
      script = ''
        cc -I${headers}/include -DTVP_EXPECTED_VERSION_CODE=${versionCode} ${./fixtures/api.c} -o api
        ./api
      '';
      expected = "ok";
      extraInputs = [ headers.tvp.cc ];
    };
  };
}

{
  pkgs,
  tvpLib,
  package,
  ninja,
}:
let
  consumer =
    useNinja:
    pkgs.stdenv.mkDerivation {
      name = "cmake-consumer-${if useNinja then "ninja" else "make"}";
      src = ./fixtures;
      nativeBuildInputs = [ package ] ++ pkgs.lib.optional useNinja ninja;
      buildInputs = [ package.tvp.deps.zlib ];
      doCheck = true;
      postInstall = ''"$out/bin/answer" > "$out/result"'';
    };
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''cmake --version | head -1 | awk '{print $3}' '';
      expected = package.version;
    };
    make = {
      script = ''cat ${consumer false}/result'';
      expected = "42";
    };
    ninja = {
      script = ''cat ${consumer true}/result'';
      expected = "42";
    };
    archives = {
      script = ''
        cmake -S ${./fixtures} -B build -DCMAKE_PREFIX_PATH='${package.tvp.cc.libc};${package.tvp.deps.zlib}' >&2
        cmake --build build -j "$NIX_BUILD_CORES" >&2
        ctest --test-dir build --output-on-failure >&2
        cd build
        cpack -G TXZ >&2
        cmake -E tar tf answer-1.0.0-Linux.tar.xz | grep -E '/bin/answer$' >&2
        printf 42
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
  };
}

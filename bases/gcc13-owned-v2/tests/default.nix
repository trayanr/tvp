{
  pkgs,
  tvpLib,
  base,
}:
let
  inherit (base) stdenv;
  plugin = stdenv.mkDerivation {
    name = "tvp-fixup-plugin";
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      mkdir -p "$out/lib"
      cc -shared -fPIC ${./plugin.c} -o "$out/lib/liboptional.so"
    '';
  };
  unused = stdenv.mkDerivation {
    name = "tvp-fixup-unused";
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''mkdir -p "$out/lib"; printf unused > "$out/lib/marker"'';
  };
  consumer = stdenv.mkDerivation {
    name = "tvp-fixup-consumer";
    outputs = [
      "out"
      "lib"
    ];
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    runtimeLibraryPaths = [ "${plugin}/lib" ];
    installPhase = ''
      mkdir -p "$out/bin" "$lib/lib"
      cc ${./consumer.c} -ldl -Wl,-rpath,${unused}/lib:${plugin}/lib -o "$out/bin/consumer"
      cc -static ${../../tests/fixtures/libc.c} -o "$out/bin/static"
      cc -shared -fPIC ${./plugin.c} -Wl,-rpath,${unused}/lib -o "$lib/lib/libanswer.so"
      ln -s consumer "$out/bin/alias"
    '';
  };
  untrimmed = consumer.overrideAttrs {
    name = "tvp-fixup-opt-out";
    dontShrinkRpaths = true;
  };
in
{
  rpath-cleanup = tvpLib.bases.mkBaseTest {
    inherit base;
    name = "rpath-cleanup";
    script = ''
      ${consumer}/bin/consumer | grep -qx 42
      ${consumer}/bin/alias | grep -qx 42
      ${consumer}/bin/static | grep -qx 45
      patchelf --print-rpath ${consumer}/bin/consumer > rpath
      grep -Fq '${plugin}/lib' rpath
      if grep -Fq '${unused}' rpath; then exit 1; fi
      if patchelf --print-rpath ${consumer.lib}/lib/libanswer.so | grep -Fq '${unused}'; then exit 1; fi
      patchelf --print-rpath ${untrimmed}/bin/consumer | grep -Fq '${unused}/lib'
      ${untrimmed}/bin/consumer | grep -qx 42
      echo ok
    '';
    expected = "ok";
  };
}

{
  tvp,
  lib,
  base,
  src,
  version,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  paths = [ "bin" "lib" ];
  precisions = {
    double = [ ];
    single = [ "--enable-single" ];
    long-double = [ "--enable-long-double" ];
    quad = [ "--enable-quad-precision" ];
  };
  buildDirectories = map (precision: "build-${precision}") (builtins.attrNames precisions);
  configure = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      precision: flags:
      let
        simd = lib.optionals (precision == "double" || precision == "single") [
          "--enable-sse2"
          "--enable-avx"
          "--enable-avx2"
          "--enable-avx512"
        ];
      in
      ''
        mkdir build-${precision}
        (
          cd build-${precision}
          "$CONFIG_SHELL" ../configure --prefix="$out" --libdir="$out/lib" \
            --enable-shared --enable-static --enable-threads --enable-openmp \
            ${lib.escapeShellArgs (flags ++ simd)}
        )
      ''
    ) precisions
  );
in
{
  pname = "fftw";
  inherit base src version;
  inherit (tools) bash coreutils;
  environment.tools = [
    tools.gnumake
    tools.gawk
    tools.grep
    tools.sed
    tools.diffutils
    tools.findutils
  ];
  runtime.libraries = [ ];
  plan = [
    (steps.unpack { src = final.src; compression = "gzip"; })
    (steps.prepareAutotools { name = "fftw.prepare"; })
    (command "fftw.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      ${configure}
    '')
    (command "fftw.build" ''
      for build in ${lib.escapeShellArgs buildDirectories}; do
        ${make} -C "$build"
      done
    '')
    (command "fftw.install" ''
      for build in ${lib.escapeShellArgs buildDirectories}; do
        ${make} -C "$build" install
      done
      install -Dm644 COPYING "$out/share/licenses/fftw/COPYING"
      for suffix in "" f l q; do
        test -e "$out/lib/libfftw3$suffix.so"
        test -e "$out/lib/libfftw3''${suffix}_threads.so"
        test -e "$out/lib/libfftw3''${suffix}_omp.so"
        test -f "$out/lib/pkgconfig/fftw3$suffix.pc"
        test -x "$out/bin/fftw$suffix-wisdom"
      done
    '')
    (steps.split "fftw.finalize")
    (outputs.copyArtifacts { })
    (outputs.libtool { paths = [ "lib" ]; })
    (outputs.relocateText { paths = [ "lib/pkgconfig" ]; })
    (outputs.shebangs {
      paths = [ "bin/fftw-wisdom-to-conf" ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (outputs.strip { inherit paths; elfKinds = [ "runtime" ]; })
    (outputs.stripArchives { paths = [ "lib" ]; })
    (outputs.rpaths { inherit paths; libraries = final.runtime.libraries; elfKinds = [ "runtime" ]; })
    (outputs.checkPaths { inherit paths; elfKinds = [ "runtime" ]; })
  ];
  meta = {
    description = "Discrete Fourier transforms in four precisions";
    homepage = "https://fftw.org/";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}

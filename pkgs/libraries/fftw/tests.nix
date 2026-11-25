{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [ tools.pkg-config tools.grep ];
  libraries = [ package ];
  tests = {
    transform = {
      script = ''
        "$CC" $(pkg-config --cflags fftw3) ${./transform.c} $(pkg-config --libs fftw3) -lm -o transform
        ./transform
      '';
      expected = "FFT round trip";
    };
    threads = {
      script = ''
        for implementation in threads omp; do
          "$CC" -DTHREADED $(pkg-config --cflags fftw3) ${./transform.c} \
            -lfftw3_"$implementation" $(pkg-config --libs fftw3) -lm -o transform
          ./transform
        done
      '';
      expected = "FFT round trip\nFFT round trip";
    };
    interfaces = {
      script = ''
        for suffix in "" f l q; do
          test "$(pkg-config --modversion "fftw3$suffix")" = "${package.version}"
          "fftw$suffix-wisdom" --version | grep -Fq "${package.version}"
        done
        test -f "${package}/include/fftw3.h"
        test -f "${package}/include/fftw3.f03"
        printf '%s\n' '${package.version}'
      '';
      expected = package.version;
    };
  };
}

{ pkgs, tvp }:
let
  fixture = import ./build-step-runner {
    inherit pkgs tvp;
    temporaryDirectories = true;
  };
in
(tvp.__legacyBases.gcc_16_2_0.stdenv.mkDerivation {
  name = "tvp-step-temporary-cleanup";
  nativeBuildInputs = [ tvp.packages.python_3 ];
  buildCommand = ''
    python3 ${./temporary-harness.py} ${fixture.passthru.runtime} ${tvp.packages.bash}/bin/bash
    touch "$out"
  '';
})
// {
  passthru.runtime = fixture.passthru.runtime;
}

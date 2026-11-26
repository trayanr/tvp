{ lib, python }:
let
  version = lib.versions.majorMinor python.version;
in
(python.edit (spec: spec // {
  configureFlags = spec.configureFlags ++ [ "--enable-shared" ];
})).editSteps (
  map (
    step:
    if step.name == "python.configure" then
      step // {
        # The installed interpreter must find the copy of libpython in its
        # own output. The Python finalizer relocates this prefix with the ELF.
        run = ''
          export LDFLAGS="$LDFLAGS -Wl,-rpath,$out/lib"
        '' + step.run;
      }
    else if step.name == "python.install" then
      step // {
        run = step.run + ''
          test -f "$out/lib/libpython${version}.so"
        '';
      }
    else
      step
  )
)

{ package, context, ... }:
let
  orcApi = if package.specification.installedInterface.orcV1 then "1" else "2";
in
context.mkSuite {
  inherit package;
  tests.jit = {
    script = ''
      clang $(llvm-config --cflags) -DTVP_ORC_API=${orcApi} \
        ${./fixtures/jit.c} $(llvm-config --link-shared --ldflags --libs orcjit native --system-libs) \
        -Wl,-rpath,"$(llvm-config --libdir)" -o jit
      ./jit
    '';
    expected = "42";
  };
}

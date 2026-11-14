{ pkgs, package }:
let
  p = package;
  coreProvider = "/nix/store/00000000000000000000000000000000-contract-coreutils";
  gzipProvider = "/nix/store/00000000000000000000000000000000-contract-gzip";
  coreEdit = p.edit (s: s // { coreutils = coreProvider; });
  gzipEdit = p.edit (
    s:
    s
    // {
      tools = s.tools // {
        gzip = gzipProvider;
      };
    }
  );
  step = q: name: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  copy = step coreEdit "output.copy-artifacts";
  manuals = step gzipEdit "output.manuals";
in
p.testContext.mkSuite {
  package = p;
  tools = [
    p.specification.tools.python
    p.specification.tools.binutils
    p.specification.tools.patchelf
  ];
  tests = {
    effective-finalization-providers = {
      expected =
        assert map toString copy.tools == [ coreProvider ];
        assert pkgs.lib.hasInfix "${coreProvider}/bin/cp" copy.run;
        assert pkgs.lib.hasInfix "${coreProvider}/bin/chmod" copy.run;
        assert map toString manuals.tools == [ gzipProvider ];
        assert pkgs.lib.hasInfix "${gzipProvider}/bin/gzip" manuals.run;
        "providers";
      script = ''printf providers'';
    };
    output-inspection-fail-closed = {
      script = ''
        printf 'int main(void) { return 0; }\n' > inspection.c
        "$CC" inspection.c -o dynamic
        "$CC" -static -no-pie inspection.c -o static
        "$CC" -c inspection.c -o relocatable.o
        ${p.specification.tools.python}/bin/python3 -B ${../../ordinary-compression-output-tests.py} \
          ${../../ordinary-compression-output.py} ${p.specification.tools.binutils}/bin/readelf \
          ${p.specification.tools.patchelf}/bin/patchelf "$PWD/dynamic" "$PWD/static" "$PWD/relocatable.o"
      '';
      expected = "inspection-contracts";
    };
  };
}

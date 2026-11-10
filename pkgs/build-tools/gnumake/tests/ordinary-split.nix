# These finite controls run against the effective ordinary package.
{ package }:
let
  p = package;
  runtime = p.editRuntime (r: r // { dlopenDirectories = [ "${p.specification.python}/lib" ]; });
  suffix = p.editSteps (
    plan:
    plan
    ++ [
      {
        name = "ordinary.final-control";
        run = ''mkdir -p "$out/nix-support"; printf selected > "$out/nix-support/final-control"'';
      }
    ]
  );
  source = p.edit (s: s // { src = p.tvp.declaredTestDependencies.alternateSource; });
  build = p.edit (
    s:
    s
    // {
      environment = s.environment // {
        overrides.values.ORDINARY_BUILD_INPUT = "changed";
      };
    }
  );
  candidate = import ../../../../bases/source-gnu { };
  alternate = (import ../../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
  sentinel = (import ../../../../bases/source-gnu/tests/probes.nix { }).sentinel;
  sourceProbe = (p.override { src = "${alternate}/source.tar.gz"; }).edit (
    s:
    let
      base = s.base.override { compiler = sentinel; };
    in
    s
    // {
      inherit base;
      plan = [
        (
          base.environment s.environment
          // {
            name = "ordinary.source-compiler";
            run = ''
              mkdir source
              ${s.gnutar}/bin/tar --use-compress-program=${candidate.tools.gzip}/bin/gzip -xf ${s.src} -C source --strip-components=1
              test "$(cat source/marker)" = 'alternate source'
              printf 'int main(void) { return 0; }\n' > probe.c
              "$CC" probe.c -o probe; "$CXX" -x c++ probe.c -o probe-cxx
              env -i ./probe; env -i ./probe-cxx
              test "$(cat selected-compiler)" = $'selected\nselected'
              mkdir "$out"; cp source/marker "$out/source-marker"
            '';
          }
        )
      ];
    }
  );
  unchanged = (p.override { }).drvPath == p.drvPath && (p.edit ((s: s))).drvPath == p.drvPath;
in
assert unchanged;
assert ((p.mkTests p).version.drvPath == p.tests.version.drvPath);
assert
  (p.edit (s: s // { base = s.base.override { compiler = sentinel; }; })).artifact.drvPath
  != p.artifact.drvPath;
assert runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
assert suffix.artifact.drvPath == p.artifact.drvPath && suffix.drvPath != p.drvPath;
assert source.artifact.drvPath != p.artifact.drvPath;
assert build.artifact.drvPath != p.artifact.drvPath;
p.testContext.mkTest {
  package = p;
  name = "split";
  tools = [
    p.specification.python
    p.specification.patchelf
    p.specification.coreutils
  ];
  script = ''
    ${p.specification.python}/bin/python3 -B ${../../../../lib/tests/ordinary-rpaths.py} \
      ${../ordinary/relocate.py} ${p.specification.patchelf}/bin/patchelf \
      ${p.specification.coreutils}/bin/true >&2
    test -s ${sourceProbe}/source-marker
    test "$(cat ${suffix}/nix-support/final-control)" = selected
    ${runtime}/bin/make --version >&2
    printf split
  '';
  expected = "split";
}

# These finite controls run against the effective ordinary package.
{
  package,
  lib,
  context,
}:
let
  p = package;
  tools = (
    builtins.removeAttrs p.specification.base.tools [
      "gcc"
      "bash"
      "coreutils"
      "binutils"
    ]
  );
  runtime = p.editRuntime (r: r // { dlopenDirectories = [ "${tools.python}/lib" ]; });
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
  alternate = p.tvp.declaredTestDependencies.alternateSource;
  sentinel = p.tvp.declaredTestDependencies.sentinel;
  sourceProbe = (p.override { src = "${alternate}/source.tar.gz"; }).edit (
    s:
    let
      base = s.base.override { compiler = sentinel; };
    in
    (builtins.removeAttrs s [ "artifactName" ])
    // {
      inherit base;
      plan = [
        (
          base.environment s.environment
          // {
            name = "ordinary.source-compiler";
            run = ''
              mkdir source
              ${s.base.tools.gnutar}/bin/tar --use-compress-program=${s.base.tools.gzip}/bin/gzip -xf ${s.src} -C source --strip-components=1
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
context.mkTest {
  package = p;
  name = "split";
  tools = [
    tools.python
    tools.patchelf
    p.specification.coreutils
  ];
  script = ''
    ${tools.python}/bin/python3 -B ${./rpaths.py} \
      ${../../owned-split-output.py} ${../../../../lib/installed-tree.py} ${tools.patchelf}/bin/patchelf \
      ${p.specification.coreutils}/bin/true >&2
    test -s ${sourceProbe}/source-marker
    test "$(cat ${suffix}/nix-support/final-control)" = selected
    ${runtime}/bin/gzip --version >&2
    printf split
  '';
  expected = "split";
}

# Controls are attached only to the assigned older ordinary releases.
{ tvp, package }:
let
  p = package;
  s = p.specification;
  finalEdit = p.editRuntime (r: r // { shell = s.coreutils; });
  stripEdit = p.edit (old: old // { stripFlags = [ "-S" ]; });
  sourceEdit = p.edit (old: old // { src = s.coreutils; });
  compilerEdit = p.edit (
    old:
    old
    // {
      base = tvp.builder.base {
        inherit (old.base)
          name
          platform
          shell
          tools
          referencePackages
          ;
        compiler = old.base.compiler.edit (c: c // { version = c.version + "-contract"; });
      };
    }
  );
  toolEdit = p.edit (old: old // { gnutar = old.coreutils; });
in
assert (p.edit (x: x)).drvPath == p.drvPath;
assert (p.override { }).drvPath == p.drvPath;
assert finalEdit.artifact.drvPath == p.artifact.drvPath;
assert finalEdit.drvPath != p.drvPath;
assert stripEdit.artifact.drvPath == p.artifact.drvPath;
assert stripEdit.drvPath != p.drvPath;
assert sourceEdit.artifact.drvPath != p.artifact.drvPath;
assert compilerEdit.artifact.drvPath != p.artifact.drvPath;
assert toolEdit.artifact.drvPath != p.artifact.drvPath;
p.testContext.mkSuite {
  package = p;
  tools = s.environment.tools;
  tests.ordinary-installed-contract = {
    script =
      {
        gnugrep = ''
          printf 'x\000y\n' > binary
          ${p}/bin/grep -aq x binary
          mkdir tree; printf 'needle\n' > tree/input
          ${p}/bin/grep -rl needle tree | grep -Fx tree/input >&2
          status=0
          ${p}/bin/grep '[' binary > unused 2> diagnostic || status=$?
          test "$status" = 2; test -s diagnostic
          test "$(${p}/bin/egrep '^needle$' tree/input)" = needle
        '';
        gnused = ''
          printf 'abc123\n' | ${p}/bin/sed -E 's/([a-z]+)([0-9]+)/\2-\1/' > result
          test "$(cat result)" = 123-abc
          printf 'old\n' > input; ${p}/bin/sed -i.bak 's/old/new/' input
          test "$(cat input)" = new; test "$(cat input.bak)" = old
          export LOCPATH=${p.compiler.libc}/lib/locale LC_ALL=C.UTF-8
          printf 'é\n' | ${p}/bin/sed 's/./X/g' > result
          test "$(cat result)" = X
        '';
        gawk = ''
          test -x ${p}/bin/${p.tvp.readlineProgram}
          printf 'a:2\nb:3\n' | ${p}/bin/awk -F: '{sum+=$2} END {print sum}' > result
          test "$(cat result)" = 5
        '';
        diffutils = ''
          mkdir conflict
          printf '#!${s.bash}/bin/bash\nexit 99\n' > conflict/pr; chmod +x conflict/pr
          printf 'a\n' > a; printf 'b\n' > b
          status=0
          PATH="$PWD/conflict:$PATH" ${p}/bin/diff -l a b > result || status=$?
          test "$status" = 1; grep -q 'a b' result
          status=0
          ${p}/bin/cmp a missing 2> error || status=$?
          test "$status" = 2; test -s error
        '';
        findutils = ''
          mkdir tree conflict; touch 'tree/with space' tree/marker
          printf '#!${s.bash}/bin/bash\nexit 99\n' > conflict/sort; chmod +x conflict/sort
          PATH="$PWD/conflict" ${p}/bin/updatedb --localpaths="$PWD/tree" --prunepaths="" --netpaths="" --output="$PWD/locate.db"
          ${p}/bin/locate -d locate.db 'with space' | grep -F 'tree/with space' >&2
          ${p}/bin/find tree -type f -print0 | ${p}/bin/xargs -0 -n1 ${s.coreutils}/bin/basename | sort > result
          printf 'marker\nwith space\n' > expected; cmp result expected
        '';
      }
      .${p.pname}
      + "\necho ordinary-installed-contract\n";
    expected = "ordinary-installed-contract";
  };
}
// (
  if p.pname == "gnugrep" then
    p.testContext.mkSuite {
      package = p;
      tools = s.environment.tools;
      tests.ordinary-finalization-regressions = {
        script =
          let
            suffix =
              (builtins.foldl'
                (acc: step: {
                  reached = acc.reached || step.name == "gnugrep.finalize";
                  steps = acc.steps ++ (if acc.reached then [ step ] else [ ]);
                })
                {
                  reached = false;
                  steps = [ ];
                }
                p.buildSteps
              ).steps;
            commands = builtins.toFile "ordinary-text-final-suffix.sh" (
              builtins.concatStringsSep "\n" (map (step: step.run or "") suffix)
            );
          in
          ''
            printf 'int main(void) { return 0; }\n' > probe.c
            "$CC" probe.c -o dynamic
            ${s.python}/bin/python3 -B ${./ordinary-text-regressions.py} \
              ${./ordinary-text-source.py} ${./ordinary-text-output.py} ${./ordinary-text-check-paths.py} \
              ${../../lib/native-output} ${s.binutils}/bin/readelf ${s.patchelf}/bin/patchelf \
              ${s.bash}/bin/bash ${s.perl}/bin/perl ${commands} "$PWD/dynamic"
          '';
        expected = "frontend-and-complete-suffix-contracts";
      };
    }
  else
    { }
)

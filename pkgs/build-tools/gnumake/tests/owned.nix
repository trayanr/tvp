{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  steps = tvp.builder.steps;
  edited = (package.override { doCheck = false; }).editSteps (
    steps.insertAfter "gnumake.install" [
      {
        name = "probe.installed";
        run = ''
          test -x "$out/bin/make"
          printf 'ordered-install-edit\n' > "$out/owned-edit"
        '';
      }
    ]
  );
  shell = tvp.lib.packages.withConstraint {
    category = "construction";
    reason = "Customization probe uses the completed base shell as an independently built runtime interpreter.";
  } tvp.bases.default.components.floor.bash;
  runtime = (package.override { doCheck = false; }).editRuntime (r: r // { inherit shell; });
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    compiler-discovery = {
      script = ''
        status=0
        env -i PATH=/absent ${package}/bin/make -pf /dev/null > database || status=$?
        test "$status" = 2
        grep -E '^(CC|CXX) = ' database | sort
      '';
      expected = "CC = cc\nCXX = c++";
    };

    runtime-shell = {
      extraInputs = [
        runtime
        shell
      ];
      script = ''
        grep -aFq '${shell}/bin/sh' ${runtime}/bin/make
        printf 'all:\n\t@printf "42\\n"\n' > Makefile
        env -i PATH=/absent ${runtime}/bin/make --no-print-directory
      '';
      expected = "42";
    };

    default-shell = {
      script = ''
        mkdir empty
        printf 'all:\n\t@value=declared; printf "%%s\\n" "$$value-shell"\n' > Makefile
        env -i PATH="$PWD/empty" ${package}/bin/make --no-print-directory
      '';
      expected = "declared-shell";
    };
    recursive-jobserver = {
      script = ''
        printf 'all: child\nchild:\n\t+@$(MAKE) --no-print-directory -f child.mk\n' > Makefile
        printf 'all: a b\na b:\n\t@printf "%%s\\n" "$@"\n' > child.mk
        ${package}/bin/make --no-print-directory -j2 --output-sync=target | sort
      '';
      expected = "a\nb";
    };
    installed-header = {
      script = ''
        test -f ${package}/include/gnumake.h
        grep -F 'gmk_alloc' ${package}/include/gnumake.h >&2
        echo ok
      '';
      expected = "ok";
    };
    named-edit = {
      extraInputs = [ edited ];
      script =
        assert edited.tests.operation.drvPath != package.tests.operation.drvPath;
        ''
          test "$(${edited}/bin/make --version | head -1)" = 'GNU Make ${package.version}'
          cat ${edited}/owned-edit
        '';
      expected = "ordered-install-edit";
    };
  };
}

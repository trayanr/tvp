{
  pkgs,
  tvpLib,
  tvp,
  package,
}:
package.testContext.mkSuite {
  inherit package;
  tests = {
    version = {
      script = ''
        ${package}/bin/make --version | head -1 | ${package.tvp.deps.grep}/bin/grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf 'all: a b\na b:\n\t@echo $@\n' > Makefile
        ${package}/bin/make --no-print-directory -j2 --output-sync=target | sort
      '';
      expected = "a\nb";
    };
  };
}
// (
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
    } (import ../../../../bases/source-gnu { }).tools.bash;
    runtime = (package.override { doCheck = false; }).editRuntime (r: r // { inherit shell; });
  in
  package.testContext.mkSuite {
    inherit package;
    tools = [ package.tvp.deps.grep ];
    tests = {
      compiler-discovery = {
        script = ''
            status=0
            env -i PATH=/absent ${package}/bin/make -pf /dev/null > database || status=$?
            test "$status" = 2
            printf 'int main(void) { return 0; }\n' > discover-c.c
          cp discover-c.c discover-cxx.cpp
          printf 'all: discover-c discover-cxx\n' > Makefile
          env -u CC -u CXX ${package}/bin/make --no-print-directory >&2
          env -i ./discover-c
          env -i ./discover-cxx
          ${package.tvp.deps.grep}/bin/grep -E '^(CC|CXX) = ' database | sort
        '';
        expected = "CC = cc\nCXX = c++";
      };

      runtime-shell = {
        tools = [
          runtime
          shell
        ];
        script = ''
          ${package.tvp.deps.grep}/bin/grep -aFq '${shell}/bin/sh' ${runtime}/bin/make
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
          ${package.tvp.deps.grep}/bin/grep -F 'gmk_alloc' ${package}/include/gnumake.h >&2
          echo ok
        '';
        expected = "ok";
      };
      named-edit = {
        tools = [ edited ];
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
)
// {
  constructor = import ../../native-tool-contract.nix { inherit pkgs tvp package; };
}
// (package.testContext.mkSuite {
  inherit package;
  tools = [ package.tvp.deps.grep ];
  tests = {
    loadable-api = {
      script = ''
        "$CC" -fPIC -shared -I${package}/include ${./fixtures/module.c} -o module.so
        printf 'load ./module.so\nall:\n\t@printf "%%s\\n" "$(tvp_answer ignored)"\n' > Makefile
        env -i PATH=/absent ${package}/bin/make --no-print-directory
      '';
      expected = "42";
    };
    nested-jobserver = {
      script = ''
        printf 'all: child\nchild:\n\t+@$(MAKE) --no-print-directory -f child.mk\n' > Makefile
        printf 'all: a b\na b:\n\t+@$(MAKE) --no-print-directory -f leaf.mk LEAF=$@\n' > child.mk
        printf 'all:\n\t@printf "%%s\\n" "$(LEAF):$(MAKEFLAGS)"\n' > leaf.mk
        ${package}/bin/make --no-print-directory -j2 --output-sync=target > nested.log
        test "$(grep -c -- '--jobserver-auth=' nested.log)" = 2
        test "$(grep -c -- '-j2' nested.log)" = 2
        ${package}/bin/make --no-print-directory -j1 --output-sync=target > serial.log
        if grep -q -- '--jobserver-auth=' serial.log; then exit 1; fi
        test "$(grep -c -- '-j1' serial.log)" = 2
        ${package.tvp.deps.python}/bin/python3 ${./fixtures/jobserver.py} ${package}/bin/make ${package.tvp.deps.python}/bin/python3
        printf controlled
      '';
      expected = "controlled";
    };
    installed-payload = {
      script = ''
        test -s ${package}/share/info/make.info
        test -s ${package}/share/man/man1/make.1.gz
        test -s ${package}/nix-support/source-date-epoch
        printf manuals
      '';
      expected = "manuals";
    };
  };
})

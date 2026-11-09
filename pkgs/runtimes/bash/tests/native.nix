{
  pkgs,
  tvpLib,
  package,
}:
package.testContext.mkSuite {
  tools = with package.specification; [
    sed
    grep
    gawk
    diffutils
    findutils
  ];
  inherit package;
  tests = {
    version = {
      script = ''
        ${package}/bin/bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        ${package}/bin/bash --noprofile --norc -c 'set -euo pipefail; declare -A names=([tvp]=preserved); mapfile -t lines < <(printf "%s\n" "''${names[tvp]}"); printf "%s\n" "''${lines[0]}"'
      '';
      expected = "preserved";
    };
    self-helpers = {
      script = ''
        test "$(readlink ${package}/bin/sh)" = bash
        test "$(head -1 ${package}/bin/bashbug)" = '#!${package}/bin/bash -'
        ${package}/bin/bashbug --version | head -1
        grep -q '^INSTALL = install -c$' ${package}/lib/bash/Makefile.inc
        test "$(tail -1 ${package}/lib/bash/Makefile.inc)" = 'SHELL = ${package}/bin/bash'
      '';
      expected = "GNU bashbug, version ${package.version}-release";
    };
    readline-curses = {
      script = ''
        # Consume complete outputs before quiet searches so producers cannot hit SIGPIPE.
        ${package}/bin/bash --noprofile --norc -c 'bind -l' > functions
        grep -q '^complete$' functions
        ${package.specification.binutils}/bin/readelf -d ${package}/bin/bash > dynamic
        grep -q libncursesw dynamic
        ${package}/bin/bash --noprofile --norc -c 'set -o emacs; bind "set editing-mode vi"; bind -v' > bindings
        grep -q '^set editing-mode vi$' bindings
        printf ok
      '';
      expected = "ok";
    };
    loadable-module = {
      tools = with package.specification; [
        gnumake
        sed
        grep
      ];
      script = ''
        cat > answer.c <<'EOF'
        #include "config.h"
        #include <stdio.h>
        #include "builtins.h"
        #include "shell.h"
        int answer_builtin(WORD_LIST *list) { printf("42\n"); return 0; }
        char *answer_doc[] = { "Print the answer", 0 };
        struct builtin answer_struct = { "answer", answer_builtin, BUILTIN_ENABLED, answer_doc, "answer", 0 };
        EOF
        printf 'include ${package}/lib/bash/Makefile.inc\nall: answer.o\n\t$(SHOBJ_LD) $(SHOBJ_LDFLAGS) answer.o -o answer.so\n' > Makefile
        make --no-print-directory CC="$CC" SHOBJ_CC="$CC" CFLAGS=-std=gnu17 >&2
        ${package}/bin/bash --noprofile --norc -c 'enable -f ./answer.so answer; answer; enable -d answer'
      '';
      expected = "42";
    };
    upstream-shipped = {
      tools = with package.specification; [
        gnutar
        gzip
        sed
        grep
        diffutils
      ];
      script = ''
        tar -xzf ${package.src} --strip-components=2 bash-${package.version}/tests bash-${package.version}/support/recho.c bash-${package.version}/support/zecho.c bash-${package.version}/support/printenv.c
        for helper in recho zecho printenv; do
          "$CC" -std=gnu17 -DHAVE_CONFIG_H -I${package}/include/bash -I${package}/include/bash/include "$helper.c" -o "$helper"
        done
        mkdir helper-bin
        printf '#!${package.specification.bash}/bin/bash\nexec ${package.specification.grep}/bin/grep -E "$@"\n' > helper-bin/egrep
        chmod +x helper-bin/egrep
        export PATH="$PWD/helper-bin:$PWD:$PATH"
        export THIS_SH=${package}/bin/bash BASH_TSTOUT="$PWD/actual" BUILD_DIR="$PWD"
        for suite in arith array assoc; do
          ${package}/bin/bash "run-$suite" >&2
          printf 'PASS:%s\n' "$suite"
        done
      '';
      expected = "PASS:arith\nPASS:array\nPASS:assoc";
    };
    helper-boundaries = {
      tools = [
        package.specification.python
        package.specification.binutils
        package.specification.patchelf
      ];
      script = ''
        ${package.specification.python}/bin/python3 -B ${./helper-safety.py} ${../native} ${../../../../lib/native-output} \
          ${package}/bin/bash ${package.specification.binutils}/bin/readelf ${package.specification.patchelf}/bin/patchelf
      '';
      expected = "boundaries-ok";
    };
  };
}

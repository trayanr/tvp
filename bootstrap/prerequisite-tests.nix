# Explicit opt-in Tower contracts. Never part of the ordinary catalogue plan.
{ scope }:
let
  inherit (scope)
    bash
    binutils
    linux-headers
    build-m4
    build-bison
    build-python
    build-grep
    ;
  cc = scope.gcc-latest;
  shell = "${bash}/bin/bash";
  glibcSource = scope.fetchurl {
    url = "mirror://gnu/libc/glibc-2.39.tar.xz";
    hash = "sha256-93vUfPgXDFc2Wue/hmlsEYrbOxINMlnGTFAtPcHi2SY=";
  };
in
{
  prerequisites =
    bash.runCommand "tvp-bootstrap-prerequisite-contracts"
      {
        nativeBuildInputs = [
          cc
          binutils
          scope.gnugrep
          scope.findutils
          scope.diffutils
          scope.gnutar-latest
          scope.xz
        ];
        outputs = [
          "out"
          "evidence"
        ];
      }
      ''
        mkdir -p "$out/bin" "$evidence"
        cat > uapi.c <<'C'
        #include <linux/version.h>
        #include <linux/types.h>
        #include <linux/ioctl.h>
        #include <linux/unistd.h>
        #include <asm/unistd.h>
        _Static_assert(LINUX_VERSION_CODE == 395520, "Linux 6.9.0");
        _Static_assert(LINUX_VERSION_MAJOR == 6 && LINUX_VERSION_PATCHLEVEL == 9, "version");
        _Static_assert(sizeof(__u64) == 8 && __NR_read == 0, "x86_64 UAPI");
        int main(void) { return _IOC_TYPE(_IO('x', 1)) != 'x'; }
        C
        ${cc}/bin/gcc -I${linux-headers}/include -H uapi.c -o "$out/bin/uapi" 2> "$evidence/header-selection"
        "$out/bin/uapi"
        grep -F '${linux-headers}/include/linux/types.h' "$evidence/header-selection"
        find ${linux-headers}/include -type f | sort > "$evidence/header-inventory"
        test -z "$(find ${linux-headers}/include -type f ! -name '*.h')"
        test ! -e ${linux-headers}/include/linux/sched/signal.h
        test ! -e ${linux-headers}/scripts
        cat > include.m4 <<'M4'
        define(`answer', `42')dnl
        M4
        cat > macro.m4 <<'M4'
        include(`include.m4')dnl
        answer
        syscmd(`printf syscmd-ok > syscmd.txt')dnl
        esyscmd(`printf esyscmd-ok')
        M4
        env -i PATH= ${build-m4}/bin/m4 macro.m4 > "$evidence/m4"
        grep -Fx 42 "$evidence/m4"
        grep -Fx esyscmd-ok "$evidence/m4"
        test "$(cat syscmd.txt)" = syscmd-ok
        cat > parser.y <<'YACC'
        %{
        int yylex(void); void yyerror(const char *s);
        static int result;
        %}
        %token NUMBER
        %%
        input: NUMBER '+' NUMBER { result = $1 + $3; };
        %%
        int yylex(void) {
          static int step;
          switch (step++) {
          case 0: yylval=19; return NUMBER;
          case 1: return '+';
          case 2: yylval=23; return NUMBER;
          default: return 0;
          }
        }
        void yyerror(const char *s) { (void)s; }
        int main(void) { return yyparse() || result != 42; }
        YACC
        env -i PATH= ${build-bison}/bin/bison -Wall --defines=parser.h -o parser.c parser.y
        ${cc}/bin/gcc parser.c -o "$out/bin/parser"
        "$out/bin/parser"
        env -i PATH= ${build-bison}/bin/yacc -o yacc.c parser.y
        ${cc}/bin/gcc yacc.c -o "$out/bin/yacc-parser"
        "$out/bin/yacc-parser"
        env -i PATH= ${build-bison}/bin/bison --print-datadir > "$evidence/bison-datadir"
        test "$(cat "$evidence/bison-datadir")" = ${build-bison}/share/bison
        env -i PATH= TMPDIR="$TMPDIR" ${build-python}/bin/python3 ${./prerequisite-python.py} ${shell} > "$evidence/python"
        env -i PATH= ${build-python}/bin/python3-config --includes > "$evidence/python-config"
        # The source archive is data only. No libc build or privileged operation.
        tar xf ${glibcSource} glibc-2.39/scripts glibc-2.39/math/gen-libm-test.py
        env -i PATH= ${build-python}/bin/python3 glibc-2.39/scripts/gen-as-const.py --help > "$evidence/glibc-help"
        printf 'ANSWER 6 * 7\n' > constants.sym
        env -i PATH= ${build-python}/bin/python3 glibc-2.39/scripts/gen-as-const.py \
          --cc=${cc}/bin/gcc constants.sym > "$evidence/glibc-constants"
        grep -F '#define ANSWER 42' "$evidence/glibc-constants"
        env -i PATH= ${build-python}/bin/python3 glibc-2.39/math/gen-libm-test.py --help > "$evidence/glibc-math-help"
        printf 'alpha\na+b\nabb\n-flag\n' > 'input space'
        env -i PATH= ${build-grep}/bin/grep '^a.*a$' 'input space' > bre
        test "$(cat bre)" = alpha
        env -i PATH= ${build-grep}/bin/grep -E 'a(b|c)+' 'input space' > ere
        test "$(cat ere)" = abb
        env -i PATH= ${build-grep}/bin/grep -F 'a+b' 'input space' > fixed
        test "$(cat fixed)" = a+b
        env -i PATH= ${build-grep}/bin/egrep -- '^a(b|c)+$' 'input space' > ere-wrapper
        cmp ere ere-wrapper
        env -i PATH= ${build-grep}/bin/fgrep -e '-flag' -- 'input space' > fixed-wrapper
        test "$(cat fixed-wrapper)" = -flag
        status=0
        env -i PATH= ${build-grep}/bin/grep absent 'input space' || status=$?
        test "$status" = 1
        status=0
        env -i PATH= ${build-grep}/bin/grep '[' 'input space' 2> "$evidence/grep-invalid" || status=$?
        test "$status" = 2
        for f in "$out"/bin/* ${build-m4}/bin/m4 ${build-bison}/bin/bison \
          ${build-python}/bin/python3.12 ${build-grep}/bin/grep; do
          readelf -h -l -d "$f" > "$evidence/$(basename "$f").elf"
          grep -F '${scope.musl}/lib/libc.so' "$evidence/$(basename "$f").elf"
          if grep -E 'NEEDED.*(libstdc\+\+|libgcc_s|libssl|libcrypto|libz\.)' "$evidence/$(basename "$f").elf"; then exit 1; fi
        done
      '';
}

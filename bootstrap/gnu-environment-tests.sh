set -euo pipefail
mkdir -p "$out/bin"
cc=$PRIVATE_CC cxx=$PRIVATE_CXX
expect_failure() {
    if "$@" > negative.log 2>&1; then printf 'unexpected success: %s\n' "$*" >&2; exit 1; fi
    cat negative.log
}
printf '%s\n' 'int main(void) { return VALUE != 37; }' > main.c
NIX_CFLAGS_COMPILE=-DVALUE=37 "$cc" main.c -o value
 env -i ./value
NIX_CFLAGS_COMPILE=-DVALUE=38 "$cc" main.c -o value-bad
expect_failure env -i ./value-bad
# All injected linker options are deliberately invalid in compile/query modes.
export NIX_CFLAGS_COMPILE=-DVALUE=37 NIX_CFLAGS_LINK=-Wl,--definitely-invalid NIX_LDFLAGS=--definitely-invalid
"$cc" -c main.c -o main.o
"$cc" --compile main.c -o alias.o
"$cc" --assemble main.c -o alias.s
"$cc" --preprocess main.c -o alias.i
"$cc" --print-search-dirs > alias-search
"$cc" --target-help > target-help
"$cc" -S main.c -o main.s
"$cc" -E main.c -o main.i
"$cc" -M main.c > deps
"$cc" -MM main.c > user-deps
"$cc" -fsyntax-only main.c
"$cc" -dumpmachine > machine
"$cc" -print-search-dirs > search
"$cc" --version > version
"$PRIVATE_CPP" main.c > cpp.i
printf '%s\n' '-c main.c -o response.o' > inner.rsp
printf '%s\n' '@inner.rsp' > outer.rsp
"$cc" @outer.rsp
printf '%s\n' '-\' 'c main.c -o continued.o' > continued.rsp
"$cc" @continued.rsp
printf '%s\n' '-c main.c -o "response space,comma.o"' > spaces.rsp
"$cc" @spaces.rsp
printf '%s\n' "-c main.c -o 'single\\quoted.o'" > single.rsp
"$cc" @single.rsp
test -s 'single\quoted.o'
printf '%s\n' '-c main.c -o "double\q.o"' > double.rsp
"$cc" @double.rsp
test -s 'double\q.o'
test -s 'response space,comma.o'
expect_failure "$cc" main.c -o should-not-link
unset NIX_CFLAGS_LINK NIX_LDFLAGS
printf '%s\n' 'int main(void) { return VALUE != 37; }' | "$cc" -v -x c - -o stdin
 env -i ./stdin
# GCC's tolerant unterminated quote handling must still be forwarded.
printf '%s' '-c main.c -o "unterminated.o' > tolerant.rsp
"$cc" @tolerant.rsp
test -s unterminated.o
# Direct argv is untouched, including spaces, commas, and literal shell syntax.
mkdir -p 'include space,comma'
printf '%s\n' '#define LITERAL "$(touch-pwned);*`touch-pwned`"' > 'include space,comma/literal.h'
cat > literal.c <<'C'
#include <string.h>
#include <literal.h>
int main(void) { return strcmp(TEXT, LITERAL); }
C
"$cc" '-Iinclude space,comma' '-DTEXT="$(touch-pwned);*`touch-pwned`"' literal.c -o 'literal space,comma'
env -i './literal space,comma'
NIX_CFLAGS_COMPILE='-DTEXT="$(touch-pwned);*`touch-pwned`"' "$cc" '-Iinclude space,comma' literal.c -o literal-env
env -i ./literal-env
test ! -e touch-pwned
# Flags are literal argv even when they look like standalone shell commands.
expect_failure env 'NIX_CFLAGS_COMPILE=$(touch pwned)' "$cc" -c main.c
expect_failure env 'NIX_CFLAGS_COMPILE=`touch-pwned`' "$cc" -c main.c
test ! -e pwned
expect_failure env NIX_LDFLAGS=a,b "$cc" main.c
expect_failure env NIX_HARDENING_ENABLE=fortify "$cc" -c main.c
expect_failure "$cc" -m32 -c main.c
printf '%s\n' '-m32 -c main.c' > abi.rsp
expect_failure "$cc" @abi.rsp
# Both flag namespaces must change the linked artifact.
NIX_CFLAGS_LINK=-Wl,--defsym,adapter_link=43 NIX_LDFLAGS='--defsym adapter_ld=47' "$cc" main.c -o symbols
"$NM" symbols > symbols.txt
grep_symbol() { local line; while IFS= read -r line; do [[ $line == *"$1" ]] && return 0; done < symbols.txt; return 1; }
grep_symbol '000000000000002b A adapter_link'
grep_symbol '000000000000002f A adapter_ld'
# Mode-looking operands belong to their option, including in response files.
NIX_CFLAGS_LINK='-Xlinker -E' "$cc" main.c -o export-direct
env -i ./export-direct
printf '%s\n' '-Xlinker -E' > link-operand.rsp
NIX_CFLAGS_LINK=@link-operand.rsp "$cc" main.c -o export-response
env -i ./export-response
# The declared order of library directories changes the chosen implementation.
mkdir first second
printf '%s\n' 'int chosen(void) { return 1; }' > first.c
printf '%s\n' 'int chosen(void) { return 2; }' > second.c
"$cc" -c first.c -o first.o; "$AR" crD first/libchosen.a first.o
"$cc" -c second.c -o second.o; "$AR" crD second/libchosen.a second.o
printf '%s\n' 'int chosen(void); int main(void) { return chosen() != EXPECT; }' > order.c
NIX_CFLAGS_COMPILE=-DEXPECT=1 NIX_LDFLAGS="$ORDER12" "$cc" order.c -lchosen -o order1
NIX_CFLAGS_COMPILE=-DEXPECT=2 NIX_LDFLAGS="$ORDER21" "$cc" order.c -lchosen -o order2
env -i ./order1; env -i ./order2
# Header discovery fails without B, or without B's public A dependency.
printf '%s\n' '#include <adapter_b.h>' 'int main(void) { return b_value() != 8; }' > discovery.c
expect_failure env NIX_CFLAGS_COMPILE="$MISSING" "$cc" -c discovery.c
expect_failure env NIX_CFLAGS_COMPILE="$B_ONLY" "$cc" -c discovery.c
NIX_CFLAGS_COMPILE="$FULL" "$cc" -c discovery.c -o discovery.o
expect_failure env NIX_LDFLAGS= "$cc" discovery.o -ladapter_b -ladapter_a -o missing-link
printf '%s\n' '#include <mpfr.h>' 'int main(void) { return 0; }' > missing-gmp.c
expect_failure env NIX_CFLAGS_COMPILE="$MPFR_ONLY" "$cc" -c missing-gmp.c
# Shared, static, C++ and supported PIE modes use the same raw GNU compiler.
printf '%s\n' 'int main(void) { return 0; }' > zero.c
unset NIX_CFLAGS_COMPILE
NIX_CFLAGS_COMPILE= NIX_CFLAGS_LINK= NIX_LDFLAGS= "$cc" zero.c -o empty-flags
env -i ./empty-flags
"$cc" -static zero.c -o static
env -i ./static
"$cc" -fPIE -pie zero.c -o pie
env -i ./pie
expect_failure "$cc" -fPIE -static-pie zero.c -o static-pie
expect_failure env NIX_CFLAGS_LINK=-static-pie "$cc" zero.c -o static-pie
expect_failure env NIX_CFLAGS_LINK=-c "$cc" zero.c -o wrong-mode
# Direct linker argv with commas/spaces bypasses the restricted encoder.
"$cc" zero.c -Xlinker -Map -Xlinker 'map space,comma' -o direct-map
test -s 'map space,comma'
"$cc" -no-pie zero.c -o no-pie
env -i ./no-pie
printf '%s\n' '#include <string>' 'int main() { return std::string("ok") != "ok"; }' > cxx.cc
"$cxx" cxx.cc -o cxx
env -i ./cxx
"$cxx" -fPIE -pie cxx.cc -o cxx-pie
env -i ./cxx-pie
"$cxx" -static cxx.cc -o cxx-static
env -i ./cxx-static
"$cxx" -fPIC -shared cxx.cc -o libcxx-fixture.so
cp value symbols pie static no-pie cxx cxx-static "$out/bin/"
cp libcxx-fixture.so "$out/"
printf 'GNU protocol and negative assertions passed\n' > "$out/assertions"

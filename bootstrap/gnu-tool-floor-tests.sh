# Invoked explicitly by the selected GNU Bash, in env -i.
set -eu
expect_status() {
    expected=$1; shift
    status=0; "$@" || status=$?
    test "$status" = "$expected" || { printf 'expected %s, got %s: %s\n' "$expected" "$status" "$*"; exit 1; }
}
for command in "$ATTR/bin/getfattr" "$ACL/bin/getfacl" "$CORE/bin/cp" "$MAKE/bin/make" "$FIND/bin/find" "$DIFF/bin/diff"; do
    env -i "$command" --version
 done
case $(readelf -d "$CORE/bin/factor") in *'Shared library: [libgmp.so.10]'*) :;; *) exit 1;; esac
case $(readelf -d "$CORE/bin/cp") in *'Shared library: [libacl.so.1]'*) :;; *) exit 1;; esac
mkdir attr-test acl-test core-test find-test diff-test make-test
# Public API linkage and library-only behavior do not depend on filesystem support.
(cd attr-test; env -i "$PROBES/attr-api" "$ATTR/lib/libattr.so.1" --linkage-only)
env -i "$PROBES/acl-api"
xattr_status=0; env -i "$PROBES/preflight" xattrs > "$EVIDENCE/xattr-preflight" 2>&1 || xattr_status=$?
acl_status=0; env -i "$PROBES/preflight" acls > "$EVIDENCE/acl-preflight" 2>&1 || acl_status=$?
setid_status=0; env -i "$PROBES/preflight" set-id > "$EVIDENCE/setid-preflight" 2>&1 || setid_status=$?
case $setid_status in 0|77) :;; *) cat "$EVIDENCE/setid-preflight"; exit 1;; esac
printf 'set-id=%s\n' "$setid_status" > "$EVIDENCE/setid-status"
printf 'xattrs=%s acls=%s\n'  "$xattr_status" "$acl_status" > "$EVIDENCE/filesystem-status"
case $xattr_status in
  0)
    (cd attr-test; env -i "$PROBES/attr-api" "$ATTR/lib/libattr.so.1")
    touch xattr-file
    setfattr -n user.tvp -v roundtrip xattr-file
    test "$(getfattr --only-values -n user.tvp xattr-file)" = roundtrip
    setfattr -x user.tvp xattr-file
    expect_status 1 getfattr -n user.tvp xattr-file
    ;;
  77) printf '%s\n' 'UNSUPPORTED sandbox user xattrs; installed linkage passed';;
  *) cat "$EVIDENCE/xattr-preflight"; exit 1;;
esac
case $acl_status in
  0)
    (cd acl-test; env -i "$PROBES/acl-native")
    touch acl-file
    setfacl -m u:12345:r-- acl-file
    getfacl -n -c acl-file > acl-before
    cp --preserve=all acl-file acl-copy
    getfacl -n -c acl-copy > acl-after
    cmp acl-before acl-after
    setfacl -b acl-file
    ;;
  77) printf '%s\n' 'UNSUPPORTED sandbox POSIX ACLs; installed linkage passed';;
  *) cat "$EVIDENCE/acl-preflight"; exit 1;;
esac
(cd core-test
 printf 'beta\nalpha\nbeta\n' > original
 chmod 640 original
 cp -p original copied
 test "$(stat -c %a copied)" = 640
 cmp original copied
 ln copied hard; ln -s copied soft
 test "$(stat -c %i hard)" = "$(stat -c %i copied)"
 test "$(readlink soft)" = copied
 test "$(sort -u original)" = $'alpha\nbeta'
 test "$(cut -c 1 original | tr a-z A-Z)" = $'B\nA\nB'
 test "$(seq 3 | paste -sd ,)" = 1,2,3
 # Values beyond fixed-width integers exercise the GMP-backed factor path.
 test "$(factor 18446744073709551617)" = '18446744073709551617: 274177 67280421310721'
 expect_status 124 timeout 0.05 sleep 5
 test "$(env -i TVP=owned "$BASH" -c 'printf %s "$TVP"')" = owned
 test "$(printf 'one\ntwo\n' | wc -l)" = 2
 stdbuf -oL cat original > buffered; cmp original buffered
)
(cd make-test
 cat > Makefile <<'MAKEFILE'
VAR = native
WORDS := $(shell printf '%s' 'shell-function')
all: first.out second.out ordered
	@test '$(VAR)' = native && test '$(WORDS)' = shell-function && test '$(CXX)' = c++
	@test '$(SHELL)' = '$(EXPECTED_SHELL)'
	@case "$$BASH_VERSION" in '') exit 1;; *) printf '%s\n' default-gnu-shell;; esac
%.out: %.in
	@cat $< > $@
ordered: first.out second.out | directory
	@test -d directory && cat first.out second.out > ordered
directory:
	@mkdir directory
MAKEFILE
 printf 'first\n' > first.in; printf 'second\n' > second.in
 env -i PATH="$PATH" EXPECTED_SHELL="$BASH" "$MAKE/bin/make" -j4 all
 test "$(cat ordered)" = $'first\nsecond'
 # env-i with PATH absent still proves the compiled default shell for shell syntax.
 printf 'all:\n\t@case "$$BASH_VERSION" in ?*) printf "%%s\\n" owned;; *) exit 1;; esac\n' > Empty.mk
 test "$(env -i "$MAKE/bin/make" -s -f Empty.mk)" = owned
 expect_status 2 "$MAKE/bin/make" -q first.out missing-target
)
(cd find-test
 mkdir -p root/keep root/skip
 touch 'root/keep/space name' $'root/keep/line\nbreak' root/skip/hidden
 find root -path root/skip -prune -o -type f -print0 > names
 printf 'root/keep/space name\0root/keep/line\nbreak\0' | sort -z > expected
 sort -z names > sorted
 cmp expected sorted
 xargs -0 -n1 "$BASH" -c 'test -f "$1"; printf "%s\0" "$1"' _ < names > echoed
 cmp names echoed
 test "$(find root/keep -type f -exec printf 'x' \;)" = xx
 test "$(find root/keep -type f -exec "$BASH" -c 'test "$#" = 2' _ {} +; printf '%s' "$?")" = 0
 expect_status 123 xargs -r "$BASH" -c 'exit 7' < <(printf 'argument\n')
 expect_status 1 find missing -print
 test ! -e "$FIND/bin/updatedb"; test ! -e "$FIND/bin/locate"
)
(cd diff-test
 printf 'alpha\nbeta\n' > left; cp left same
 printf 'alpha\ngamma\n' > right
 cmp left same; diff left same
 expect_status 1 cmp left right
 expect_status 1 diff -u left right
 expect_status 1 sdiff left right
 expect_status 1 diff -l left right > paginated
 test -s paginated
 case $(cat paginated) in *'Page 1'*) :;; *) exit 1;; esac
 expect_status 2 diff left absent
)
printf '%s\n' 'PASS: installed GNU utility contracts (filesystem coverage recorded separately)'

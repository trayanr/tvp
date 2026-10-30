set -euo pipefail
export LC_ALL=C
version=$1
mkdir owned
cd owned
touch file
setfattr -n user.text -v 'text with spaces' file
setfattr -n user.binary -v 0x00ff0122 file
getfattr -d -e hex file > before
setfattr -x user.text file
setfattr -x user.binary file
setfattr --restore=before 2> diagnostics
getfattr -d -e hex file > after
cmp before after
ln -s file link
getfattr -d -e hex link | sed 's/# file: link/# file: file/' > followed
cmp before followed
test -z "$(getfattr -h -d link)"
if setfattr -h -n user.text -v changed link 2> nofollow-error; then
  echo 'unexpected user xattr on symlink' >&2
  exit 1
fi
getfattr -d -e hex file > after
cmp before after
# A restore naming a leaf symlink follows it unless -h is given.
printf '# file: link\nuser.text="restored"\n\n' > leaf
setfattr --restore=leaf 2> leaf-warning
test "$(getfattr --only-values -n user.text file)" = restored
if setfattr -h --restore=leaf 2> leaf-error; then
  echo 'unexpected no-dereference restore success' >&2
  exit 1
fi
test "$(getfattr --only-values -n user.text file)" = restored
setfattr -x user.text file
if getfattr -n user.text file > removed 2>&1; then exit 1; fi
grep -Fq 'No such attribute' removed

if test "$version" = 2.6.0; then
  # The unpatched default configure enables both unsafe-restore warnings.
  test "$(grep -c '^Warning:' diagnostics)" = 2
  grep -Fq 'without option -P (--physical)' diagnostics
  grep -Fq 'without option -h (--no-dereference)' diagnostics
  mkdir real
  touch real/target
  ln -s real alias
  printf '# file: real/target\nuser.safe="roundtrip"\n\n' > physical
  setfattr -P -h --restore=physical 2> safe-warning
  test ! -s safe-warning
  test "$(getfattr --only-values -n user.safe real/target)" = roundtrip
  setfattr -x user.safe real/target
  printf '# file: alias/target\nuser.safe="blocked"\n\n' > through-link
  if setfattr -P -h --restore=through-link 2> physical-error; then exit 1; fi
  grep -Fq 'without following symlinks' physical-error
  if getfattr -n user.safe real/target > absent 2>&1; then exit 1; fi
  # -h alone permits symlink directory traversal; all targets are owned fixtures.
  setfattr -h --restore=through-link 2> directory-warning
  test "$(getfattr --only-values -n user.safe real/target)" = blocked
  test "$(grep -c '^Warning:' directory-warning)" = 1
  grep -Fq 'without option -P (--physical)' directory-warning
  setfattr -P --restore=physical 2> dereference-warning
  test "$(grep -c '^Warning:' dereference-warning)" = 1
  grep -Fq 'without option -h (--no-dereference)' dereference-warning
else
  test ! -s diagnostics
fi
echo ok

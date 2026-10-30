set -euo pipefail
export LC_ALL=C
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
mkdir src
printf 'preserved\n' > src/file
ln src/file src/hard
ln -s file src/sym
printf 'quoted\n' > 'src/name "quoted"'
for format in gnu ustar pax; do
  mkdir "$format"
  "$TAR" --format="$format" -cf "$format.tar" src
  "$TAR" -tf "$format.tar" > "$RESULTS/$format.list"
  grep -Fx src/hard "$RESULTS/$format.list"
  "$TAR" -xf "$format.tar" -C "$format"
  cmp src/file "$format/src/file"
  cmp 'src/name "quoted"' "$format/src/name \"quoted\""
  test "$(stat -c %i "$format/src/file")" = "$(stat -c %i "$format/src/hard")"
  test "$(readlink "$format/src/sym")" = file
  "$TAR" -df "$format.tar" -C "$format"
  echo "PASS $format create/list/extract/compare, hard/symbolic/quoted names"
done
long=$(printf '%0150d' 1)
printf long > "src/$long"
truncate -s 8388608 src/sparse
printf tail | dd of=src/sparse bs=1 seek=8388604 conv=notrunc status=none
for format in gnu pax; do
  mkdir "sparse-$format"
  "$TAR" --format="$format" --sparse -cf "sparse-$format.tar" src
  "$TAR" -xf "sparse-$format.tar" -C "sparse-$format"
  cmp src/sparse "sparse-$format/src/sparse"
  cmp "src/$long" "sparse-$format/src/$long"
  test "$(stat -c %b "sparse-$format/src/sparse")" -lt 1024
  "$TAR" -df "sparse-$format.tar" -C "sparse-$format"
  echo "PASS $format sparse/long names"
done
# The default PAX extended-header name changed in 1.33; POSIXLY_CORRECT
# continues to include a PID. Only header names are inspected, never replayed.
for posix in no yes; do
  if test "$posix" = yes; then
    POSIXLY_CORRECT=1 "$TAR" --format=pax -cf "header-$posix.tar" "src/$long"
  else
    env -u POSIXLY_CORRECT "$TAR" --format=pax -cf "header-$posix.tar" "src/$long"
  fi
  dd if="header-$posix.tar" bs=1 count=100 status=none | tr -d '\000' > "$RESULTS/pax-$posix.header"
  if test "$VERSION" = 1.32 || test "$posix" = yes; then
    grep -E '^src/PaxHeaders\.[0-9]+/' "$RESULTS/pax-$posix.header"
  else
    grep -E '^src/PaxHeaders/' "$RESULTS/pax-$posix.header"
  fi
  echo "PASS PAX header POSIXLY_CORRECT=$posix"
done
mkdir -p nodir/source/dir nodir/dest/dir
printf existing > nodir/dest/dir/existing
printf payload > nodir/source/dir/file
chmod 700 nodir/source/dir
chmod 755 nodir/dest/dir
touch -t 200001010000 nodir/dest/dir
before=$(stat -c %a nodir/dest/dir)
"$TAR" -cf nodir.tar -C nodir/source dir
"$TAR" --no-overwrite-dir -xf nodir.tar -C nodir/dest
test "$before" = "$(stat -c %a nodir/dest/dir)"
cmp nodir/source/dir/file nodir/dest/dir/file
echo 'PASS --no-overwrite-dir nonempty directory mode'
# First part of upstream 1.34 extrac23: historical empty-directory behavior.
mkdir empty
chmod 755 empty
"$TAR" -cf empty.tar empty
chmod 777 empty
"$TAR" --no-overwrite-dir -xf empty.tar
if test "$VERSION" = 1.32; then
  test "$(stat -c %a empty)" = 755
  echo 'PASS historical 1.32 extrac23: empty directory mode overwritten'
else
  test "$(stat -c %a empty)" = 777
  echo 'PASS extrac23 control: empty directory mode preserved'
fi
# Upstream 1.34 tests/extrac24.at, with its original shell body and observations.
mkdir stdout
cd stdout
mkdir dir/
echo TEXT > dir/file
"$TAR" cf a.tar dir
rm -r dir
"$TAR" --extract --to-stdout --file a.tar > "$RESULTS/to-stdout"
test "$(cat "$RESULTS/to-stdout")" = TEXT
if test "$VERSION" = 1.33; then
  test -d dir
  test ! -e dir/file
  echo 'PASS historical 1.33 extrac24: directory created, regular file only on stdout'
else
  test ! -d dir
  echo 'PASS extrac24 control: no directory created'
fi

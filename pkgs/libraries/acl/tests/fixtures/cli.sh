set -euo pipefail
version=$1
export LC_ALL=C
mkdir cli
cd cli
touch file ' leading'
chmod 640 file
if ! setfacl -m u:12345:r-- file 2>probe.err; then
    if grep -q 'Operation not supported' probe.err; then
        echo 'SKIP cli: filesystem rejects named ACLs'; exit 0
    fi
    cat probe.err; exit 1
fi
getfacl -n file > saved
setfacl -b file
setfacl --restore=saved 2>warning
getfacl -n file > roundtrip
cmp saved roundtrip
touch copied
getfacl -c -n file | setfacl --set-file=- copied
cmp <(getfacl -c -n file) <(getfacl -c -n copied)
mkdir inherited
setfacl -m d:u::rwx,d:u:12345:r-x,d:g::r-x,d:m::r-x,d:o::--- inherited
(umask 000; touch inherited/child)
getfacl -n inherited/child | grep -q 'user:12345:r-x.*effective:r--'
# --test must leave mode and ACL unchanged even when the backup differs.
chmod 600 file
getfacl -n file > before
before_mode=$(stat -c %a file)
setfacl --test --restore=saved > test-output 2>test-warning
test "$(stat -c %a file)" = "$before_mode"
getfacl -n file > after
cmp before after
# 2.3.x truncates an overflowing 32-bit qualifier to zero. Pin the exact
# historical observation against an explicit zero control; 2.4.0 rejects it.
for kind in u g; do
    status=0
    setfacl --test -m "$kind:4294967296:r--" file >invalid.out 2>invalid.err || status=$?
    if [ "$version" = 2.4.0 ]; then
        test "$status" != 0
        grep -q 'Invalid argument' invalid.err
    else
        test "$status" = 0
        setfacl --test -m "$kind:0:r--" file >zero.out
        cmp invalid.out zero.out
        echo "HISTORICAL $version: $kind qualifier 4294967296 truncates to zero (2.4.0 rejects)"
    fi
done
printf '# owner: root\n' > malformed
if setfacl --restore=malformed >malformed.out 2>malformed.err; then
    echo 'unexpected malformed restore success'; exit 1
fi
grep -q 'No filename found' malformed.err
# Leading whitespace is a historical restore parsing bug, fixed in 2.4.0.
setfacl -m u:12345:r-- ' leading'
getfacl -n ' leading' > whitespace
setfacl -b ' leading'
status=0
setfacl --restore=whitespace >white.out 2>white.err || status=$?
if [ "$version" = 2.4.0 ]; then
    test "$status" = 0
    getfacl -n ' leading' > white-after
    cmp whitespace white-after
else
    test "$status" != 0
    grep -q 'No such file or directory' white.err
    ! getfacl -n ' leading' | grep -q 'user:12345:'
    echo "HISTORICAL $version: leading-whitespace restore loses filename whitespace (2.4.0 control passes)"
fi
mkdir physical
cp file physical/target
ln -s target physical/link
getfacl -RP -n physical > physical-backup
getfacl -RL -n physical > logical-backup
if [ "$version" = 2.4.0 ]; then
    setfacl --restore=physical-backup --physical >physical.out 2>physical.err
    test ! -s physical.err
    setfacl --restore=physical-backup >unsafe.out 2>unsafe.err
    grep -q 'unsafe without option -P' unsafe.err
    if setfacl --restore=logical-backup --physical >logical.out 2>logical.err; then
        echo 'physical restore unexpectedly traversed symlink'; exit 1
    fi
    grep -q 'Too many levels of symbolic links' logical.err
    # Intermediate directory symlinks must also be refused.
    ln -s physical through
    getfacl -n physical/target | sed 's|physical/target|through/target|' > traversal
    chmod 600 physical/target
    getfacl -n physical/target > traversal-before
    if setfacl --restore=traversal --physical >traversal.out 2>traversal.err; then
        echo 'physical restore unexpectedly traversed directory symlink'; exit 1
    fi
    grep -Eq 'Too many levels of symbolic links|Not a directory' traversal.err
    getfacl -n physical/target > traversal-after
    cmp traversal-before traversal-after
else
    setfacl --restore=logical-backup >logical.out 2>logical.err
    test ! -s logical.err
    echo "HISTORICAL $version: restore follows backup symlinks without the 2.4.0 unsafe-restore warning"
fi
echo "PASS cli $version: restore/copy/inheritance, malformed rejection/numeric controls, dry run, historical controls"

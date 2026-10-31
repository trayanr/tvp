{
  pkgs,
  package,
  helpers,
}:
let
  inherit (package.tvp.deps) acl attr;
in
{
  upstream-fixtures = import ./tracker.nix { inherit pkgs; };
  archive-semantics = pkgs.runCommand "gnutar-${package.version}-archive-semantics" { } ''
    set -euo pipefail
    mkdir -p "$out"
    export RESULTS="$out" TAR=${package}/bin/tar VERSION=${package.version}
    bash ${./roundtrip.sh} 2>&1 | tee "$out/results.log"
    # Assertions inspect the original traversal and numeric PAX header first.
    # Persist the member set and header shape independently of readdir/PIDs;
    # the unmodified observations remain in the build log above.
    for listing in "$out/gnu.list" "$out/ustar.list" "$out/pax.list"; do
      LC_ALL=C sort "$listing" -o "$listing"
    done
    sed -E -i 's@(PaxHeaders\.)[0-9]+/@\1<pid>/@g' \
      "$out/pax-no.header" "$out/pax-yes.header" "$out/results.log"
  '';
  compression-helpers = pkgs.runCommand "gnutar-${package.version}-compression-helpers" { } ''
    set -euo pipefail
    mkdir -p "$out" wrappers src dest
    export HELPER_LOG="$out/helpers.log"
    ${pkgs.lib.concatMapStringsSep "\n" (helper: ''
        cat > wrappers/${helper.bin} <<'WRAPPER'
      #!${pkgs.runtimeShell}
      echo '${helper.bin}' >> "$HELPER_LOG"
      exec ${helper.package}/bin/${helper.bin} "$@"
      WRAPPER
        chmod +x wrappers/${helper.bin}
    '') helpers}
    export PATH="$PWD/wrappers:$PATH"
    printf preserved > src/file
    ${pkgs.lib.concatMapStringsSep "\n" (helper: ''
      ${package}/bin/tar ${helper.flag} -cf archive -C src file
      ${package}/bin/tar ${helper.flag} -xf archive -C dest
      cmp src/file dest/file
      test "$(grep -cx '${helper.bin}' "$HELPER_LOG")" -ge 2
      echo 'PASS ${helper.bin}: explicit owned helper executed for create/extract' | tee -a "$out/results.log"
    '') helpers}
  '';
  native-metadata =
    pkgs.runCommand "gnutar-${package.version}-native-metadata"
      {
        nativeBuildInputs = [ package.stdenv.cc ];
      }
      ''
        set -euo pipefail
        mkdir -p "$out" src dest
        cc ${./features.c} -I${acl}/include -L${acl}/lib -Wl,-rpath,${acl}/lib -lacl -o probe
        printf preserved > src/file
        for feature in acl xattr; do
          rc=0
          ./probe set "$feature" src/file > "$out/$feature.log" 2>&1 || rc=$?
          case "$rc" in
            0)
              rm -f dest/file
              ${package}/bin/tar --acls --xattrs -cf archive -C src file >> "$out/$feature.log" 2>&1
              ${package}/bin/tar --acls --xattrs -xf archive -C dest >> "$out/$feature.log" 2>&1
              cmp src/file dest/file
              ./probe get "$feature" dest/file >> "$out/$feature.log" 2>&1
              echo "PASS $feature roundtrip" | tee -a "$out/results.log"
              ;;
            77) echo "SKIP $feature: filesystem/kernel unsupported (see errno log)" | tee -a "$out/results.log" ;;
            *) cat "$out/$feature.log" >&2; exit "$rc" ;;
          esac
        done
        ${package.stdenv.cc.bintools}/bin/readelf -d ${package}/bin/tar > "$out/dynamic.txt"
        grep -F '${acl}/lib' "$out/dynamic.txt"

        grep -F 'libacl.so' "$out/dynamic.txt"
        # On this base getxattr/setxattr are supplied by libc; libattr is
        # a declared build input, not a runtime dependency of tar.
        printf '%s\n' 'acl=${acl}' 'attr=${attr}' > "$out/declared-inputs.txt"
        grep -F 'libc.so' "$out/dynamic.txt"
        cp probe "$out/probe"
      '';
}

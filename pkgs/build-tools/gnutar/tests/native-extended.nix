{
  pkgs,
  tvpLib,
  package,
  helpers,
}:
let
  inherit (package.tvp.deps) acl attr;
  commonTools = package.specification.environment.tools ++ [
    package.tvp.declaredDependencies.binutils
  ];
  recorded =
    name: tools: libraries: script:
    (import ../../../../lib/tests/recorded.nix) {
      inherit
        package
        name
        script
        libraries
        ;
      tools = commonTools ++ tools;
    };
in
{
  upstream-fixtures = import ./native-tracker.nix { inherit pkgs package; };
  archive-semantics = recorded "archive-semantics" [ ] [ ] ''
    set -euo pipefail
    mkdir -p "$out"
    export RESULTS="$out" TAR=${package}/bin/tar VERSION=${package.version}
    bash ${./roundtrip.sh} 2>&1 | tee "$out/results.log"
    # Assertions inspect the original traversal and numeric PAX header first.
    # Persist the member set and header shape independently of readdir/PIDs;
    # the raw observations remain in the build log before normalization.
    for listing in "$out/gnu.list" "$out/ustar.list" "$out/pax.list"; do
      printf 'Raw archive members (%s):\n' "$listing"
      cat "$listing"
      LC_ALL=C sort "$listing" -o "$listing"
    done
    sed -E -i 's@(PaxHeaders\.)[0-9]+/@\1<pid>/@g' \
      "$out/pax-no.header" "$out/pax-yes.header" "$out/results.log"
  '';
  compression-helpers = recorded "compression-helpers" (map (h: h.package) helpers) [ ] ''
    set -euo pipefail
    mkdir -p "$out" wrappers src dest
    export HELPER_LOG="$out/helpers.log"
    ${pkgs.lib.concatMapStringsSep "\n" (helper: ''
        cat > wrappers/${helper.bin} <<'WRAPPER'
      #!${package.specification.bash}/bin/bash
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
  native-metadata = recorded "native-metadata" [ package.tvp.cc ] [ acl ] ''
    set -euo pipefail
    mkdir -p "$out" src dest
    "$CC" ${./features.c} -I${acl}/include -L${acl}/lib -Wl,-rpath,${acl}/lib -lacl -o probe
    "$CC" ${../../../../lib/tests/filesystem-capabilities.c} -o independent-preflight
    printf preserved > src/file
    for feature in acl xattr; do
      rc=0
      capability=xattrs
      if test "$feature" = acl; then capability=acls; fi
      ./independent-preflight "$capability" > "$out/$feature-preflight.log" 2>&1 || rc=$?
      case "$rc" in
        0)
          # Once the independent capability succeeds, fixture77 is a failure.
          ./probe set "$feature" src/file > "$out/$feature.log" 2>&1
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
    ${package.tvp.declaredDependencies.binutils}/bin/readelf -d ${package}/bin/tar > "$out/dynamic.txt"
    grep -F '${acl}/lib' "$out/dynamic.txt"

    grep -F 'libacl.so' "$out/dynamic.txt"
    # On this base getxattr/setxattr are supplied by libc; libattr is
    # a declared build input, not a runtime dependency of tar.
    printf '%s\n' 'acl=${acl}' 'attr=${attr}' > "$out/declared-inputs.txt"
    grep -F 'libc.so' "$out/dynamic.txt"
    cp probe "$out/probe"
  '';
}

# Opt-in installed GNU utility contracts; observers are not runtime helpers.
{
  scope,
  gnu,
  floor,
}:
let
  shell = "${gnu.gnu-bash}/bin/bash";
  path = scope.lib.makeBinPath (
    builtins.attrValues floor
    ++ [
      gnu.gnu-bash
      gnu.gnu-binutils
    ]
  );
in
scope.bash.runCommand "tvp-bootstrap-gnu-tool-floor-contracts"
  {
    outputs = [
      "out"
      "evidence"
    ];
    nativeBuildInputs = [ scope.coreutils-musl ];
  }
  ''
      mkdir -p "$out/bin" "$evidence"
      cp ${../lib/tests/filesystem-capabilities.c} preflight.c
      cp ${../pkgs/libraries/attr/tests/fixtures/api.c} attr-api.c
      cp ${../pkgs/libraries/acl/tests/fixtures/acl.c} acl-api.c
      cp ${../pkgs/libraries/acl/tests/fixtures/native.c} acl-native.c
      env -i ${gnu.gnu-gcc}/bin/gcc -O2 preflight.c -o "$out/bin/preflight"
      env -i ${gnu.gnu-gcc}/bin/gcc -O2 -fPIE -pie attr-api.c -I${floor.gnu-attr}/include -L${floor.gnu-attr}/lib -lattr -ldl -o "$out/bin/attr-api"
      env -i ${gnu.gnu-gcc}/bin/gcc -O2 acl-api.c -I${floor.gnu-acl}/include -L${floor.gnu-acl}/lib -lacl -o "$out/bin/acl-api"
      env -i ${gnu.gnu-gcc}/bin/gcc -O2 acl-native.c -I${floor.gnu-acl}/include -L${floor.gnu-acl}/lib -lacl -o "$out/bin/acl-native"
      env -i PATH=${path} LC_ALL=C HOME="$PWD" \
        BASH=${shell} ATTR=${floor.gnu-attr} ACL=${floor.gnu-acl} CORE=${floor.gnu-coreutils} \
        MAKE=${floor.gnu-make} FIND=${floor.gnu-findutils} DIFF=${floor.gnu-diffutils} \
        PROBES="$out/bin" EVIDENCE="$evidence" \
        ${shell} -ex ${./gnu-tool-floor-tests.sh} > "$evidence/contracts.log" 2>&1 || { cat "$evidence/contracts.log"; exit 1; }
      ${scope.build-python}/bin/python3 -B ${./gnu-tool-floor-checks.py} \
      ${floor.gnu-attr.evidence} ${floor.gnu-acl.evidence} ${floor.gnu-coreutils.evidence} \
      ${floor.gnu-make.evidence} ${floor.gnu-findutils.evidence} ${floor.gnu-diffutils.evidence} \
      > "$evidence/upstream-classification.json"
    cat "$evidence/contracts.log"
  ''

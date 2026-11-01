{
  pkgs,
  tvp,
  ownedCLI,
  testDeps,
}:
let
  inherit (tvp) lib;
  old = "8519d0400a0369a8ddfafa18f98a1225e0fee6ea";
  new = "cfb871f11ca374c33ac500e692ce095548cb4a33";
  upstream = {
    type = "git-head";
    url = "./upstream";
    ref = "refs/heads/master";
    revisions."2026-05-17" = old;
  };
  cli = pkgs.callPackage ../../upstream.nix {
    inherit ownedCLI;
    inherit (tvp.packages)
      coreutils
      curl
      git
      gnugrep
      gnused
      ;
    tvpLib = lib;
    packages.fixture_2026_05_17 = {
      pname = "fixture";
      version = "2026-05-17";
      tvp = {
        inherit upstream;
      };
    };
  };
  row = pkgs.writeText "git-head-fixture.json" (
    builtins.toJSON {
      inherit upstream;
      versions = [ "2026-05-17" ];
    }
  );
in
pkgs.runCommand "tvp-upstream-git-head-tests"
  {
    nativeBuildInputs = [
      testDeps.bash
      testDeps.coreutils
      testDeps.git
      testDeps.gnugrep
      testDeps.jq
    ];
  }
  ''
    set -euo pipefail
    source ${../git-head.sh}
    mkdir "$out"
    git init --bare upstream
    # Fixed commit objects avoid clocks, user config, signatures and live hosts.
    git --git-dir=upstream hash-object -w -t tree --stdin < /dev/null
    first=$(git --git-dir=upstream hash-object -w -t commit --stdin <<'EOF'
    tree 4b825dc642cb6eb9a060e54bf8d69288fbee4904
    author Fixture <fixture@example.invalid> 1 +0000
    committer Fixture <fixture@example.invalid> 1 +0000

    fixture one
    EOF
    ) || exit 1
    second=$(git --git-dir=upstream hash-object -w -t commit --stdin <<'EOF'
    tree 4b825dc642cb6eb9a060e54bf8d69288fbee4904
    author Fixture <fixture@example.invalid> 2 +0000
    committer Fixture <fixture@example.invalid> 2 +0000

    fixture two
    EOF
    ) || exit 1
    test "$first" = ${old}
    test "$second" = ${new}
    git --git-dir=upstream update-ref refs/heads/master "$first"
    row=$(cat ${row}) || exit 1
    upstream_git_head "$row" > "$out/packaged-head.json"
    jq -e --arg old "$first" '
      .remoteHead == $old and .headPackaged == true and .missingRevision == null and
      .packagedRevisions == [{version: "2026-05-17", revision: $old}]
    ' "$out/packaged-head.json"
    ${cli}/bin/tvp-upstream fixture > "$out/cli-packaged.log"
    grep -Fx 'fixture — upstream branch head comparison (history not enumerated)' "$out/cli-packaged.log"
    grep -Fx '  head packaged: true' "$out/cli-packaged.log"
    grep -Fx '  missing revision: none' "$out/cli-packaged.log"

    git --git-dir=upstream update-ref refs/heads/master "$second"
    upstream_git_head "$row" > "$out/new-head.json"
    jq -e --arg new "$second" '
      .remoteHead == $new and .headPackaged == false and .missingRevision == $new
    ' "$out/new-head.json"
    ${cli}/bin/tvp-upstream fixture > "$out/cli-new.log"
    grep -Fx '  head packaged: false' "$out/cli-new.log"
    grep -Fx '  missing revision: ${new}' "$out/cli-new.log"
    # A date is a display label. Distinct snapshots remain exact revisions.
    both=$(jq --arg new "$second" '
      .versions += ["2026-05-18"] | .upstream.revisions["2026-05-18"] = $new
    ' <<< "$row") || exit 1
    upstream_git_head "$both" > "$out/two-snapshots.json"
    jq -e '.headPackaged and (.packagedRevisions | length == 2)' "$out/two-snapshots.json"

    reject() {
      local input=$1 label=$2
      if upstream_git_head "$input" > "$out/reject-$label.stdout" 2> "$out/reject-$label.stderr"; then
        echo "unexpected git-head success: $label" >&2
        exit 1
      fi
      test -s "$out/reject-$label.stderr"
    }
    cases=0
    for mutation in \
      'del(.upstream.revisions)' \
      '.upstream.revisions["2026-05-17"] = "8519d04"' \
      '.upstream.revisions["2026-05-17"] = "8519D0400A0369A8DDFAFA18F98A1225E0FEE6EA"' \
      '.upstream.revisions["2026-05-18"] = .upstream.revisions["2026-05-17"]' \
      '.upstream.revisions = {}' \
      '.upstream.revisions = []' \
      '.upstream.ref = "HEAD"' \
      '.upstream.ref = "refs/heads/*"' \
      '.upstream.ref = "refs/heads/missing"' \
      '.upstream.ref = "refs/heads/../bad"' \
      'del(.upstream.ref)' \
      '.upstream.url = "./does-not-exist"' \
      '.upstream.url = "-bad-option"' \
      '.upstream.normalise = "invalid-extra-field"' \
      '.versions = []'; do
      bad=$(jq "$mutation" <<< "$row") || exit 1
      reject "$bad" "case-$((++cases))"
    done

    # Exercise response validation as well as actual local-Git error paths.
    mkdir mock
    cat > mock/git <<'EOF'
    #!${testDeps.bash}/bin/bash
    if test "$1" = check-ref-format; then
      exec ${testDeps.git}/bin/git "$@"
    fi
    cat "$GIT_HEAD_RESPONSE"
    EOF
    chmod +x mock/git
    printf '%s\t%s\n' bad refs/heads/master > malformed
    GIT_HEAD_RESPONSE="$PWD/malformed" PATH="$PWD/mock:$PATH" reject "$row" bad-hash
    printf '%s\t%s\n' ${new} refs/heads/other > malformed
    GIT_HEAD_RESPONSE="$PWD/malformed" PATH="$PWD/mock:$PATH" reject "$row" wrong-ref
    printf '%s\t%s\n%s\t%s\n' ${old} refs/heads/master ${new} refs/heads/master > malformed
    GIT_HEAD_RESPONSE="$PWD/malformed" PATH="$PWD/mock:$PATH" reject "$row" multiple-refs
    : > malformed
    GIT_HEAD_RESPONSE="$PWD/malformed" PATH="$PWD/mock:$PATH" reject "$row" empty-response

    # The CLI itself must retain the failed/incomplete classification.
    git --git-dir=upstream update-ref -d refs/heads/master
    if ${cli}/bin/tvp-upstream fixture > "$out/cli-missing.log" 2>&1; then
      echo 'CLI incorrectly accepted a missing branch' >&2
      exit 1
    fi
    grep -F 'FAILED: commit head comparison failed' "$out/cli-missing.log"
    grep -F 'report above is incomplete' "$out/cli-missing.log"
    echo 'Local Git head, new revision, metadata, malformed response and failure fixtures passed.' > "$out/status"
  ''

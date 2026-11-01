# Sourced by tvp-upstream. This adapter deliberately compares one branch head;
# it neither enumerates history nor invents release versions for an untagged repo.
upstream_git_head() {
  local row=$1 url ref listing head
  if ! jq -e '
    .upstream as $u |
    ($u | type == "object") and
    ($u | keys == ["ref", "revisions", "type", "url"]) and
    ($u.type == "git-head") and
    ($u.url | type == "string" and length > 0 and (startswith("-") | not)) and
    ($u.ref | type == "string" and startswith("refs/heads/")) and
    ($u.revisions | type == "object" and length > 0) and
    (.versions | type == "array" and length > 0 and all(.[]; type == "string")) and
    ((.versions | sort) == ($u.revisions | keys)) and
    ($u.revisions | all(.[]; type == "string" and test("^[0-9a-f]{40}$")))
  ' <<< "$row" > /dev/null; then
    echo 'tvp-upstream: invalid git-head metadata (expected one full revision per packaged version and an explicit branch ref)' >&2
    return 1
  fi
  url=$(jq -r '.upstream.url' <<< "$row") || return 1
  ref=$(jq -r '.upstream.ref' <<< "$row") || return 1
  if ! git check-ref-format "$ref"; then
    echo 'tvp-upstream: invalid git-head branch ref' >&2
    return 1
  fi
  # Bound both network and noninteractive credential failures. This explicit
  # command is the sole network operation; Nix evaluation never asks Git.
  if ! listing=$(GIT_TERMINAL_PROMPT=0 timeout --signal=TERM --kill-after=5 45 \
    git -c credential.helper= -c core.askPass= ls-remote --exit-code --refs -- "$url" "$ref"); then
    echo 'tvp-upstream: git-head lookup failed or branch ref is missing' >&2
    return 1
  fi
  if ! head=$(jq -enr --arg listing "$listing" --arg ref "$ref" '
    $listing | split("\n") |
    if length != 1 then error("expected exactly one remote ref") else .[0] end |
    split("\t") |
    if length == 2 and .[1] == $ref and (.[0] | test("^[0-9a-f]{40}$"))
    then .[0] else error("malformed remote ref") end
  '); then
    echo 'tvp-upstream: malformed git-head response' >&2
    return 1
  fi
  jq --arg head "$head" '{
    type: "git-head",
    source: .upstream.url,
    ref: .upstream.ref,
    remoteHead: $head,
    packagedRevisions: (.upstream.revisions | to_entries | map({version: .key, revision: .value})),
    headPackaged: (.upstream.revisions | any(.[]; . == $head)),
    missingRevision: (if (.upstream.revisions | any(.[]; . == $head)) then null else $head end)
  }' <<< "$row" || return 1
}

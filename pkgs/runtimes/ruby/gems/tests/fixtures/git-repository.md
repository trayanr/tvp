This small bare repository contains the synthetic `fixtures/git` sources plus
`.gitattributes` marking `dist/widget.js` as `export-ignore`. It verifies that
manifest Git fetching preserves the complete checkout instead of Git archive
filtering. Its two gemspecs exercise one fetch shared by multiple gems.

The fixture uses the commit message `Fixture`, author and committer
`TVP fixture <fixture@example.invalid>`, and timestamp `2000-01-01T00:00:00Z`.
The revision and recursive SHA-256 are recorded in `automatic-git.nix`.
Only a pack, its index, the master ref, HEAD and bare configuration are retained;
there are no hooks, remotes, credentials or Git metadata in the exported source.

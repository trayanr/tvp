# TVP 

This flake/repo is used to contain old packages that have been dropped.
Mainly for dev and build tools.

## Reason
Sometimes just using old packages doesn't work (e.g. Some old versions of ruby are inaccessible since there were change to flakes).
Or just overriding parameters is too difficult.
Or maybe they are difficult to find.
While nowadays you can create a nix flake and lock it so that the version will remain the same, trying to bring an old projects to a flake is difficult.

## Usage

```sh
nix build github:trayanr/tvp#ruby_2_7_0
nix shell github:trayanr/tvp#ruby_2_7_0
```

Use `canonical.ruby_2_7_0` when you require exactly Ruby 2.7.0.
Public full names are fallbacks and can be shadowed by a generated line alias (for
example, `openssl_1_1_1` follows the 1.1.1 letter releases). Aliases (`ruby_2_7`, `ruby_2`,
`ruby`) follow the latest packaged, non-broken release in that line. Pin the TVP commit
in your flake lock to fix the dependencies and build environment too.

To list what is available:

```sh
nix eval --raw github:trayanr/tvp#packages.x86_64-linux \
  --apply 'p: builtins.concatStringsSep "\n" (builtins.attrNames p)'
```

or `nix flake show github:trayanr/tvp` for the full output tree.

To inspect evaluated dependency choices without building the catalogue:

```sh
nix run .#dependencies
nix run .#dependencies -- --json > dependencies.json
nix run .#dependencies -- --kind exact --scope ordinary --details
nix run .#dependencies -- --flake 'github:trayanr/tvp/REVISION' --system x86_64-linux --json
nix run .#dependencies -- --json --compare dependencies.json
```

The report separates per-release edges from shared definition choices, requested
selectors, and resolved releases. Bootstrap construction, matched SDK artifacts,
broken releases, and borrowed infrastructure have separate scopes.

> **Note:** TVP packages end-of-life software. It preserves and tests old versions; it
> does **not** provide security support. Availability is not a statement that something
> is safe to deploy.

## Contributing

[STRUCTURE.md](STRUCTURE.md) describes the repository layout and the conventions a change
is expected to follow — where a package lives, how builders are named and forked, how
version tables and aliases work, and how tests are written.

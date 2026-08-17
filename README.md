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

Every package has a canonical, immutable name (`ruby_2_7_0`) and may also have movable
aliases (`ruby_2_7`, `ruby_2`, `ruby`). Pin the canonical name if you want it to mean the
same thing forever.

To list what is available:

```sh
nix eval --raw github:trayanr/tvp#packages.x86_64-linux \
  --apply 'p: builtins.concatStringsSep "\n" (builtins.attrNames p)'
```

or `nix flake show github:trayanr/tvp` for the full output tree.

> **Note:** TVP packages end-of-life software. It preserves and tests old versions; it
> does **not** provide security support. Availability is not a statement that something
> is safe to deploy.

## Contributing

[STRUCTURE.md](STRUCTURE.md) describes the repository layout and the conventions a change
is expected to follow — where a package lives, how builders are named and forked, how
version tables and aliases work, and how tests are written.

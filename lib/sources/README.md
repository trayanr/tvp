# Package sources and release discovery

Declare downloads and discovery together in the family's `source`. Hashes stay
in its version table. These descriptors are callable source factories; recipes
still receive the selected `src`, and discovery never runs during evaluation or
package builds.

For an archive directory:

```nix
source = tvp.lib.sources.directory {
  url = "https://curl.se/download/";
  archive = "curl-{version}.tar.gz";
};
```

The directory URL ends in `/`. The plain archive filename contains exactly one
`{version}` placeholder. The helper derives both the selected download URL and
the listing parser. Literal filename punctuation is escaped. Release policy is
explicit: add `discovery.include` when prereleases or particular eras should be
excluded. A discovery override can use another listing or parser; selecting a
different discovery type replaces the directory parser.

For downloads and releases hosted separately:

```nix
source = tvp.lib.sources.archive {
  url = version:
    "https://downloads.example.org/project-${version}.tar.xz";
  discovery = {
    type = "git-tags";
    url = "https://git.example.org/project.git";
    prefix = "v";
  };
};
```

`prefix` strips a declared Git tag prefix; use a `normalise` function for more
complex spellings. The discovery types are `directory-index`, `git-tags`,
`git-head`, and `rubygems`, retaining their existing CLI-specific fields. Omit
discovery or set it to `null` when unknown; the upstream report must show that
gap rather than omit the family or claim there are no missing versions.

The default download factory is the existing `<nix/fetchurl.nix>` with exactly
the URL and version-table hash. A source needing other fetch arguments can
provide an explicit `fetch = { version, sha256 }: ...` factory alongside its URL
and discovery. This preserves existing fetch identities and behavior.

The family exports the resolved URL as `package.tvp.source` and its discovery as
`package.tvp.upstream`. An explicit definition-level source takes precedence over
the family source. Legacy function sources and `packageMeta.upstream` remain
readable during transition, but a descriptor's discovery must not also be
declared in `packageMeta.upstream`.

# Private GNU environment checkpoint

`gnu-environment.nix` supplies base **data** and a separately named driver over
exactly the existing GNU raw compiler. It is not a production base or a default.
There is no setup import, hook protocol, package set, or `mkDerivation` here.
`owned-lib.nix` supplies only the pure helpers used by the existing owned builder.

The driver consumes the shared environment encoder's whitespace-free words using
Bash arrays, without evaluating shell syntax. Compile words precede direct argv;
link-driver words apply only when linking; linker words follow direct argv as
separate `-Xlinker` pairs. Direct argv retains spaces and commas. The shared
encoder still rejects whitespace-bearing words and commas in `NIX_LDFLAGS`.
Compile, preprocess and dependency modes omit link-only words; informational
queries omit environment flags. Response files are inspected using the pinned
GCC libiberty quoting rules and forwarded unchanged. Unreadable response files
with environment flags and nesting beyond 63 levels fail clearly. This is mode
classification, not a compiler security sandbox.

C/C++ shared, static, PIE and non-PIE probes run against the checkpoint. Static PIE
is rejected: the reduced raw checkpoint produces an executable that crashes at
startup. Alternate ABIs and nonempty hardening requests are also rejected.
`defaultHardeningFlags = []` describes the actual implemented profile.

The shared environment accepts `cc.libcTools` as an explicit tool list, defaulting
to its previous `getBin cc.libc` behavior. This checkpoint declares `[]`: its libc
has headers/libraries, but no executable output. This does not claim libc tools,
locale/conversion coverage, or libc shell APIs.

`gnu-environment-fixtures.nix` calls the actual `lib/builder.nix` factory. A public
B→A development interface supplies headers, link search and runtime search to a
consumer declaring only B. MPFR/GMP overlays reuse exact existing outputs.
Override, specification/environment edits, runtime edits and a step customization
recompute through the existing fixed point. Run these fixtures explicitly with
`nix-build bootstrap/gnu-environment-fixtures.nix -A protocol -A consumer
-A override -A edited -A customized -A mpfrConsumer`.
They are not ordinary catalogue/Server CI dependencies.

The opt-in construction auditor adds a precise owned-runner profile to the
existing strict origin audit. It checks structured prepared input edges and the
exact text-copy builder/helper form before normalization. The owned runner's
existing substitution policy is recorded, not disguised as a new bootstrap
policy. A separate exact GNU runtime profile uses the unchanged strict ELF,
loader, search, symlink and script auditor. Source data never authorizes an
executable. No complete base, compiler generation comparison, full conformance,
reproducibility, fixed-point build or default readiness claim follows.

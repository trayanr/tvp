# Public python-build profile

`default.nix` uses a literal release/recipe record and implicit `mkFamily` wiring.
`build.nix` is the complete public profile, with its unchanged disabled-module and
configure/install contracts. Standard tools are effective-base roles. Actual
libraries and File/pkg-config choices remain explicit package dependencies.

`tests/installed.nix` uses the shared public Python reduced-profile assertion
factory. Test fixtures/expected results and profile-specific TLS checks are retained.
`tests/customization.nix` observes grouped features and base shell edits.

`retained.nix` is the byte-identical old historical factory. The original root
`build-3.12.5.nix`, old installed test factory and all direct bootstrap providers
remain in place. This public authoring conversion does not activate a different
construction Python generation. See `../python/README.md` for scope and limits.

# Ruby 2.6's MJIT header command omits the configured CFLAGS. Forward them as
# the 2.7 build procedure does; keep the transformer and all strict checks intact.
{ lib, fetchurl, ... }@args:
(import ./build-2.2.nix args).overrideAttrs (old: {
  postPatch =
    (old.postPatch or "")
    + ''
      substituteInPlace common.mk --replace-fail \
        'transform_mjit_header.rb "$(CC) $(ARCH_FLAG)"' \
        'transform_mjit_header.rb "$(CC) $(ARCH_FLAG) $(CFLAGS)"'
    '';
})

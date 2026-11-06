# Select retained producers by role. These tools keep their measured host
# generations; selecting the full target compiler does not rebuild the tools.
{ bootstrap }:
let
  full = import ../../bootstrap/source-full-gcc.nix { inherit bootstrap; };
  native = import ../../bootstrap/source-native-compiler.nix { inherit bootstrap; };
  cmake = import ../../bootstrap/source-cmake.nix { inherit bootstrap; };
  pythonMeson = import ../../bootstrap/source-python-meson.nix { inherit bootstrap; };
  prerequisites = import ../../bootstrap/source-full-gcc-prerequisites.nix { inherit bootstrap; };
  lib = import ../../bootstrap/owned-lib.nix { system = "x86_64-linux"; };
  # This selected GNU linker owns indirect-DSO lookup. Generic composition knows
  # neither GNU ld policy nor a library-scanning flag convention.
  linker = native.binutils // {
    buildEnvironment =
      context:
      let
        existing = (native.binutils.buildEnvironment or (_: { })) context;
        flags = existing.flags or { };
      in
      existing
      // {
        flags = flags // {
          NIX_LDFLAGS =
            (flags.NIX_LDFLAGS or [ ])
            ++ lib.concatMap (
              library:
              lib.concatMap (directory: [
                "-rpath-link"
                directory
              ]) (context.directories library).libraries
            ) context.libraries;
        };
      };
  };
in
{
  # Definition/reference ownership only. These are the selected target providers
  # and the older source-built generations their installed interfaces reference.
  # This list grants no executable permission; native origin/runtime audits remain
  # separate, with explicit target roles.
  referencePackages = [
    full.compiler
    full.driver
    native.profile.libc
    native.profile.libgcc
    native.profile.libstdcxx
    native.gmp
    native.mpfr
    native.mpc
    full.compiler.tvp.deps.isl
    full.compiler.tvp.deps.libxcrypt
    prerequisites.zlib
    prerequisites.zstd
    native.prior.prerequisites.xz
    bootstrap.linux-headers
    bootstrap.gnu-libc
    bootstrap.gnu-libgcc
    bootstrap.gnu-libstdcxx
    bootstrap.gnu-bash
    bootstrap.gnu-gmp
    bootstrap.gnu-tool-floor.gnu-attr
    bootstrap.gnu-tool-floor.gnu-acl
    bootstrap.gnu-tool-floor.gnu-coreutils
    bootstrap.gnu-binutils
    bootstrap.musl
    bootstrap.gnused
  ];
  toolchain = {
    compiler = full.compiler;
    driver = full.driver;
    libc = native.profile.libc;
    binutils = native.binutils;
    runtime = full.compiler;
  };
  tools = prerequisites.tools // {
    inherit linker;
    inherit (cmake) cmake;
    inherit (pythonMeson) python meson;
    inherit (pythonMeson.tools) ninja pkgConfig;
    m4 = bootstrap.build-m4;
    bzip2 = bootstrap.bzip2;
    inherit (prerequisites) perl texinfo;
  };
}

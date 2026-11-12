# 1.0.0: make depend; domd compiler-name compatibility: COMPLETE independent native procedure; source distinctions are definition data.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  pkgConfig,
  gnumake,
  gnutar,
  gzip,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  python,
  binutils,
  patchelf,
  buildPerl,
  perl,
  doCheck ? true,
  cStandard ? null,
  compileFlags ? [ ],
  hardeningDisable ? [ ],
  forceGccName ? false,
  installTarget ? "install_sw",
  features,
  sourceEncoding ? "latin-1",
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "openssl.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j1 SHELL=${final.bash}/bin/bash'';
in
{
  pname = "openssl";
  # Keep compiled self strings, suffix pooling and stored lengths unchanged.
  artifactName = "${final.pname}-${final.version}";
  # Rebind both consumer adapters from the effective recipe option. The base
  # carries the selected underlying toolchain; it is never replaced by a global
  # compiler or a peer package procedure.
  base =
    if base.compiler ? hardeningPolicy then
      let
        policy = base.compiler.specification.policy // {
          disable = final.hardeningDisable;
        };
        bintools = base.compiler.bintools.override { inherit policy; };
        compiler = base.compiler.override { inherit policy bintools; };
      in
      base.override { inherit compiler; }
    else
      base;

  inherit
    src
    version
    bash
    coreutils
    pkgConfig
    gnumake
    gnutar
    gzip
    findutils
    sed
    grep
    gawk
    diffutils
    python
    binutils
    patchelf
    buildPerl
    perl
    doCheck
    cStandard
    compileFlags
    hardeningDisable
    forceGccName
    installTarget
    features
    sourceEncoding
    ;
  sourceHelper = ./source.py;
  finalHelper = ./output.py;
  archiveHelper = ./archive.py;
  elfHelper = ./elf.py;
  # Shared pure tree/text inspection owns no family mutations or recipe.
  inspectionHelper = ../../../../lib/installed-tree.py;
  configureFlags = [
    "shared"
    "--openssldir=etc/ssl"
  ] ++ [ ] ++ lib.optional (final.cStandard != null) "-std=${final.cStandard}" ++ final.compileFlags;
  environment = {
    tools = [
      final.coreutils
      final.buildPerl
      final.pkgConfig
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.python
    ];
    libraries = [ ];
  };
  dependencyProviders = {
    perl = final.runtime.perl;
  };
  runtime = {
    libraries = [ ];
    perl = final.perl;
    shell = final.bash;
    tools = [
      final.coreutils
      final.sed
      final.grep
      final.gawk
      final.findutils
    ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      inherit (final) gzip findutils;
      compression = "gzip";
    })
    (command "prepare" ''
      ${final.python}/bin/python3 -B ${final.sourceHelper} ${final.bash}/bin/bash ${final.buildPerl}/bin/perl ${final.coreutils} ${lib.escapeShellArg final.sourceEncoding}
    '')
    (command "configure" ''
      export PERL=${final.buildPerl}/bin/perl HASHBANGPERL=${final.buildPerl}/bin/perl
      ${lib.optionalString final.forceGccName ''export CC=gcc''}
      export LDFLAGS="''${LDFLAGS:-} -Wl,-rpath,$out/lib"
      ${final.buildPerl}/bin/perl ./Configure linux-x86_64 --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "depend" ''${make} depend'')
    (command "build" make)
    (
      (command "check" ''
        status=0
        ${make} test > "$TVP_SOURCE_ROOT/upstream.raw" 2>&1 || status=$?
        printf '%s\n' "$status" > "$TVP_SOURCE_ROOT/upstream.exit"
        cat "$TVP_SOURCE_ROOT/upstream.raw"
        # Raw execution is before installation/split. No failure classifier or
        # allowlist: nonzero upstream status makes this artifact unqualified.
        test "$status" -eq 0
      '')
      // {
        enabled = final.doCheck;
      }
    )
    (command "install" ''
      ${make} ${lib.escapeShellArg final.installTarget}
      # 0.9.7c chmods the directory rather than its .pc files.
      if test -d "$out/lib/pkgconfig"; then chmod 755 "$out/lib/pkgconfig"; fi
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      ${lib.optionalString final.doCheck ''
        cp "$TVP_SOURCE_ROOT/upstream.raw" "$out/nix-support/upstream.raw"
        cp "$TVP_SOURCE_ROOT/upstream.exit" "$out/nix-support/upstream.exit"
      ''}
    '')
    (steps.split "openssl.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "openssl.relocate";
      tools = [
        final.python
        final.binutils
        final.patchelf
      ];
      run = ''${final.python}/bin/python3 -B ${final.finalHelper} ${final.archiveHelper} ${final.inspectionHelper} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            readelf = "${final.binutils}/bin/readelf";
            patchelf = "${final.patchelf}/bin/patchelf";
            perl = "${final.runtime.perl}/bin/perl";
            buildPerl = "${final.buildPerl}/bin/perl";
            shell = "${final.runtime.shell}/bin/bash";
            tools = map (p: "${p}/bin") final.runtime.tools;
            rehash = final.features.rehash;
          }
        )
      } ${final.elfHelper}'';
    }
    (outputs.strip {
      inherit (final) python binutils;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      inherit (final) python binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      inherit (final)
        python
        binutils
        patchelf
        base
        ;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.development {
      python = final.python;
      libraries = [ ];
    })
    (outputs.checkPaths {
      inherit (final) python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = final.features;
  meta = {
    description = "A cryptographic library that implements the SSL and TLS protocols";
    homepage = "https://www.openssl.org/";
    license = lib.licenses.openssl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "openssl";
  };
}

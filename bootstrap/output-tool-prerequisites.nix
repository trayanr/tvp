# Opt-in qualification only. No package-set import or default/base promotion.
{
  bootstrap ? import ./. { },
}:
let
  b = bootstrap;
  adapter = import ./gnu-environment.nix { inherit bootstrap; };
  inherit (adapter) lib bash coreutils;
  builder = import ../lib/builder.nix { inherit lib; };
  runtimeDirectories = [
    "${b.gnu-libc}/lib"
    "${b.gnu-libgcc}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0"
    "${b.gnu-libstdcxx}/lib"
  ];
  base = adapter.base // {
    inherit runtimeDirectories;
    environment = import ../lib/build-environment.nix { inherit lib base; };
  };
  # Private explicit native BUILD floor. These existing source-owned helpers may
  # execute on musl; none is selected as a target runtime library.
  buildTools = with b; [
    gnumake-musl
    gnused
    build-grep
    gawk
    diffutils
    findutils
  ];
  python = b.build-python;
  fetch = import <nix/fetchurl.nix>;
  sources = builtins.mapAttrs (_: fetch) (
    builtins.fromJSON (builtins.readFile ./output-tool-sources.json)
  );
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "private-output-tool-qualification";
      mkTests = _: { };
    };
  command =
    final: name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
  patchelf = make (
    { }:
    final: {
      pname = "tvp-standalone-patchelf";
      version = "0.19.2";
      src = sources.patchelf;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment.tools = buildTools ++ [
        b.gnu-binutils
        b.gnutar-latest
        b.bzip2
        b.gzip
        python
      ];
      plan = [
        {
          name = "source.unpack";
          tools = [
            b.gnutar-latest
            b.bzip2
          ];
          run = ''
            mkdir source
            PATH=${b.bzip2}/bin:"$PATH" ${b.gnutar-latest}/bin/tar -xjf ${sources.patchelf} --strip-components=1 -C source
            chmod -R u+w source
            mkdir -p "$evidence"
          '';
        }
        (command final "patchelf.prepare" ''
          ${python}/bin/python3 -B ${./gnu-tool-floor-prepare.py} ${bash}/bin/bash
        '')
        (builder.steps.shebangs {
          name = "patchelf.shebangs";
          inherit python;
          paths = [
            "tests"
            "build-aux"
          ];
          names = [
            "sh"
            "bash"
          ];
          interpreter = "${bash}/bin/bash";
        })
        (command final "patchelf.build" ''
          trap 'status=$?; if (( status != 0 )); then cat "$evidence"/*.log; fi' EXIT
          export SHELL=${bash}/bin/bash CONFIG_SHELL=${bash}/bin/bash
          # Link the final interpreter and runtime search paths directly. No older
          # Patchelf, and the resulting executable never has to rewrite itself.
          export LDFLAGS=${
            lib.escapeShellArg (lib.concatMapStringsSep " " (d: "-Wl,-rpath,${d}") runtimeDirectories)
          }
          ./configure --prefix="$out" --disable-dependency-tracking > "$evidence/configure.log" 2>&1
          cp config.log "$evidence/"
          ${b.gnumake-musl}/bin/make -j"$NIX_BUILD_CORES" > "$evidence/build.log" 2>&1
          # Test-only ldd surface: exact owned GNU loader, no system ldd/search.
          mkdir check-tools
          printf '%s\n' '#!${bash}/bin/bash' 'exec ${b.gnu-libc}/lib/ld-linux-x86-64.so.2 --list "$@"' > check-tools/ldd
          chmod +x check-tools/ldd
          export PATH="$PWD/check-tools:$PATH"
          status=0
          ${b.gnumake-musl}/bin/make -j"$NIX_BUILD_CORES" check > "$evidence/check.log" 2>&1 || status=$?
          printf '%s\n' "$status" > "$evidence/check.status"
          ${b.findutils}/bin/find tests -name '*.log' -exec cp --parents '{}' "$evidence" \;
          ${b.findutils}/bin/find tests -name '*.trs' -exec cp --parents '{}' "$evidence" \;
          mv "$evidence/tests" "$evidence/full-suite"
          ${b.gnu-binutils}/bin/readelf -d tests/no-rpath tests/libshared-rpath.so > "$evidence/raw-fixtures.elf"
          ${python}/bin/python3 -B ${./patchelf-checks.py} full \
            "$evidence/full-suite" "$evidence/check.status" "$evidence/raw-fixtures.elf" \
            > "$evidence/full-suite-classification.json"
          # The raw compiler always embeds its owned runtime paths. These two
          # tests require deliberately different fixture RPATHs. Retain the raw
          # full-suite result, then establish precisely their upstream premises.
          ./src/patchelf --remove-rpath tests/no-rpath
          # This fixture has no libc calls: direct owned ld gives the upstream
          # single-string dynstr premise, without editing compiler defaults.
          "$CC" -fPIC -c tests/shared-rpath.c -o shared-rpath.o
          "$LD" -shared shared-rpath.o -rpath a_symbol_name -o tests/libshared-rpath.so
          ${b.gnu-binutils}/bin/readelf -d tests/no-rpath tests/libshared-rpath.so > "$evidence/normalized-fixtures.elf"
          status=0
          ${b.gnumake-musl}/bin/make -C tests check TESTS='no-rpath.sh shared-rpath.sh replace-add-needed.sh' > "$evidence/fixture-recheck.log" 2>&1 || status=$?
          printf '%s\n' "$status" > "$evidence/fixture-recheck.status"
          cat "$evidence/fixture-recheck.log"
          test "$status" = 0
          ${python}/bin/python3 -B ${./patchelf-checks.py} recheck \
            "$evidence/fixture-recheck.log" "$evidence/fixture-recheck.status" tests \
            > "$evidence/fixture-recheck-classification.json"
          ${b.findutils}/bin/find tests -name '*.log' -exec cp --parents '{}' "$evidence" \;
          ${b.gnumake-musl}/bin/make install > "$evidence/install.log" 2>&1
          ${b.gnu-binutils}/bin/strip -S -p "$out/bin/patchelf"
          mkdir -p "$out/share/licenses/patchelf"
          cp COPYING "$out/share/licenses/patchelf/"
          env -i "$out/bin/patchelf" --version > "$evidence/version"
          ${b.gnu-binutils}/bin/readelf -l -d "$out/bin/patchelf" > "$evidence/elf"
          # Operational mutation is on a disposable consumer, never on Patchelf.
          printf '%s\n' 'int main(void) { return 0; }' > probe.c
          "$CC" probe.c -o probe
          "$out/bin/patchelf" --set-rpath ${b.gnu-libc}/lib probe
          test "$("$out/bin/patchelf" --print-rpath probe)" = ${b.gnu-libc}/lib
          test "$("$out/bin/patchelf" --print-interpreter probe)" = ${b.gnu-libc}/lib/ld-linux-x86-64.so.2
          env -i ./probe
        '')
      ];
      meta.license = lib.licenses.gpl3Plus;
    }
  ) { };
  gmp = b.gnu-gmp;
  # MPFR uses the same owned procedure as the catalogue, on the earlier BUILD tier.
  mpfrBase = builder.base {
    name = "source-output-tools-mpfr";
    inherit (base) platform;
    compiler = base.stdenv.cc // {
      inherit runtimeDirectories;
    };
    shell = bash;
    inherit coreutils;
    tools = base.stdenv.initialPath;
    standardTools = {
      gnumake = b.gnumake-musl;
      gnutar = b.gnutar-latest;
      xz = b.xz;
      inherit python patchelf;
      sed = b.gnused;
      grep = b.build-grep;
      gawk = b.gawk;
      diffutils = b.diffutils;
      findutils = b.findutils;
    };
    construction = {
      kind = "stage";
      previous = base.name;
    };
  };
  mpfr = builder {
    recipe = import ../pkgs/libraries/mpfr/build.nix;
    args = {
      tvp = {
        inherit builder;
      };
      inherit lib gmp;
      base = mpfrBase;
      src = sources.mpfr;
      version = "4.2.2";
      sourceScripts = [
        "ar-lib"
        "install-sh"
        "version-ext.sh"
        "compile"
        "missing"
        "config.sub"
        "configure"
        "config.guess"
        "ltmain.sh"
        "depcomp"
        "test-driver"
      ];
    };
    dependencyNames = [ "gmp" ];
    metadata = { };
    selection.kind = "private-output-tool-qualification";
    testContext =
      package: (import ../lib/tests.nix { inherit lib; }).fromPackage { inherit builder package; };
    mkTests =
      package:
      import ../pkgs/libraries/mpfr/tests/default.nix {
        inherit package lib;
        context = package.testContext;
      };
  };
  consumer = make (
    { library }:
    final: {
      pname = "tvp-standalone-mpfr-consumer";
      version = "1";
      src = null;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment.libraries = [ library ];
      plan = [
        (
          (final.base.environment final.environment)
          // {
            name = "consumer.build";
            run = ''
              mkdir -p "$out/bin"
              cp ${./output-tool-consumer.c} consumer.c
              "$CC" -Wl,-t -Wl,-Map,link.map consumer.c -lmpfr -lgmp -o "$out/bin/consumer"
              env -i "$out/bin/consumer"
              # Link/CRT evidence belongs to its own output, so it cannot pull
              # the build compiler into the installed consumer's runtime.
              mkdir -p "$evidence"
              cp link.map "$evidence/"
            '';
          }
        )
      ];
    }
  ) { library = mpfr; };
in
{
  inherit
    patchelf
    mpfr
    consumer
    sources
    ;
  metadata = {
    inherit runtimeDirectories;
    buildTools = map toString (
      buildTools
      ++ [
        python
        b.gnutar-latest
        b.xz
        b.gzip
        b.bzip2
      ]
    );
    target = map toString [
      b.gnu-libc
      b.gnu-libgcc
      b.gnu-libstdcxx
      gmp
    ];
    stages = {
      artifact = mpfr.artifact.drvPath;
      output = mpfr.drvPath;
      consumer = consumer.drvPath;
    };
    developmentLibraries = map toString mpfr.development.libraries;
  };
}

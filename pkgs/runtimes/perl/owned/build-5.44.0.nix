# Native shared Perl. Config and ExtUtils retain the real development tool paths.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
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
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
in
final:
let
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'';
in
{
  pname = "perl";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      inherit src gzip findutils;
      tar = gnutar;
      compression = "gzip";
    })
    (steps.shebangs {
      name = "perl.prepare";
      inherit python;
      paths = [
        "Configure"
        "hints"
      ];
      names = [ "sh" ];
      interpreter = "${bash}/bin/bash";
    })
    {
      name = "perl.test-tools";
      cwd = "source";
      tools = [ python ];
      enabled = doCheck;
      # Pod::Html's fixture changes expect_fail semantics when neither hardcoded
      # host diff path exists. Bind the real declared diff, retaining its tests.
      run = ''
        ${python}/bin/python3 -B - <<'PY'
        from pathlib import Path
        p = Path('ext/Pod-Html/t/lib/Testing.pm')
        text = p.read_text()
        old = "my $diff = '/bin/diff';"
        assert text.count(old) == 1
        p.write_text(text.replace(old, "my $diff = '${diffutils}/bin/diff';"))
        PY
      '';
    }
    (command "perl.configure" ''
      export SHELL=${bash}/bin/bash CONFIG_SHELL=${bash}/bin/bash
      ${bash}/bin/bash ./Configure -des -Dprefix="$out" -Duseshrplib \
        '-Dlocincpth= ' '-Dloclibpth= ' -Dcc="$CC" -Dld="$CC" \
        -Dar="$AR" -Dnm="$NM" -Dranlib="$RANLIB" -Dmake=${gnumake}/bin/make \
        -Dsh=${bash}/bin/bash
    '')
    (command "perl.build" make)
    (
      (command "perl.check" ''TEST_JOBS="$NIX_BUILD_CORES" ${make} test_harness'')
      // {
        enabled = doCheck;
      }
    )
    (command "perl.install" ''${make} install'')
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      # Perl installs libperl read-only. Retain compiler-generated native paths
      # and original library bytes/modes; the bounded observer checks every
      # libperl/core XS ELF directly. Runtime edits rebind the interpreter.
      paths = [ "bin" ];
      libraries = final.runtime.libraries;
    })
  ];
  meta = {
    description = "Native shared Perl interpreter and development interface";
    license = lib.licenses.artistic1;
    platforms = [ "x86_64-linux" ];
    mainProgram = "perl";
  };
}

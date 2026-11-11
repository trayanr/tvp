# 5.30.3–5.34.3: Errno preprocessor fallback; old malloc/free and external pwd probes.
# Source preparation and installed finalization are distinct input files: changing
# runtime metadata cannot invalidate configure/build/check/install.
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
  cStandard,
  doCheck ? true,
  upstreamNonpasses ? [ ],
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "perl.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  sourceContract = {
    shell = "${final.bash}/bin/bash";
    diff = "${final.diffutils}/bin/diff";
    buildPwd = "${final.buildPwd}/bin/pwd";
    podHelper = "ext/Pod-Html/t/pod2html-lib.pl";
    externalPwd = true;
    patches = map (p: {
      file = p.file;
      target = p.target;
    }) final.sourcePatches;
  };
  finalContract = {
    readelf = "${final.binutils}/bin/readelf";
    patchelf = "${final.patchelf}/bin/patchelf";
    externalPwd = true;
    buildPwd = "${final.buildPwd}/bin/pwd";
    runtimePwd = "${final.runtime.pwd}/bin/pwd";
  };
in
{
  pname = "perl";
  inherit
    base
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
    ;
  inherit cStandard;
  buildPwd = coreutils;
  sourcePatches = [ ];
  prepareHelper = ./prepare.py;
  finalizeHelper = ./elf-finalize.py;
  artifactName = "${final.pname}-${final.version}";
  configureFlags = [
    "-des"
    "-Duseshrplib"
    "-Dlocincpth= "
    "-Dloclibpth= "
  ];
  environment = {
    tools = [
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
    overrides.flags.NIX_CFLAGS_COMPILE = [ "-std=${final.cStandard}" ];
  };
  runtime = {
    libraries = [ ];
    pwd = final.coreutils;
  };
  dependencyProviders.coreutils = final.runtime.pwd;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    (command "prepare" ''
      ${final.python}/bin/python3 -B ${final.prepareHelper} "$PWD" ${lib.escapeShellArg (builtins.toJSON sourceContract)}
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ${final.bash}/bin/bash ./Configure ${lib.escapeShellArgs final.configureFlags} \
        -Dprefix="$out" -Dcc="$CC" -Dld="$CC" -Dar="$AR" -Dnm="$NM" \
        -Dranlib="$RANLIB" -Dmake=make -Dsh=${final.bash}/bin/bash
    '')
    (command "build" make)
    (
      (command "check" ''${final.python}/bin/python3 -B ${final.checkHelper} ${lib.escapeShellArg (builtins.toJSON final.upstreamNonpasses)} ${make} test_harness'')
      // {
        enabled = final.doCheck;
      }
    )
    (command "install" ''${make} install'')
    (steps.split "perl.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "perl.relocate";
      tools = [
        final.python
        final.binutils
        final.patchelf
      ];
      run = ''
        ${final.python}/bin/python3 -B ${final.finalizeHelper} ${lib.escapeShellArg (builtins.toJSON finalContract)} "$out" "$TVP_ARTIFACT_ROOT"
      '';
    }
    (outputs.shebangs {
      python = final.python;
      paths = [ "bin" ];
      names = [
        "perl"
        "perl${final.version}"
      ];
      selfInterpreter = "bin/perl";
    })
    (
      (outputs.shebangs {
        python = final.python;
        paths = [
          "bin"
          "lib"
        ];
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${final.bash}/bin/bash";
      })
      // {
        name = "output.shell-shebangs";
      }
    )
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
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
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    {
      name = "perl.final-checks";
      tools = [ final.python ];
      run = ''
        unset PERL5LIB PERL5OPT PERLLIB
        "$out/bin/perl" -e 'for (@INC) { next if $_ eq "."; die "bad compiled INC: $_" unless index($_, $ARGV[0]."/lib/")==0 && index($_, chr(0))<0 }' "$out"
        "$out/bin/perl" -MConfig -MList::Util=sum -e 'die unless $Config{prefix} eq $ARGV[0]; for(qw(privlib archlib)) { die unless index($Config{$_},$ARGV[0]."/lib/")==0 } die unless sum(1,2,39)==42' "$out"
        ${final.python}/bin/python3 -B ${final.finalizeHelper} audit "$out" "[\"$TVP_ARTIFACT_ROOT\"]"
      '';
    }
  ];
  inherit doCheck upstreamNonpasses;
  checkHelper = ./check.py;
  tvp.features = {
    shared = true;
    xs = true;
    globImportable = false;
    externalPwdFallback = true;
    legacyCompilerProbes = false;
  };
  meta = {
    description = "Shared Perl interpreter with installed core, XS and embedding interfaces";
    homepage = "https://www.perl.org/";
    license = lib.licenses.artistic1;
    platforms = [ "x86_64-linux" ];
    mainProgram = "perl";
  };
}

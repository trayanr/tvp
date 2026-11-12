# Ordinary native 3.6.3 only: independent 3.x engine/c_rehash ordinary profile with shared AND static libraries.
# Earlier releases and source-bootstrap generations retain independent procedures.
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
  pythonCommand =
    name: run:
    (final.base.environment (final.environment // { tools = final.environment.tools ++ [ python ]; }))
    // {
      name = "openssl.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${gnumake}/bin/make -j1 SHELL=${final.bash}/bin/bash'';
  selectProductionGenerated = ''
    productionGenerated=$(
      ${buildPerl}/bin/perl -I. -Mconfigdata -e '
        my $mandatory = $configdata::unified_info{depends}->{""};
        die "Missing mandatory generation set\n" unless ref($mandatory) eq "ARRAY";
        print join " ", grep { !m{\A(?:test|fuzz)/} } @$mandatory;
      '
    )
  '';
  productionMake =
    make
    + " 'LIBS=$(INSTALL_LIBS)' 'SHLIBS=$(INSTALL_SHLIBS)'"
    + " 'PROGRAMS=$(INSTALL_PROGRAMS)' 'ENGINES=$(INSTALL_ENGINES)'"
    + " 'MODULES=$(INSTALL_MODULES) $(INSTALL_ENGINES)'"
    + " \"GENERATED_MANDATORY=$productionGenerated\"";
in
{
  pname = "openssl";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      buildPerl
      pkgConfig
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    libraries = [ ];
  };
  runtime = {
    shell = final.bash;
    libraries = [ ];
    perl = perl;
  };
  artifactPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.shebangs {
      name = "openssl.prepare-perl";
      inherit python;
      paths = [
        "Configure"
        "util"
      ];
      names = [ "perl" ];
      interpreter = "${buildPerl}/bin/perl";
    })
    (steps.shebangs {
      name = "openssl.prepare-shells";
      inherit python;
      paths = [
        "util"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (pythonCommand "diagnostic-compiler" ''
      ${python}/bin/python3 -B - <<'PYTHON'
      from pathlib import Path
      p = Path('util/mkbuildinf.pl')
      text = p.read_text()
      old = "my $cflags = join(' ', @ARGV);"
      assert text.count(old) == 1
      new = old + "\n$cflags =~ s{^\\Q$ENV{CC}\\E(?=\\s|$)}{do { my $cc = $ENV{CC}; $cc =~ s{.*/}{}; $cc }}e;"
      p.write_text(text.replace(old, new))
      PYTHON
    '')
    (command "configure" ''
      export LDFLAGS="''${LDFLAGS:-} -Wl,-rpath,$out/lib"
      export PERL=${buildPerl}/bin/perl HASHBANGPERL=${buildPerl}/bin/perl
      ${buildPerl}/bin/perl ./Configure linux-x86_64 shared --prefix="$out" --libdir=lib --openssldir=etc/ssl
    '')
    (command "build" ''
      ${selectProductionGenerated}
      ${productionMake} build_sw
    '')
    (command "install" ''
      ${selectProductionGenerated}
      ${productionMake} install_sw
    '')
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
  ];
  artifactName = "${final.pname}-${final.version}";
  finalizeHelper = ./../ordinary/output.py;
  inherit doCheck;
  upstreamPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.shebangs {
      name = "openssl.prepare-perl";
      inherit python;
      paths = [
        "Configure"
        "util"
        "test"
      ];
      names = [ "perl" ];
      interpreter = "${buildPerl}/bin/perl";
    })
    (steps.shebangs {
      name = "openssl.prepare-shells";
      inherit python;
      paths = [
        "util"
        "test"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (pythonCommand "diagnostic-compiler" ''
      ${python}/bin/python3 -B - <<'PYTHON'
      from pathlib import Path
      p = Path('util/mkbuildinf.pl')
      text = p.read_text()
      old = "my $cflags = join(' ', @ARGV);"
      assert text.count(old) == 1
      new = old + "\n$cflags =~ s{^\\Q$ENV{CC}\\E(?=\\s|$)}{do { my $cc = $ENV{CC}; $cc =~ s{.*/}{}; $cc }}e;"
      p.write_text(text.replace(old, new))
      PYTHON
    '')
    (command "configure" ''
      export LDFLAGS="''${LDFLAGS:-} -Wl,-rpath,$out/lib"
      export PERL=${buildPerl}/bin/perl HASHBANGPERL=${buildPerl}/bin/perl
      ${buildPerl}/bin/perl ./Configure linux-x86_64 shared --prefix="$out" --libdir=lib --openssldir=etc/ssl
    '')
    (command "build" make)
    (steps.shebangs {
      name = "openssl.generated-shells";
      inherit python;
      paths = [ "util/shlib_wrap.sh" ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
  ];
  upstreamCheck =
    ((command "check" ''${make} test'') // { enabled = final.doCheck; });
  plan = steps.sequence (final.artifactPlan ++ [
    (steps.split "openssl.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "openssl.relocate";
      tools = [ python binutils patchelf ];
      run = ''${python}/bin/python3 -B ${final.finalizeHelper} ${../ordinary/archive.py} ${../../../runtimes/perl/ordinary/elf-finalize.py} "$out" "$TVP_ARTIFACT_ROOT" ${lib.escapeShellArg (builtins.toJSON {
        manual = { };
        readelf = "${binutils}/bin/readelf";
        patchelf = "${patchelf}/bin/patchelf";
        perl = "${final.runtime.perl}/bin/perl";
        buildPerl = "${buildPerl}/bin/perl";
        shell = "${final.runtime.shell}/bin/bash";
        tools = [ ];
        rehash = final.tvp.features.rehash or false;
      })} ${../ordinary/elf.py} ${../ordinary/manuals.py}'';
    }
    (outputs.shebangs {
      inherit python;
      paths = [ "bin/c_rehash" ];
      names = [ "perl" ];
      interpreter = "${final.runtime.perl}/bin/perl";
    })
    (
      (outputs.shebangs {
        inherit python;
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
      inherit python binutils;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
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
      inherit python;
      libraries = [ ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
  ]);
  tvp.features = {
    sha256 = true;
    pbkdf2 = true;
    shared = true;
    static = true;
    providers = true;
    engines = true;
    rehash = true;
  };
  meta = {
    description = "A cryptographic library that implements the SSL and TLS protocols";
    homepage = "https://www.openssl.org/";
    license = lib.licenses.openssl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "openssl";
  };
}

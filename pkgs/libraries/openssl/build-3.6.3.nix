# Ordinary native 3.6.3 only: independent 3.x engine/c_rehash ordinary profile with shared AND static libraries.
# Earlier releases and source-bootstrap generations retain independent procedures.
{
  tvp,
  lib,
  base,
  src,
  version,
  buildPerl,
  perl,
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
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
    (final.base.environment (
      final.environment // { tools = final.environment.tools ++ [ tools.python ]; }
    ))
    // {
      name = "openssl.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${tools.gnumake}/bin/make -j1 SHELL=${tools.bash}/bin/bash'';
  selectProductionGenerated = ''
    productionGenerated=$(
      ${final.buildPerl}/bin/perl -I. -Mconfigdata -e '
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
    ;
  inherit buildPerl perl;
  inherit (tools)
    bash
    coreutils
    python
    gnumake
    ;
  environment = {
    tools = [
      final.buildPerl
      tools.pkg-config
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    shell = tools.bash;
    libraries = [ ];
    perl = final.perl;
  };
  artifactPlan = steps.sequence [
    (steps.unpack {
      src = final.src;

      compression = "gzip";
    })
    (steps.shebangs {
      name = "openssl.prepare-perl";

      paths = [
        "Configure"
        "util"
      ];
      names = [ "perl" ];
      interpreter = "${final.buildPerl}/bin/perl";
    })
    (steps.shebangs {
      name = "openssl.prepare-shells";

      paths = [
        "util"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (pythonCommand "diagnostic-compiler" ''
      ${tools.python}/bin/python3 -B - <<'PYTHON'
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
      export PERL=${final.buildPerl}/bin/perl HASHBANGPERL=${final.buildPerl}/bin/perl
      ${final.buildPerl}/bin/perl ./Configure linux-x86_64 shared --prefix="$out" --libdir=lib --openssldir=etc/ssl
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
  finalizeHelper = ./ordinary/output.py;
  inherit doCheck;
  upstreamPlan = steps.sequence [
    (steps.unpack {
      src = final.src;

      compression = "gzip";
    })
    (steps.shebangs {
      name = "openssl.prepare-perl";

      paths = [
        "Configure"
        "util"
        "test"
      ];
      names = [ "perl" ];
      interpreter = "${final.buildPerl}/bin/perl";
    })
    (steps.shebangs {
      name = "openssl.prepare-shells";

      paths = [
        "util"
        "test"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (pythonCommand "diagnostic-compiler" ''
      ${tools.python}/bin/python3 -B - <<'PYTHON'
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
      export PERL=${final.buildPerl}/bin/perl HASHBANGPERL=${final.buildPerl}/bin/perl
      ${final.buildPerl}/bin/perl ./Configure linux-x86_64 shared --prefix="$out" --libdir=lib --openssldir=etc/ssl
    '')
    (command "build" make)
    (steps.shebangs {
      name = "openssl.generated-shells";

      paths = [ "util/shlib_wrap.sh" ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
  ];
  upstreamCheck = ((command "check" ''${make} test'') // { enabled = final.doCheck; });
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "openssl.finalize")
      (outputs.copyArtifacts { })
      {
        name = "openssl.relocate";
        tools = [
          tools.python
          tools.binutils
          tools.patchelf
        ];
        run = ''${tools.python}/bin/python3 -B ${final.finalizeHelper} ${./ordinary/archive.py} ${../../runtimes/perl/ordinary/elf-finalize.py} "$out" "$TVP_ARTIFACT_ROOT" ${
          lib.escapeShellArg (
            builtins.toJSON {
              manual = { };
              readelf = "${tools.binutils}/bin/readelf";
              patchelf = "${tools.patchelf}/bin/patchelf";
              perl = "${final.runtime.perl}/bin/perl";
              buildPerl = "${final.buildPerl}/bin/perl";
              shell = "${final.runtime.shell}/bin/bash";
              tools = [ ];
              rehash = final.tvp.features.rehash or false;
            }
          )
        } ${./ordinary/elf.py} ${./ordinary/manuals.py}'';
      }
      (outputs.shebangs {

        paths = [ "bin/c_rehash" ];
        names = [ "perl" ];
        interpreter = "${final.runtime.perl}/bin/perl";
      })
      (
        (outputs.shebangs {

          paths = [
            "bin"
            "lib"
          ];
          names = [
            "sh"
            "bash"
          ];
          interpreter = "${tools.bash}/bin/bash";
        })
        // {
          name = "output.shell-shebangs";
        }
      )
      (outputs.strip {

        paths = [
          "bin"
          "lib"
        ];
        elfKinds = [ "runtime" ];
      })
      (outputs.stripArchives {

        paths = [ "lib" ];
      })
      (outputs.rpaths {

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

        libraries = [ ];
      })
      (outputs.checkPaths {

        paths = [
          "bin"
          "lib"
        ];
        elfKinds = [ "runtime" ];
      })
    ]
  );
  buildFeatures = {
    shared = true;
    static = true;
  };
  installedInterface = {
    sha256 = true;
    pbkdf2 = true;
    providers = true;
    engines = true;
    rehash = true;
  };
  tvp.features = {
    inherit (final.buildFeatures) shared static;
  } // final.installedInterface;
  meta = {
    description = "A cryptographic library that implements the SSL and TLS protocols";
    homepage = "https://www.openssl.org/";
    license = lib.licenses.openssl;
    platforms = [ "x86_64-linux" ];
    mainProgram = "openssl";
  };
}

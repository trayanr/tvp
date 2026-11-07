# Ordinary native 4.0.1 only: independent 4.x provider-only ordinary profile with shared AND static libraries.
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
  make = ''${gnumake}/bin/make -j1 SHELL=${final.bash}/bin/bash'';
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
  runtime.libraries = [ ];
  plan = steps.sequence [
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
    (command "diagnostic-compiler" ''
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
    ((command "check" ''${make} test'') // { enabled = doCheck; })
    (command "install" ''${make} install_sw'')
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
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
  ];
  tvp.features = {
    sha256 = true;
    pbkdf2 = true;
    shared = true;
    static = true;
    providers = true;
    engines = false;
    rehash = false;
  };
  meta.platforms = [ "x86_64-linux" ];
}

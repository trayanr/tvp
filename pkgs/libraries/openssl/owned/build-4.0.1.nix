# Native prefix-sensitive OpenSSL; Perl is a build tool only. Retain serial make.
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
  perl,
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
  make = ''${gnumake}/bin/make -j1 SHELL=${bash}/bin/bash'';
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
      perl
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    libraries = [ ];
    overrides.values = {
      PERL = "${perl}/bin/perl";
      HASHBANGPERL = "${perl}/bin/perl";
    };
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      inherit src gzip findutils;
      tar = gnutar;
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
      interpreter = "${perl}/bin/perl";
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
      interpreter = "${bash}/bin/bash";
    })
    {
      name = "openssl.diagnostic-compiler";
      cwd = "source";
      tools = [ python ];
      # buildinf is a human diagnostic, not an executable development interface.
      # Keep flags, but report the compiler's basename rather than retaining the
      # entire compiler closure in libcrypto. Real commands remain in raw logs.
      run = ''
        ${python}/bin/python3 -B - <<'PY'
        from pathlib import Path
        p = Path('util/mkbuildinf.pl')
        text = p.read_text()
        old = "my $cflags = join(' ', @ARGV);"
        assert text.count(old) == 1
        new = old + "\n$cflags =~ s{^\\Q$ENV{CC}\\E(?=\\s|$)}{do { my $cc = $ENV{CC}; $cc =~ s{.*/}{}; $cc }}e;"
        p.write_text(text.replace(old, new))
        PY
      '';
    }
    (command "openssl.configure" ''
      # Upstream's in-tree wrapper supplies library lookup during tests. Link
      # installed programs/DSOs against their own final prefix as well.
      export LDFLAGS="''${LDFLAGS:-} -Wl,-rpath,$out/lib"
      ${perl}/bin/perl ./Configure linux-x86_64 shared --prefix="$out" --libdir=lib --openssldir=etc/ssl
    '')
    (command "openssl.build" make)
    (steps.shebangs {
      name = "openssl.generated-shells";
      inherit python;
      paths = [ "util/shlib_wrap.sh" ];
      names = [ "sh" ];
      interpreter = "${bash}/bin/bash";
    })
    ((command "openssl.check" ''${make} test'') // { enabled = doCheck; })
    (command "openssl.install" ''${make} install_sw'')
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = [
        "bin"
        "lib"
      ];
      libraries = final.runtime.libraries;
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
  ];
  meta = {
    description = "OpenSSL shared TLS and cryptography libraries";
    license = "Apache-2.0";
    platforms = [ "x86_64-linux" ];
    mainProgram = "openssl";
  };
}

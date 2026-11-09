# Ordinary source Git; Rust/Cargo remain the explicitly selected binary components.
{
  lib,
  tvp,
  base,
  src,
  version,
  bash,
  coreutils,
  helperPython,
  rustc,
  cargo,
  pkg-config,
  perl,
  python,
  curl,
  openssl,
  zlib,
  expat,
  pcre2,
  gnumake,
  gnutar,
  xz,
  findutils,
  diffutils,
  gawk,
  gnused,
  gnugrep,
  binutils,
  patchelf,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      name = "git.${name}";
      cwd = "source";
      run = ''
        export CARGO_HOME="$TVP_SOURCE_ROOT/cargo-home" CARGO_NET_OFFLINE=true
        # Cargo's target linker uses the selected GNU driver; RUSTFLAGS and caller
        # compile/link flags are preserved, including native cc-rs build scripts.
        export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="$CC"
        export CONFIG_SHELL=${final.bash}/bin/bash
        ${run}
      '';
    };
  make = ''
    ${gnumake}/bin/make -j"$NIX_BUILD_CORES" prefix="$out" \
        SHELL=${final.bash}/bin/bash SHELL_PATH=${final.runtime.shell}/bin/bash \
        PERL_PATH=${final.runtime.perl}/bin/perl PYTHON_PATH=${final.runtime.python}/bin/python3 \
        CURL_CONFIG=${curl}/bin/curl-config NO_GETTEXT=YesPlease NO_TCLTK=YesPlease USE_LIBPCRE2=YesPlease'';
  paths = [
    "bin"
    "libexec"
  ];
in
{
  pname = "git";
  inherit
    base
    src
    version
    bash
    coreutils
    helperPython
    gawk
    gnugrep
    ;
  environment = {
    tools = [
      coreutils
      gnumake
      gnutar
      xz
      rustc
      cargo
      pkg-config
      perl
      python
      curl
      findutils
      diffutils
      gawk
      gnused
      gnugrep
    ];
    libraries = [
      curl
      openssl
      zlib
      expat
      pcre2
    ];
  };
  runtime = {
    libraries = environment.libraries;
    shell = bash;
    inherit perl python;
  };
  tvp.features = {
    http = true;
    pcre2 = true;
    gui = false;
    gettext = false;
    manpages = false;
    bundledSshClient = false;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit xz findutils;
    })
    (steps.shebangs {
      name = "git.test-shells";
      python = helperPython;
      paths = [ "t" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "configure" ''
      ${final.bash}/bin/bash ./configure --prefix="$out" \
        --with-curl=${curl} --with-openssl=${openssl} --with-expat=${expat} --with-zlib=${zlib}
    '')
    (command "build" ''${make}'')
    (
      (command "check" ''
        cd t
        # t0001 setgid fixture is sandbox-excluded; only prior host evidence exists.
        ${final.bash}/bin/bash t0000-basic.sh --verbose-log
        ${final.bash}/bin/bash t0008-ignores.sh --verbose-log
        ${final.bash}/bin/bash t1300-config.sh --verbose-log
      '')
      // {
        enabled = doCheck;
      }
    )
    (command "install" ''${make} install'')
    (
      (outputs.shebangs {
        python = helperPython;
        inherit paths;
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${final.runtime.shell}/bin/bash";
      })
      // {
        name = "git.shells";
      }
    )
    (
      (outputs.shebangs {
        python = helperPython;
        inherit paths;
        names = [ "perl" ];
        interpreter = "${final.runtime.perl}/bin/perl";
      })
      // {
        name = "git.perl";
      }
    )
    (
      (outputs.shebangs {
        python = helperPython;
        inherit paths;
        names = [
          "python"
          "python3"
        ];
        interpreter = "${final.runtime.python}/bin/python3";
      })
      // {
        name = "git.python";
      }
    )
    (outputs.strip {
      python = helperPython;
      inherit binutils paths;
    })
    (outputs.rpaths {
      python = helperPython;
      inherit binutils patchelf paths;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.checkPaths {
      python = helperPython;
      inherit binutils patchelf paths;
    })
  ];
  meta = {
    description = "Git version control system with owned HTTP transport and PCRE2";
    homepage = "https://git-scm.com/";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "git";
  };
}

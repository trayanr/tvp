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
}@args:
final:
let
  inherit (final)
    base
    src
    version
    bash
    coreutils
    helperPython
    rustc
    cargo
    pkg-config
    perl
    python
    curl
    openssl
    zlib
    expat
    pcre2
    gnumake
    gnutar
    xz
    findutils
    diffutils
    gawk
    gnused
    gnugrep
    binutils
    patchelf
    doCheck
    ;
  inherit (tvp.builder) steps outputs;
  configurePrefix = if builtins.isString final.configurePrefix && !(builtins.hasContext final.configurePrefix) && builtins.match "/tvp/[A-Za-z0-9][A-Za-z0-9_+./-]*" final.configurePrefix != null && !(builtins.elem ".." (lib.splitString "/" final.configurePrefix)) then final.configurePrefix else throw "Git configurePrefix must be a context-free /tvp path";
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
    ${gnumake}/bin/make -j"$NIX_BUILD_CORES" prefix=${lib.escapeShellArg configurePrefix} RUNTIME_PREFIX=YesPlease \
        SHELL=${final.bash}/bin/bash SHELL_PATH=${final.bash}/bin/bash \
        PERL_PATH=${final.perl}/bin/perl PYTHON_PATH=${final.python}/bin/python3 \
        CURL_CONFIG=${curl}/bin/curl-config NO_GETTEXT=YesPlease NO_TCLTK=YesPlease USE_LIBPCRE2=YesPlease'';
  paths = [
    "bin"
    "libexec"
  ];
in
{
  pname = "git";
  inherit (args)
    base
    src
    version
    bash
    coreutils
    helperPython
    rustc
    cargo
    pkg-config
    perl
    python
    curl
    openssl
    zlib
    expat
    pcre2
    gnumake
    gnutar
    xz
    findutils
    diffutils
    gawk
    gnused
    gnugrep
    binutils
    patchelf
    ;
  doCheck = args.doCheck or true;

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
  configurePrefix = "/tvp/git";
  runtime = {
    libraries = final.environment.libraries;
    shell = final.bash;
    perl = final.perl;
    python = final.python;
  };
  tvp.features = {
    http = true;
    pcre2 = true;
    gui = false;
    gettext = false;
    manpages = false;
    bundledSshClient = false;
  };
  upstreamPreparation = steps.shebangs {
    name = "git.test-shells";
    python = helperPython;
    paths = [ "t" ];
    names = [ "sh" "bash" ];
    interpreter = "${final.bash}/bin/bash";
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit xz findutils;
    })
    (command "source-slots" ''
      ${helperPython}/bin/python3 -B ${./prepare.py}
    '')
    (command "configure" ''
      ${final.bash}/bin/bash ./configure --prefix=${lib.escapeShellArg configurePrefix} \
        --with-curl=${curl} --with-openssl=${openssl} --with-expat=${expat} --with-zlib=${zlib}
    '')
    (command "build" ''${make}'')
    (command "install" ''
      ${make} DESTDIR="$TVP_SOURCE_ROOT/stage" install
      mkdir -p "$out"
      cp -a "$TVP_SOURCE_ROOT/stage"${lib.escapeShellArg configurePrefix}/. "$out/"
    '')
    (steps.split "git.finalize")
    (outputs.copyArtifacts { inherit coreutils; })
    {
      name = "git.bind-runtime";
      tools = [ helperPython ];
      run = ''${helperPython}/bin/python3 -B ${./finalize.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (builtins.toJSON {
          shell = [ "${final.bash}/bin/bash" "${final.runtime.shell}/bin/bash" ];
          perl = [ "${final.perl}/bin/perl" "${final.runtime.perl}/bin/perl" ];
          python = [ "${final.python}/bin/python3" "${final.runtime.python}/bin/python3" ];
        })
      } ${../../../../lib/installed-tree.py} ${../../../libraries/libxml2/ordinary/elf.py} ${binutils}/bin/readelf'';
    }
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

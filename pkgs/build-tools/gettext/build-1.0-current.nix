# Gettext 1.0: independent ordinary source-GNU recipe. Native spit, styling,
# XML, Java and NLS retain the existing release profile. One compiled prefix;
{
  tvp,
  lib,
  base,
  src,
  version,
  binutils,
  perl,
  python,
  jdk,
  json-c,
  curl,
  ncurses,
  libxml2,
  zlib,
  acl,
  attr,
  configureFlags ? [ ],
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs;
  baseTools = context.tools;
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  gawk = baseTools.gawk;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  grep = baseTools.grep;
  patchelf = baseTools.patchelf;
  pkg-config = baseTools.pkg-config;
  sed = baseTools.sed;
  xz = baseTools.xz;
in

let
  environment = final.base.environment final.environment;
  command =
    name:
    steps.command {
      environment = final.environment;
    } "gettext.${name}";
  make = "${final.tools.gnumake}/bin/make SHELL=${final.bash}/bin/bash";
  elfPaths = [
    "bin"
    "lib"
    "libexec"
  ];
  helperPaths = [
    "bin"
    "libexec/gettext"
    "share/gettext"
  ];
in
{
  pname = "gettext";
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  gawk = baseTools.gawk;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  grep = baseTools.grep;
  patchelf = baseTools.patchelf;
  pkg-config = baseTools.pkg-config;
  sed = baseTools.sed;
  xz = baseTools.xz;
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    ;
  tools = {
    inherit
      gnumake
      gnutar
      xz
      findutils
      sed
      grep
      gawk
      diffutils
      pkg-config
      binutils
      patchelf
      python
      ;
  };
  providers = {
    inherit
      json-c
      curl
      ncurses
      libxml2
      zlib
      acl
      attr
      ;
  };
  inherit
    configureFlags
    doCheck
    ;
  dependencyProviders =
    (builtins.intersectAttrs {
      binutils = null;
      python = null;
    } final.tools)
    // final.providers
    // {
      inherit (final.runtime) perl jdk;
    };
  environment = {
    tools =
      (builtins.attrValues (
        removeAttrs final.tools [
          "binutils"
          "patchelf"
        ]
      ))
      ++ [
        final.bash
        final.coreutils
        final.runtime.perl
        final.runtime.jdk
      ];
    libraries = builtins.attrValues final.providers;
  };
  runtime = {
    inherit perl jdk;
    libraries = builtins.attrValues final.providers;
    tools = [
      final.coreutils
      final.tools.sed
      final.tools.grep
      final.tools.gawk
      final.tools.diffutils
      final.tools.findutils
      final.tools.gnutar
      final.tools.xz
    ];
  };
  # The headers expose no external includes, but an isolated libtextstyle
  # consumer needs Ncurses in the GNU linker's indirect DSO search path.
  # libgettextpo consumers need no additional public provider.
  developmentLibraries = [ final.providers.ncurses ];
  upstreamCheck =
    (command "check" ''
      status=0
      ${make} -j1 check > upstream-check.log 2>&1 || status=$?
      cat upstream-check.log
      printf '%s\n' "$status" > upstream-check.status
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
    };

  originalPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.tools.gnutar;
      inherit (final.tools) xz findutils;
    })
    (command "prepare" ''
      ${final.tools.python}/bin/python3 -B ${./native/prepare-production.py} ${
        lib.escapeShellArg (
          builtins.toJSON {
            bash = toString final.bash;
            perl = toString final.runtime.perl;
            python = toString final.tools.python;
          }
        )
      }
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      export PERL=${final.runtime.perl}/bin/perl PYTHON=${final.tools.python}/bin/python3
      export JAVA_HOME=${final.runtime.jdk}
      ./configure --prefix="$out" --disable-static --disable-dependency-tracking --with-libxml2-prefix=${final.providers.libxml2} \
        --with-libncurses-prefix=${final.providers.ncurses} ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "capabilities" ''
      grep -q '^am__append_1 = spit$' gettext-tools/src/Makefile || {
        echo 'Gettext requires native spit with JSON-C and shared Curl' >&2; exit 1;
      }
      grep -q '^#define HAVE_TERMINFO 1$' libtextstyle/config.h
      grep '^LIBTERMINFO = ' libtextstyle/Makefile | grep -F '${final.providers.ncurses}/lib/libncursesw.so'
      grep '^LIBXML = ' gettext-tools/Makefile | grep -F '${final.providers.libxml2}/lib/libxml2.so'
      grep -q '^HAVE_JAVAC = 1$' gettext-runtime/intl-java/Makefile
      grep -q '^#define ENABLE_NLS 1$' gettext-tools/config.h
    '')
    (command "build" ''${make} -j"$NIX_BUILD_CORES"'')
    (command "install" ''
      ${make} -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "gettext.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gettext.relocate";
      tools = [ final.tools.python ];
      run = ''${final.tools.python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            text = [ ];
            slots = [ ];
            fixed = [ ];
          }
        )
      } ${../../../lib/installed-tree.py}'';
    }
    (outputs.shebangs {
      python = final.tools.python;
      paths = helperPaths;
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (
      (outputs.shebangs {
        python = final.tools.python;
        paths = helperPaths;
        names = [ "perl" ];
        interpreter = "${final.runtime.perl}/bin/perl";
      })
      // {
        name = "output.perl-helpers";
      }
    )
    {
      name = "gettext.runtime-tools";
      tools = [ final.tools.python ];
      run = ''${final.tools.python}/bin/python3 -B ${./native/runtime.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            bash = toString final.bash;
            paths = map (p: "${p}/bin") final.runtime.tools;
            scripts = [
              "bin/gettextize"
              "bin/autopoint"
              "libexec/gettext/project-id"
              "libexec/gettext/user-email"
            ];
          }
        )
      }'';
    }
    (outputs.strip {
      inherit (final.tools) python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit (final.tools) python binutils;
      paths = [ "lib" ];
    })
    (outputs.libtool {
      python = final.tools.python;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      inherit (final.tools) python binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    (outputs.development {
      python = final.tools.python;
      libraries = final.developmentLibraries;
    })
    (outputs.checkSymlinks {
      python = final.tools.python;
      paths = [
        "lib/libasprintf.so"
        "lib/libasprintf.so.0"
        "lib/libtextstyle.so"
        "lib/libtextstyle.so.0"
        "lib/libgettextlib.so"
        "lib/libgettextsrc.so"
        "lib/libgettextpo.so"
        "lib/libgettextpo.so.0"
      ];
    })
    (outputs.checkPaths {
      inherit (final.tools) python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = {
    doCheck = final.doCheck;
    nls = true;
    nativeSpit = true;
    xml = true;
    styling = true;
    java = true;
  };
  meta = {
    description = "GNU translation tools, text styling and native machine translation frontend";
    homepage = "https://www.gnu.org/software/gettext/";
    license = [
      lib.licenses.gpl3Plus
      lib.licenses.lgpl21Plus
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "gettext";
  };

  upstreamPlan = artifact: [
    {
      name = "gettext.restore-build-tree";
      tools = [ baseTools.python ];
      run = ''
        ${baseTools.python}/bin/python3 -B ${../../../lib/restore-checkpoint.py} ${artifact}/nix-support/gettext-build-tree "$TVP_SOURCE_ROOT"
      '';
    }
    {
      name = "gettext.prepare-test-frontends";
      tools = [ final.tools.python ];
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ${final.tools.python}/bin/python3 -B ${./native/prepare-tests.py} ${
          lib.escapeShellArg (
            builtins.toJSON {
              phase = "tests";
              bash = toString final.bash;
              perl = toString final.runtime.perl;
              python = toString final.tools.python;
            }
          )
        }
      '';
    }
  ];
  plan =
    let
      parts = steps.partition final.originalPlan;
    in
    parts.first
    ++ [
      {
        name = "gettext.save-build-tree";
        tools = [
          baseTools.python
          final.coreutils
        ];
        run = ''
          ${baseTools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/nix-support/gettext-build-tree"
        '';
      }
    ]
    ++ (lib.optional parts.split (steps.split "gettext.finalize"))
    ++ [
      (builtins.head parts.second)
      {
        name = "gettext.drop-build-tree";
        tools = [ final.coreutils ];
        run = ''${final.coreutils}/bin/rm -rf -- "$out/nix-support/gettext-build-tree"'';
      }
    ]
    ++ builtins.tail parts.second;
}

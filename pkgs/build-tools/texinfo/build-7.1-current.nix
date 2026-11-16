# Ordinary 7.1 onward: independent native procedure, Perl XS and wide Info.
# Frozen and source-bootstrap procedures retain their original construction.
{
  tvp,
  lib,
  base,
  src,
  version,
  binutils,
  perl,
  ncurses,
  localeTools,
  patches ? [ ],
  configureFlags ? [ ],
  cStandard ? "gnu17",
}@args:
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
  gzip = baseTools.gzip;
  patch = baseTools.patch;
  patchelf = baseTools.patchelf;
  python = baseTools.python;
  sed = baseTools.sed;
  xz = baseTools.xz;
in

let
  inherit (final)
    base
    src
    version
    bash
    coreutils
    ;
  command =
    name:
    steps.command {
      environment = final.environment;
    } "texinfo.${name}";
in
{
  pname = "texinfo";
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  gawk = baseTools.gawk;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  grep = baseTools.grep;
  gzip = baseTools.gzip;
  patch = baseTools.patch;
  patchelf = baseTools.patchelf;
  python = baseTools.python;
  sed = baseTools.sed;
  xz = baseTools.xz;
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
  inherit (args)
    base
    src
    version
    ;
  environment = {
    tools = [
      gnumake
      perl
      patch
      gzip
      xz
      findutils
      sed
      grep
      gawk
      diffutils
    ];
    libraries = [ ncurses ];
  };
  runtime.libraries = [ ncurses ];
  upstreamCheck =
    (command "upstream" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      status=0
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" check || status=$?
      find . \( -name 'test-suite.log' -o -name '*.trs' \) -exec cat {} \; >&2
      if (( status )); then exit "$status"; fi
    '')
    // {
      enabled = true;
    };
  originalPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz findutils;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      name = "texinfo.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (command "patch" ''
      for file in ${lib.escapeShellArgs (map (p: "${p}") patches)}; do
        ${patch}/bin/patch -p1 < "$file"
      done
      ${python}/bin/python3 -B - <<'PATCH'
      from pathlib import Path
      p = Path('tp/Texinfo/Translations.pm')
      data = p.read_text()
      assert data.count('@TVP_LOCALE@') == 1
      p.write_text(data.replace('@TVP_LOCALE@', '${localeTools}/bin/locale'))
      PATCH
    '')
    (steps.shebangs {
      name = "texinfo.perl-helpers";
      inherit python;
      paths = [ "tp/maintain" ];
      names = [ "perl" ];
      interpreter = "${perl}/bin/perl";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      export CFLAGS="''${CFLAGS:--O2} -I${ncurses}/include/ncursesw${
        lib.optionalString (cStandard != null) " -std=${cStandard}"
      }"
      ./configure --prefix="$out" PERL=${perl}/bin/perl PERL_EXT_CC="$CC" --enable-perl-xs=yes ${lib.escapeShellArgs configureFlags}
      # A successful outer configure can silently disable the XS subproject.
      test -s tp/Texinfo/XS/Makefile
      grep -F "$CC" tp/Texinfo/XS/Makefile
    '')
    (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (command "install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash TEXMF="$out/texmf-dist" install install-tex
      test -s "$out/texmf-dist/tex/texinfo/texinfo.tex"
      test -n "$(find "$out/lib" -name '*.so' -print -quit)"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "texinfo.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "texinfo.relocate";
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
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
      inherit python;
      paths = [ "bin" ];
      names = [ "perl" ];
      interpreter = "${perl}/bin/perl";
    })
    (
      (outputs.shebangs {
        inherit python;
        paths = [ "bin" ];
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
    {
      name = "texinfo.bind-shell-helpers";
      tools = [ python ];
      run = ''
        ${python}/bin/python3 -B - "$out" <<'PYTHON'
        import sys
        from pathlib import Path
        root = Path(sys.argv[1])
        profile = f"{root}/bin:${coreutils}/bin:${sed}/bin:${grep}/bin:${gawk}/bin:${findutils}/bin:${diffutils}/bin:${gzip}/bin"
        for name in ['texi2pdf', 'texi2dvi', 'texindex']:
            path = root / 'bin' / name
            first, rest = path.read_text().split('\n', 1)
            assert first == '#!${final.bash}/bin/bash', name
            path.write_text(first + '\nPATH=' + profile + ':"$' + '{PATH-}"; export PATH\n' + rest)
        PYTHON
      '';
    }
    (outputs.strip {
      inherit python binutils;
      paths = [
        "bin"
        "lib"
      ];
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
    })

    (outputs.development {
      inherit python;
      libraries = [ ncurses ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp.features = {
    perlXS = true;
    infoReader = true;
    texSupport = true;
  };
  meta = {
    description = "GNU Texinfo documentation tools and wide Info reader";
    homepage = "https://www.gnu.org/software/texinfo/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "makeinfo";
  };

  upstreamPlan = artifact: [
    {
      name = "texinfo.restore-build-tree";
      tools = [ baseTools.python ];
      run = ''
        ${baseTools.python}/bin/python3 -B ${../../../lib/restore-checkpoint.py} ${artifact}/nix-support/texinfo-build-tree "$TVP_SOURCE_ROOT"
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
        name = "texinfo.save-build-tree";
        tools = [
          baseTools.python
          final.coreutils
        ];
        run = ''
          ${baseTools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/nix-support/texinfo-build-tree"
        '';
      }
    ]
    ++ (lib.optional parts.split (steps.split "texinfo.finalize"))
    ++ [
      (builtins.head parts.second)
      {
        name = "texinfo.drop-build-tree";
        tools = [ final.coreutils ];
        run = ''${final.coreutils}/bin/rm -rf -- "$out/nix-support/texinfo-build-tree"'';
      }
    ]
    ++ builtins.tail parts.second;
}

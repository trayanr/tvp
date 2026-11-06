# Selected source-native release; canonical family construction is unchanged.
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
  xz,
  python,
  binutils,
  patchelf,
  perl,
  ncurses,
  localeTools,
  patch,
  gzip,
  cStandard ? "gnu17",
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "texinfo.${name}";
      cwd = "source";
      run = run;
    };
in
{
  pname = "texinfo";
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
      perl
      patch
      gzip
      xz
    ];
    libraries = [ ncurses ];
  };
  runtime.libraries = [ ncurses ];
  plan = steps.sequence [
    (steps.unpack {
      inherit src xz;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      name = "texinfo.prepare";
      inherit bash python;
      base = final.base;
    })
    (command "patch" ''
      ${patch}/bin/patch -p1 < ${../patches/wide-ncurses.patch}
      ${patch}/bin/patch -p1 < ${../patches/locale-program.patch}
      # Perl 5.44 diagnoses ambiguous negation; express the intended nonempty
      # output filename check directly, without suppressing warnings.
      ${patch}/bin/patch -p1 < ${../patches/perl-5.44-precedence.patch}
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
      export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash
      export CFLAGS="''${CFLAGS:--O2} -I${ncurses}/include/ncursesw${
        lib.optionalString (cStandard != null) " -std=${cStandard}"
      }"
      ./configure --prefix="$out" PERL=${perl}/bin/perl PERL_EXT_CC="$CC" --enable-perl-xs=yes
    '')
    (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'')
    (command "check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash check'')
    (command "install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash TEXMF="$out/texmf-dist" install install-tex
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
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
        interpreter = "${bash}/bin/bash";
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
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [
        "bin"
        "lib"
      ];
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
  meta.platforms = [ "x86_64-linux" ];
}

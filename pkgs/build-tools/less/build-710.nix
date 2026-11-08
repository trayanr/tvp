# First owned pager profile: full 710 commands and declared-shell child execution.
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
  python,
  binutils,
  patchelf,
  ncurses,
  pcre2,
  patch,
  patches ? [ ],
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "less.${name}";
      cwd = "source";
      inherit run;
    };
in
{
  pname = "less";
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
      findutils
      sed
      grep
      gawk
    ];
    libraries = [
      ncurses
      pcre2
    ];
  };
  runtime.libraries = [
    ncurses
    pcre2
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "less.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (command "patch" ''
      for file in ${lib.escapeShellArgs (map (p: "${p}") patches)}; do
        ${patch}/bin/patch -p1 < "$file"
      done
    '')
    (command "declared-shell" ''
      cp ${./declared-shell.c} declared-shell.c
      chmod u+w declared-shell.c
      ${python}/bin/python3 -B - <<'PYTHON'
      from pathlib import Path
      p = Path('declared-shell.c')
      text = p.read_text()
      assert text.count('@TVP_SHELL@') == 1
      p.write_text(text.replace('@TVP_SHELL@', '${final.bash}/bin/bash'))
      p = Path('Makefile.in')
      text = p.read_text()
      assert text.count('OBJ = \\\n') == 1
      p.write_text(text.replace('OBJ = \\\n', 'OBJ = declared-shell.$' + '{O} \\\n'))
      PYTHON
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      export CPPFLAGS="''${CPPFLAGS-} -I${ncurses}/include/ncursesw -I${pcre2}/include"
      ./configure --prefix="$out" --sysconfdir="$out/etc" --libexecdir="$out/bin" --with-regex=pcre2
      grep -q '^#define HAVE_PCRE2 1' defines.h
    '')
    (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash LDFLAGS="''${LDFLAGS-} -Wl,--wrap=popen,--wrap=pclose,--wrap=system"'')
    (command "install" ''
      ${gnumake}/bin/make SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.shebangs {
      inherit python;
      paths = [ "bin" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    {
      name = "less.bind-link-helper";
      tools = [ python ];
      run = ''
        ${python}/bin/python3 -B - "$out" <<'PYTHON'
        import sys
        from pathlib import Path
        root = Path(sys.argv[1])
        p = root / 'bin/less-osc8-open'
        first, rest = p.read_text().split('\n', 1)
        assert first == '#!${final.bash}/bin/bash'
        p.write_text(first + f'\nPATH={root}/bin:${coreutils}/bin:${final.bash}/bin:"$' + '{PATH-}"; export PATH\n' + rest)
        PYTHON
      '';
    }
    (outputs.strip {
      inherit python binutils;
      paths = [ "bin" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [ "bin" ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "bin" ];
    })
  ];
  meta = {
    description = "File pager with declared shell execution";
    homepage = "https://www.greenwoodsoftware.com/less/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "less";
  };
}

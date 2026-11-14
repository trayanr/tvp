# Shared installed Autoconf/Automake pair assertions. Upstream execution is
# supplied separately through the checkpoint test factory.
{
  package,
  lib,
  context,
}:
let
  p = package;
  s = p.specification;
  d =
    s.base.standardTools
    // {
      coreutils = s.base.coreutils;
      bash = s.base.shell;
    }
    // p.tvp.deps;
  t = p.tvp.declaredTestDependencies;
  isAutoconf = p.pname == "autoconf";
  ac = if isAutoconf then p else d.autoconf;
  am = if isAutoconf then t.automake else p;
  api = am.specification.apiVersion or (lib.versions.majorMinor am.version);
  tools = [
    ac
    am
    ac.tvp.deps.m4
    d.findutils
    d.gnutar
    d.gnumake
    d.grep
    d.sed
    d.gawk
  ];
  macro = p.edit (
    s:
    s
    // {
      plan = [
        {
          name = "macro.fixture";
          run = ''
            mkdir -p "$out/share/aclocal" "$out/nix-support"
            printf 'AC_DEFUN([TVP_PROVIDER], [AC_DEFINE([TVP_ANSWER], [42], [Provider answer])])\n' > "$out/share/aclocal/tvp.m4"
            printf 'exit 93\n' > "$out/nix-support/setup-hook"
          '';
        }
      ];
    }
  );
  alternateXZ = p.edit (
    s:
    s
    // {
      plan = [
        {
          name = "alternate.xz";
          tools = [
            ac.specification.base.standardTools.gzip
            d.xz
          ];
          run = ''
            mkdir "$out"
            ${ac.specification.base.standardTools.gzip}/bin/gzip -cd ${t.alternateSource}/source.tar.gz | ${d.xz}/bin/xz -c > "$out/source.tar.xz"
          '';
        }
      ];
    }
  );
  project =
    lib.concatMapStringsSep "\n"
      (
        file:
        "cp ${file} ${lib.escapeShellArg (baseNameOf file)}\nchmod u+w ${lib.escapeShellArg (baseNameOf file)}"
      )
      [
        ./autoconf/tests/fixtures/owned-pair/configure.ac
        ./autoconf/tests/fixtures/owned-pair/Makefile.am
        ./autoconf/tests/fixtures/owned-pair/greeting.in
        ./autoconf/tests/fixtures/owned-pair/main.c
      ];
  build = ''
    mkdir build
    cd build
    ../configure --prefix="$PWD/install" >&2
    ${d.gnumake}/bin/make -j"$NIX_BUILD_CORES" >&2
    ${d.gnumake}/bin/make install >&2
    test "$(cat greeting)" = 42
    ./install/bin/answer
  '';
  discovery = context.mkTest {
    package = p;
    name = "macro-discovery";
    inherit tools;
    libraries = [ macro ];
    script = ''
      ${project}
      sed -i '/AC_PROG_CC/a TVP_PROVIDER' configure.ac
      ${ac}/bin/autoreconf --install --force >&2
      grep -q TVP_PROVIDER aclocal.m4
      ${build}
    '';
    expected = "42";
  };
  # Source and base edits execute an independent consumer, rather than matching
  # mirrored recipe strings. The edited source must reach the unpack command.
  sourceProbe =
    (p.override {
      src = if isAutoconf then "${t.alternateSource}/source.tar.gz" else "${alternateXZ}/source.tar.xz";
    }).edit
      (
        s:
        let
          selectedBase = s.base.override { compiler = t.sentinel; };
        in
        s
        // {
          base = selectedBase;
          plan = [
            (builtins.head s.plan)
            (
              (selectedBase.environment s.environment)
              // {
                name = "autotools.source-base";
                run = ''
                  test "$(cat source/marker)" = 'alternate source'
                  printf 'int main(void) { return 0; }\n' > probe.c
                  "$CC" probe.c -o probe
                  env -i ./probe
                  test "$(cat selected-compiler)" = selected
                  mkdir "$out"
                  cp source/marker "$out/marker"
                '';
              }
            )
          ];
        }
      );
  rebound = p.override (
    { perl = t.alternatePerl; } // lib.optionalAttrs isAutoconf { m4 = t.alternateM4; }
  );
  changed = p.editRuntime (
    r:
    r
    // {
      tools = [
        d.grep
        d.sed
        p.specification.coreutils
        t.runtimeShell
      ];
    }
  );
  contracts = {
    noOp = (p.override { }).drvPath == p.drvPath && (p.edit (s: s)).drvPath == p.drvPath;
    noLegacy = !(p ? overrideAttrs) && !(p ? stdenv);
    reboundTests = rebound.tests.version.package.outPath == rebound.outPath;
    factory =
      (
        (p.mkTests.override { tests = import (if isAutoconf then ./autoconf/tests else ./automake/tests); })
        p
      ).version.package.outPath == p.outPath;
    projections = builtins.all (
      q: q ? buildEnvironment && q.tests.version.package.outPath == p.outPath
    ) ([ p.out ] ++ p.all);
  };
in
context.mkSuite {
  inherit package tools;
  tests = {
    libtool-project = {
      tools = tools ++ [ t.libtool ];
      libraries = [ t.libtool ];
      script = ''
        mkdir -p m4
        cp ${./libtool/tests/fixtures/configure.ac} configure.ac
        cp ${./libtool/tests/fixtures/Makefile.am} Makefile.am
        cp ${./libtool/tests/fixtures/answer.c} answer.c
        cp ${./libtool/tests/fixtures/cppanswer.cc} cppanswer.cc
        cp ${./libtool/tests/fixtures/main.c} main.c
        chmod u+w configure.ac Makefile.am
        ${ac}/bin/autoreconf --install --force >&2
        mkdir build
        cd build
        ../configure --prefix="$PWD/install" >&2
        ${d.gnumake}/bin/make -j"$NIX_BUILD_CORES" >&2
        ${d.gnumake}/bin/make install >&2
        readelf -d install/bin/answer | grep -Fq libanswer.so.1
        ./install/bin/answer
        ./libtool --tag=CC --mode=link "$CC" -static ${./libtool/tests/fixtures/static-main.c} libanswer.la -o static-answer >&2
        if readelf -d static-answer | grep -q libanswer.so; then exit 1; fi
        ./static-answer
      '';
      expected = "42\n42";
    };
    installed-pair = {
      script = ''
        ${project}
        env -i PATH="$PATH" ${ac}/bin/autoreconf --install --force >&2
        ${build}
      '';
      expected = "42";
    };
    tool-overrides = {
      script = ''
        ${project}
        mkdir wrappers
        for name in autoconf autoheader autom4te autoreconf aclocal automake make m4; do
          real=$(command -v "$name")
          printf '#!%s/bin/bash\nprintf "%%s\\n" %s >> "%s/calls"\nexec %s "$@"\n' ${p.specification.bash} "$name" "$PWD" "$real" > "wrappers/$name"
          chmod +x "wrappers/$name"
        done
        export AUTOCONF="$PWD/wrappers/autoconf" AUTOHEADER="$PWD/wrappers/autoheader"
        export AUTOM4TE="$PWD/wrappers/autom4te" M4="$PWD/wrappers/m4"
        export AUTOMAKE="$PWD/wrappers/automake" ACLOCAL="$PWD/wrappers/aclocal" MAKE="$PWD/wrappers/make"
        ${ac}/bin/autoreconf --install --force >&2
        for name in autoconf autoheader autom4te m4 aclocal automake; do grep -qx "$name" calls; done
        ./configure >&2
        ${ac}/bin/autoreconf --force --make >&2
        grep -qx make calls
        "$MAKE" distclean >&2
        ${build}
      '';
      expected = "42";
    };
    data-overrides = {
      script = ''
        ${project}
        cp -r ${ac}/share/autoconf ac-data
        cp -r ${am}/share/automake-${api} am-data
        cp -r ${am}/share/aclocal-${api} am-macros
        chmod -R u+w ac-data am-data am-macros
        cat ${./autoconf/tests/fixtures/data-marker.pl} >> ac-data/Autom4te/Channels.pm
        cat ${./autoconf/tests/fixtures/data-language.cfg} >> ac-data/autom4te.cfg
        printf '# tvp-selected-automake-data\n' >> am-data/am/header-vars.am
        printf 'AC_DEFUN([TVP_DATA_MACRO], [AC_DEFINE([TVP_DATA_MARK], [73], [Data override])])\n' > am-macros/tvp-data.m4
        sed -i '/AC_PROG_CC/a TVP_DATA_MACRO' configure.ac
        export AUTOTOOLS_DATA_LOG="$PWD/data-used"
        export AC_MACRODIR="$PWD/ac-data" autom4te_perllibdir="$PWD/ac-data"
        export autom4te_buildauxdir="$PWD/ac-data/build-aux"
        export AUTOMAKE_LIBDIR="$PWD/am-data" ACLOCAL_AUTOMAKE_DIR="$PWD/am-macros"
        export AUTOM4TE=${ac}/bin/autom4te AUTOCONF=${ac}/bin/autoconf AUTOHEADER=${ac}/bin/autoheader
        ${am}/bin/aclocal --automake-acdir="$PWD/am-macros" >&2
        ${ac}/bin/autoheader >&2
        ${ac}/bin/autoconf >&2
        ${am}/bin/automake --libdir="$PWD/am-data" --add-missing >&2
        ${ac}/bin/autom4te --language=TVP-data --trace=AC_INIT:'$1' configure.ac | grep -qx owned-pair
        grep -qx selected data-used
        grep -q tvp-selected-automake-data Makefile.in
        ${build}
        grep -qx '#define TVP_DATA_MARK 73' config.h
      '';
      expected = "42";
    };
    explicit-macros = {
      script = ''
        ${project}
        sed -i '/AC_PROG_CC/a TVP_PROVIDER' configure.ac
        env -u ACLOCAL_PATH ${am}/bin/aclocal -I ${macro}/share/aclocal >&2
        ${ac}/bin/autoheader >&2
        ${ac}/bin/autoconf >&2
        ${am}/bin/automake --add-missing >&2
        ${build}
      '';
      expected = "42";
    };
    constructor = {
      expected =
        assert builtins.all (x: x) (builtins.attrValues contracts);
        "qualified";
      script = ''
        test -s ${sourceProbe}/marker
        ${project}
        ${rebound}/bin/${p.pname} --version >&2
        ${changed}/bin/${p.pname} --version >&2
        ${
          if isAutoconf then
            ''
                  ${am}/bin/aclocal
              env -i PATH=/absent ${rebound}/bin/autoconf
                  env -i PATH=/absent ${rebound}/bin/autoheader
                  ${changed}/bin/autoconf --trace=AC_INIT:'$1' | grep -qx owned-pair
            ''
          else
            ''
              ${ac}/bin/autoreconf --install --force >&2
              ${rebound}/bin/aclocal --force >&2
              ${changed}/bin/automake --add-missing >&2
            ''
        }
        printf qualified
      '';
    };
  };
}
// {
  macro-discovery = discovery;
}
// lib.optionalAttrs isAutoconf (
  context.mkSuite {
    inherit package tools;
    tests = {
      trace-cache-scan-update = {
        script = ''
          printf 'AC_INIT([trace-me], [1])\nAC_PROG_CC\nAC_OUTPUT\n' > configure.ac
          autoconf --trace=AC_INIT:'$1' | grep -qx trace-me
          autoconf
          test -s autom4te.cache/requests
          autoconf
          printf '#ifdef TVP_FLAG\n#endif\n' > scan.c
          ifnames scan.c | grep -q '^TVP_FLAG '
          autoscan >&2
          test -s configure.scan
          printf 'AC_INIT([old], [1])\nAC_PROG_CC\nAC_WARN([old warning])\nAC_OUTPUT\n' > configure.ac
          autoupdate >&2
          grep -q AC_MSG_WARN configure.ac
          autoconf
          ./configure --silent >&2
          printf scanned
        '';
        expected = "scanned";
      };
      installed-interpreters = {
        script = ''
          for name in ${
            lib.optionalString (p.specification.installedInterface.frontends.autoconf == "perl") "autoconf"
          } autoheader autom4te autoreconf autoscan autoupdate ifnames; do
            read -r interpreter flags < ${p}/bin/$name
            test "$interpreter" = '#!${p.runtime.perl}/bin/perl'
            case "$flags" in ""|-w) ;; *) exit 1 ;; esac
            env -i PATH=/absent ${p}/bin/$name --version >&2
          done
          head -1 ${p}/bin/autoconf | grep -qx '#!${
            if p.specification.installedInterface.frontends.autoconf == "perl" then
              "${p.runtime.perl}/bin/perl"
            else
              "${p.runtime.shell}/bin/bash"
          }'
          env -i PATH=/absent ${p}/bin/autoconf --version >&2
          printf seven
        '';
        expected = "seven";
      };
    };
  }
)
// lib.optionalAttrs (!isAutoconf) (
  context.mkSuite {
    inherit package tools;
    tests = {
      versioned-aliases = {
        script = ''
            test "$(readlink -f ${am}/bin/automake-${api})" = "$(readlink -f ${am}/bin/automake)"
            test "$(readlink -f ${am}/bin/aclocal-${api})" = "$(readlink -f ${am}/bin/aclocal)"
            ${project}
            ${am}/bin/aclocal-${api}
          ${ac}/bin/autoheader
            ${ac}/bin/autoconf
            ${am}/bin/automake-${api} --add-missing >&2
            ${build}
        '';
        expected = "42";
      };
    };
  }
)

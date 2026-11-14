{
  package,
  lib,
  context,
}:
let
  p = package;
  d = p.tvp.deps;
  tools = p.specification.base.standardTools;
  shellProvider = p.edit (
    s:
    (builtins.removeAttrs s [ "artifactName" ])
    // {
      plan = [
        {
          name = "runtime-shell.fixture";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/bash" <<'SCRIPT'
            #!${p.specification.base.shell}/bin/bash
            if [[ -n "''${TVP_RUNTIME_SHELL_LOG-}" ]]; then
              printf '%s\n' "$*" >> "$TVP_RUNTIME_SHELL_LOG"
            fi
            exec ${p.specification.base.shell}/bin/bash "$@"
            SCRIPT
            chmod +x "$out/bin/bash"
          '';
        }
      ];
    }
  );
  runtimeShell = p.editRuntime (r: r // { shell = shellProvider; });
  macroProvider = d.m4.edit (
    s:
    (builtins.removeAttrs s [ "artifactName" ])
    // {
      plan = [
        {
          name = "m4.provider-fixture";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/m4" <<'SCRIPT'
            #!${p.specification.base.shell}/bin/bash
            if [[ -n "''${TVP_PROVIDER_LOG-}" ]]; then printf 'selected-m4\n' >> "$TVP_PROVIDER_LOG"; fi
            exec ${d.m4}/bin/m4 "$@"
            SCRIPT
            chmod +x "$out/bin/m4"
          '';
        }
      ];
    }
  );
  rebound = p.override {
    m4 = macroProvider;
    file = d.file.editRuntime (r: r // { dlopenDirectories = [ "${d.file}/lib" ]; });
  };
  alternateXZ = p.edit (
    s:
    (builtins.removeAttrs s [ "artifactName" ])
    // {
      plan = [
        {
          name = "alternate.source";
          tools = [
            tools.gzip
            tools.xz
          ];
          run = ''
            mkdir "$out"
            ${tools.gzip}/bin/gzip -cd ${p.tvp.declaredTestDependencies.alternateSource}/source.tar.gz | ${tools.xz}/bin/xz -c > "$out/source.tar.xz"
          '';
        }
      ];
    }
  );
  sourceProbe =
    (p.override {
      src =
        if p.specification.sourceLayout != "build-aux-regenerated-ltmain" then
          "${p.tvp.declaredTestDependencies.alternateSource}/source.tar.gz"
        else
          "${alternateXZ}/source.tar.xz";
    }).edit
      (
        s:
        let
          base = s.base.override { compiler = p.tvp.declaredTestDependencies.sentinel; };
        in
        (builtins.removeAttrs s [ "artifactName" ])
        // {
          inherit base;
          plan = [
            (builtins.head s.plan)
            (
              (base.environment s.environment)
              // {
                name = "libtool.base";
                run = ''
                  test "$(cat source/marker)" = 'alternate source'
                  printf 'int main(void) { return 0; }\n' > probe.c
                  "$CC" probe.c -o probe
                  env -i ./probe
                  test "$(cat selected-compiler)" = selected
                  mkdir "$out"; cp source/marker "$out/source-marker"
                '';
              }
            )
          ];
        }
      );
in
context.mkSuite {
  package = p;
  tools = [
    d.autoconf
    d.automake
    d.m4
    d.file
    tools.gnumake
    tools.grep
    tools.sed
    tools.gawk
    tools.findutils
  ];
  libraries = [ p ];
  tests = {
    runtime-shell-wrappers-relink = {
      expected =
        assert runtimeShell.artifact.drvPath == p.artifact.drvPath;
        assert runtimeShell.drvPath != p.drvPath;
        "runtime-shell";
      script = ''
        LT=${runtimeShell}/bin/libtool
        mkdir -p installed/lib
        printf 'int dep(void) { return 41; }\n' > dep.c
        printf 'int dep(void); int answer(void) { return dep()+1; }\n' > answer.c
        printf '#include <stdio.h>\nint answer(void); int main(void) { printf("%%d\\n", answer()); }\n' > main.c
        "$LT" --tag=CC --mode=compile "$CC" -fPIC -c dep.c -o dep.lo >&2
        "$LT" --tag=CC --mode=link "$CC" dep.lo -o libdep.la -rpath "$PWD/installed/lib" >&2
        "$LT" --tag=CC --mode=compile "$CC" -fPIC -c answer.c -o answer.lo >&2
        "$LT" --tag=CC --mode=link "$CC" answer.lo libdep.la -o libanswer.la -rpath "$PWD/installed/lib" >&2
        "$LT" --tag=CC --mode=link "$CC" main.c libanswer.la -o consumer >&2
        head -1 consumer | sed 's/^#![[:space:]]*//' | grep -Fx '${shellProvider}/bin/bash' >&2
        env -i PATH="$PATH" TVP_RUNTIME_SHELL_LOG="$PWD/wrapper.log" ./consumer > answer
        test "$(cat answer)" = 42
        grep -F consumer wrapper.log >&2
        "$LT" --mode=install ${p.specification.base.coreutils}/bin/install -c libdep.la "$PWD/installed/lib" >&2
        export TVP_RUNTIME_SHELL_LOG="$PWD/relink.log"
        "$LT" --mode=install ${p.specification.base.coreutils}/bin/install -c libanswer.la "$PWD/installed/lib" >&2
        grep -F -- '--mode=relink' relink.log >&2
        printf runtime-shell
      '';
    };
    installed-consumer = {
      script = ''
        mkdir project
        cd project
        cp ${./fixtures/configure.ac} configure.ac
        cp ${./fixtures/Makefile.am} Makefile.am
        cp ${./fixtures/answer.c} answer.c
        cp ${./fixtures/cppanswer.cc} cppanswer.cc
        cp ${./fixtures/main.c} main.c
        chmod u+w configure.ac Makefile.am cppanswer.cc
        printf '#define TVP_DEPENDENCY 42\n' > dependency.hh
        printf '#include "dependency.hh"\n' >> cppanswer.cc
        printf '\nlibcppanswer_la_SOURCES += dependency.hh\n' >> Makefile.am
        env -i PATH="$PATH" ACLOCAL_PATH="$ACLOCAL_PATH" ${d.autoconf}/bin/autoreconf --install --force >&2
        test -s m4/libtool.m4
        mkdir build
        cd build
        ../configure --prefix="$NIX_BUILD_TOP/installed" >&2
        make -j"$NIX_BUILD_CORES" >&2
        grep -q dependency.hh .deps/cppanswer.Plo
        before=$(stat -c %Y .libs/cppanswer.o)
        # A deterministic newer header proves C++ dependency tracking schedules it.
        touch -d "@$((before + 2))" ../dependency.hh
        make -n > rebuild
        grep -q 'cppanswer.cc' rebuild
        touch ../dependency.hh
        make >&2
        make install >&2
        ./libtool --tag=CC --mode=compile "$CC" -fPIC -c ${./fixtures/plugin.c} -o plugin.lo >&2
        ./libtool --tag=CC --mode=link "$CC" -module -avoid-version -rpath "$NIX_BUILD_TOP/installed/lib" plugin.lo -o plugin.la >&2
        ./libtool --mode=install install -c plugin.la "$NIX_BUILD_TOP/installed/lib" >&2
        "$CC" ${./fixtures/loader.c} -lltdl -o "$NIX_BUILD_TOP/installed/bin/loader"
        cd "$NIX_BUILD_TOP"
        rm -rf project
        env -i ./installed/bin/answer
        env -i ./installed/bin/loader "$PWD/installed/lib/plugin.la"
        readelf -d installed/bin/answer > installed.elf
        grep -Fq '[libanswer.so.1]' installed.elf
        grep -Fq '[libcppanswer.so.1]' installed.elf
        if grep -E '/project/|/\.libs' installed.elf; then exit 1; fi
        readelf -d installed/bin/loader | grep -Fq '${p}/lib'
        test -s ${p}/lib/libltdl.a
        test -s ${p}/lib/libltdl.la
        "$CC" ${./fixtures/loader.c} ${p}/lib/libltdl.a -ldl -o static-loader
        env -i ./static-loader "$PWD/installed/lib/plugin.so"
        if readelf -d static-loader | grep -q libltdl.so; then exit 1; fi
      '';
      expected = "42\n42\n42";
    };
    user-overrides = {
      script = ''
        mkdir wrappers
        for name in autoconf automake m4; do
          real=$(command -v "$name")
          printf '#!%s/bin/bash\nprintf "%%s\\n" %s >> "%s/calls"\nexec %s "$@"\n' ${p.specification.base.shell} "$name" "$PWD" "$real" > wrappers/$name
          chmod +x wrappers/$name
        done
        export AUTOCONF="$PWD/wrappers/autoconf" AUTOMAKE="$PWD/wrappers/automake"
        export M4="$PWD/wrappers/m4"
        cp ${./fixtures/configure.ac} configure.ac
        cp ${./fixtures/Makefile.am} Makefile.am
        cp ${./fixtures/answer.c} answer.c
        cp ${./fixtures/cppanswer.cc} cppanswer.cc
        cp ${./fixtures/main.c} main.c
        libtoolize --help >&2
        libtoolize --copy --force >&2
        ${lib.optionalString p.tvp.features.toolDefaults ''
          grep -qx autoconf calls
          grep -qx automake calls
          grep -qx m4 calls
        ''}
        ${d.autoconf}/bin/autoreconf --install --force >&2
        grep -qx autoconf calls
        grep -qx automake calls
        grep -qx m4 calls
        mkdir build; cd build
        ../configure --prefix="$PWD/install" >&2
        make >&2; make install >&2
        ./libtool --version >&2
        ./install/bin/answer
      '';
      expected = "42";
    };
    constructor = {
      expected =
        assert (p.override { }).drvPath == p.drvPath;
        assert (p.edit (s: s)).drvPath == p.drvPath;
        assert rebound.tests.version.package.outPath == rebound.outPath;
        assert p.development.aclocalDirectories == [ "${p}/share/aclocal" ];
        assert !(p ? stdenv) && !(p ? overrideAttrs);
        "qualified";
      script = ''
        test -s ${sourceProbe}/source-marker
        ${rebound}/bin/libtoolize --version >&2
        printf 'AC_INIT([provider], [1])\nLT_INIT\nAC_OUTPUT\n' > configure.ac
        env -u M4 TVP_PROVIDER_LOG="$PWD/provider-calls" ${rebound}/bin/libtoolize --copy --force >&2
        ${lib.optionalString p.tvp.features.toolDefaults ''grep -qx selected-m4 provider-calls''}
        env M4=${rebound.specification.m4}/bin/m4 TVP_PROVIDER_LOG="$PWD/provider-calls" ${d.autoconf}/bin/autoconf >&2
        grep -qx selected-m4 provider-calls

        grep -Fq '${rebound.tvp.deps.file}/bin/file' ${rebound}/bin/libtool
        printf qualified
      '';
    };
  };
}

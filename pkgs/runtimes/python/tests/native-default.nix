# Native implementation of the ordinary suite: same named profile tests,
# explicit support roles, plus measured installed/developer interface coverage.
{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  lib = pkgs.lib;
  deps = package.tvp.deps;
  support = package.tvp.testDeps;
  testLinker = import ./native-linker.nix {
    builder = tvp.builder;
    inherit (package.specification) base bash coreutils;
  };
  linkage = dependency: soname: modules: {
    script = ''
      python3 ${./native-linkage.py} ${lib.escapeShellArg "${lib.getLib dependency}/lib"} \
        ${lib.escapeShellArg soname} ${lib.escapeShellArgs modules}
    '';
    expected = "linked";
  };
in
package.testContext.mkSuite {
  inherit package;
  tools = [
    deps.binutils
    deps.grep
    deps.gawk
    deps.sed
    deps.findutils
    deps.pkgConfig
  ];
  libraries = [ package ];
  tests =
    {
      omissions = {
        script = ''python3 -c 'import importlib.util, sys; assert all(importlib.util.find_spec(m) is None for m in sys.argv[1:]); print("explicit")' ${lib.escapeShellArgs package.tvp.disabledModules}'';
        expected = "explicit";
      };
      version = {
        script = ''python3 -c 'import platform; print(platform.python_version())' '';
        expected = package.version;
      };
      stdlib = {
        script = ''python3 ${./fixtures/stdlib.py}'';
        expected = "general-purpose";
      };
      subprocess-core = {
        script = ''python3 -c 'import subprocess; print(subprocess.Popen("printf 42", shell=True, stdout=subprocess.PIPE).communicate()[0].decode())' '';
        expected = "42";
      };

      extension = {
        script = ''
          "$CC" -shared -fPIC $(python3-config --cflags) ${./fixtures/answer.c} -o answer$(python3-config --extension-suffix)
          python3 -c 'import answer; print(answer.answer())'
        '';
        expected = "42";
      };

      venv = {
        script = ''
          export PIP_NO_INDEX=1 PIP_DISABLE_PIP_VERSION_CHECK=1
          python3 -m pip --version >&2
          python3 -m venv env
          env/bin/python -m pip --version >&2
          env/bin/python -c 'import sys, ssl, sqlite3, ctypes; assert sys.prefix != sys.base_prefix; print("isolated")'
        '';
        expected = "isolated";
      };
      upstream = {
        tools = [
          testLinker
          deps.binutils
          deps.grep
          deps.gawk
          deps.sed
        ];
        script = ''
          export PATH=${testLinker}/bin:$PATH
          export LD_LIBRARY_PATH=${package.compiler.libc}/lib
          python3 -m test -v -j"$NIX_BUILD_CORES" ${lib.escapeShellArgs package.tvp.upstreamModules} > upstream.log 2>&1 || { cat upstream.log >&2; exit 1; }
          cat upstream.log >&2
          grep -E 'Total tests: run=[1-9]' upstream.log >&2
          printf passed
        '';
        expected = "passed";
      };
      upstream-profile = {
        script = ''
          python3 -m test -v -j"$NIX_BUILD_CORES" test_decimal test_zstd test_ensurepip test_venv test_codecs > upstream-profile.log 2>&1 || { cat upstream-profile.log >&2; exit 1; }
          cat upstream-profile.log >&2
          grep -E 'Total tests: run=[1-9]' upstream-profile.log >&2
          printf passed
        '';
        expected = "passed";
      };
      openssl-linkage = linkage deps.openssl "lib(ssl|crypto)\\.so" [
        "_ssl"
        "_hashlib"
      ];
      ffi-linkage = linkage deps.libffi "libffi\\.so" [ "_ctypes" ];
      sqlite-linkage = linkage deps.sqlite "libsqlite3\\.so" [ "_sqlite3" ];
      gdbm-linkage = linkage deps.gdbm "libgdbm(_compat)?\\.so" [
        "_gdbm"
        "_dbm"
      ];
      readline-linkage = linkage deps.readline "libreadline\\.so" [ "readline" ];
      curses-linkage = linkage deps.ncurses "lib(ncursesw?|panelw?|tinfow?)\\.so" [
        "_curses"
        "_curses_panel"
      ];
      zlib-linkage = linkage deps.zlib "libz\\.so" [ "zlib" ];
      bzip2-linkage = linkage deps.bzip2 "libbz2\\.so" [ "_bz2" ];
      xz-linkage = linkage deps.xz "liblzma\\.so" [ "_lzma" ];
      zstd-linkage = linkage deps.zstd "libzstd\\.so" [ "_zstd" ];
      decimal-linkage = linkage deps.mpdecimal "libmpdec\\.so" [ "_decimal" ];
      zstd = {
        script = ''python3 -c 'from compression import zstd; assert zstd.decompress(zstd.compress(b"tvp")) == b"tvp"; print("roundtrip")' '';
        expected = "roundtrip";
      };

      installed-profile = {
        script = ''python3 ${./native-profile.py} ${./general-purpose-profile.json} ${package} ${package.runtime.shell}/bin/bash'';
        expected = "complete";
      };
      development = {
        script = ''python3 ${./native-development.py} ${./fixtures/answer.c} ${./fixtures/embed.c}'';
        expected = "interfaces";
      };
      cmake-python = {
        tools = [
          support.cmake
          deps.gnumake
          deps.grep
        ];
        script = ''
          cp ${./fixtures/answer.c} answer.c
          cp ${./fixtures/embed.c} embed.c
          cp ${./fixtures/CMakeLists.txt} CMakeLists.txt
          cmake -S . -B build -DPython3_EXECUTABLE=${package}/bin/python3 -DPython3_ROOT_DIR=${package} -DPython3_FIND_STRATEGY=LOCATION >&2
          cmake --build build --parallel "$NIX_BUILD_CORES" >&2
          (cd build; python3 -c 'import answer; assert answer.answer()==42'; ./embed)
        '';
        expected = "42";
      };
      meson-python = {
        tools = [
          support.meson
          support.ninja
          deps.pkgConfig
        ];
        script = ''
          cp ${./fixtures/answer.c} answer.c
          cp ${./fixtures/embed.c} embed.c
          cp ${./fixtures/meson.build} meson.build
          cp ${./fixtures/meson.options} meson.options
          meson setup build -Dpython=${package}/bin/python3 >&2
          meson compile -C build >&2
          (cd build; python3 -c 'import answer; assert answer.answer()==42'; ./embed)
        '';
        expected = "42";
      };
    }
    // lib.optionalAttrs package.tvp.features.linkUnwinder {
      thread-unwinder = {
        script = ''
          LD_TRACE_LOADED_OBJECTS=1 ${package}/bin/python3 > linked
          grep -F '${builtins.elemAt package.compiler.runtimeDirectories 2}/libgcc_s.so.1' linked >&2
          python3 -c 'import ctypes; ctypes.pythonapi.PyThread_exit_thread()'
          printf unwound
        '';
        expected = "unwound";
      };
    }
    // lib.optionalAttrs package.tvp.features.embedFlag {
      embed = {
        script = ''"$CC" ${./fixtures/embed.c} $(python3-config --cflags --embed --ldflags) -o embed; ./embed'';
        expected = "42";
      };
    }
    // lib.optionalAttrs package.tvp.features.textSubprocess {
      subprocess = {
        script = ''python3 -c 'import subprocess; print(subprocess.check_output("printf 42", shell=True, text=True))' '';
        expected = "42";
      };
    };
}

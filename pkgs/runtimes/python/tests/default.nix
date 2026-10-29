{
  pkgs,
  tvpLib,
  package,
}:
let
  deps = package.tvp.deps;
  linkage = dependency: soname: modules: {
    script = ''
      modules=$(python3 -c 'import importlib, sys; print("\n".join(importlib.import_module(m).__file__ for m in sys.argv[1:]))' ${pkgs.lib.escapeShellArgs modules})
      paths=$(while IFS= read -r module; do ldd "$module"; done <<< "$modules" | awk '/${soname}/ {print $3}')
      test -n "$paths"
      while IFS= read -r path; do
        case "$path" in
          ${pkgs.lib.escapeShellArg "${pkgs.lib.getLib dependency}/"}*) ;;
          *) echo "Unexpected library path: $path" >&2; exit 1 ;;
        esac
      done <<< "$paths"
      printf linked
    '';
    expected = "linked";
    extraInputs = [ pkgs.glibc.bin ];
  };
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests =
    {
      omissions = {
        script = ''python3 -c 'import importlib.util, sys; assert all(importlib.util.find_spec(m) is None for m in sys.argv[1:]); print("explicit")' ${pkgs.lib.escapeShellArgs package.tvp.disabledModules} '';
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
          cc -shared -fPIC $(python3-config --cflags) ${./fixtures/answer.c} -o answer$(python3-config --extension-suffix)
          python3 -c 'import answer; print(answer.answer())'
        '';
        expected = "42";
        extraInputs = [ package.tvp.cc ];
      };
      venv = {
        script = ''
          export PIP_NO_INDEX=1
          python3 -m venv env
          env/bin/python -m pip --version >&2
          env/bin/python -c 'import sys, ssl, sqlite3, ctypes; assert sys.prefix != sys.base_prefix; print("isolated")'
        '';
        expected = "isolated";
      };
      upstream = {
        script = ''
          python3 -m test -v -j"$NIX_BUILD_CORES" ${pkgs.lib.escapeShellArgs package.tvp.upstreamModules} > upstream.log 2>&1 || { cat upstream.log >&2; exit 1; }
          cat upstream.log >&2
          printf passed
        '';
        expected = "passed";
        extraInputs = [ package.tvp.cc ];
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
    }
    // pkgs.lib.optionalAttrs (deps ? libxcrypt) {
      crypt = {
        script = ''python3 -c 'import crypt; h = crypt.crypt("tvp", "$6$tvp$"); assert crypt.crypt("tvp", h) == h and crypt.crypt("wrong", h) != h; print("verified")' '';
        expected = "verified";
      };
      crypt-linkage = linkage deps.libxcrypt "libcrypt\\.so" [ "_crypt" ];
    }
    // pkgs.lib.optionalAttrs (deps ? zstd) {
      zstd = {
        script = ''python3 -c 'from compression import zstd; assert zstd.decompress(zstd.compress(b"tvp")) == b"tvp"; print("roundtrip")' '';
        expected = "roundtrip";
      };
      zstd-linkage = linkage deps.zstd "libzstd\\.so" [ "_zstd" ];
    }
    // pkgs.lib.optionalAttrs (deps ? mpdecimal) {
      decimal-linkage = linkage deps.mpdecimal "libmpdec\\.so" [ "_decimal" ];
    }
    // pkgs.lib.optionalAttrs package.tvp.features.embedFlag {
      embed = {
        script = ''cc ${./fixtures/embed.c} $(python3-config --cflags --embed --ldflags) -o embed; ./embed'';
        expected = "42";
        extraInputs = [ package.tvp.cc ];
      };
    }
    // pkgs.lib.optionalAttrs (!package.tvp.features.embedFlag && package.tvp.features.finalizeEx) {
      embed-legacy = {
        script = ''cc ${./fixtures/embed.c} $(python3-config --cflags --ldflags) -o embed; ./embed'';
        expected = "42";
        extraInputs = [ package.tvp.cc ];
      };
    }
    // pkgs.lib.optionalAttrs package.tvp.features.textSubprocess {
      subprocess = {
        script = ''python3 -c 'import subprocess; print(subprocess.check_output("printf 42", shell=True, text=True))' '';
        expected = "42";
      };
    }
    // pkgs.lib.optionalAttrs (!package.tvp.features.finalizeEx) {
      embed-finalize = {
        script = ''cc ${./fixtures/embed-legacy.c} $(python3-config --cflags --ldflags) -o embed; ./embed'';
        expected = "42";
        extraInputs = [ package.tvp.cc ];
      };
    };
}

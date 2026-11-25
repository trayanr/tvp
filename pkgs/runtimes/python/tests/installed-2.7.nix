{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [ tools.pkg-config ];
  libraries = [ package ];
  tests = {
    interpreter = {
      script = ''
        python2 -E -s - <<'PY'
        import ast
        import platform
        import subprocess
        import sys
        from distutils import sysconfig

        assert sys.prefix == "${package}"
        assert sys.maxunicode == 0x10ffff
        assert sysconfig.get_python_inc() == "${package}/include/python2.7"
        ast.parse("print 'legacy generator'")
        assert subprocess.check_output("printf 42", shell=True) == "42"
        print platform.python_version()
        PY
      '';
      expected = package.version;
    };
    standard-library = {
      script = ''
        python2 -E -s - <<'PY'
        import bz2
        import crypt
        import ctypes
        import curses
        import dbm
        import gdbm
        import hashlib
        import pip
        import readline
        import sqlite3
        import ssl
        import zlib

        assert bz2.decompress(bz2.compress("python2")) == "python2"
        assert zlib.decompress(zlib.compress("python2")) == "python2"
        assert sqlite3.connect(":memory:").execute("select 42").fetchone() == (42,)
        assert ssl.OPENSSL_VERSION.startswith("OpenSSL 1.1.")
        assert hashlib.sha256("abc").hexdigest() == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        print "modules"
        PY
      '';
      expected = "modules";
    };
    development = {
      script = ''
        test "$(python2.7-config --prefix)" = "${package}"
        test "$(pkg-config --modversion python-2.7)" = 2.7
        cat > embed.c <<'EOF'
        #include <Python.h>
        int main(void) {
          Py_Initialize();
          int result = PyRun_SimpleString("print 42");
          Py_Finalize();
          return result;
        }
        EOF
        "$CC" $(python2.7-config --includes) embed.c $(pkg-config --libs python-2.7) -o embed
        ./embed
      '';
      expected = "42";
    };
  };
}

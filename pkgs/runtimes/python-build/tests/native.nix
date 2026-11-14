{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  inherit (pkgs) lib;
  spec = package.specification;
in
package.testContext.mkSuite {
  inherit package;
  tools = spec.environment.tools;
  libraries = [ package ];
  tests = {
    customization = {
      script = "echo customization";
      expected = import ./customization.nix { inherit package; };
    };
    steps-replacement = {
      script =
        let
          control = package.edit (
            s:
            builtins.removeAttrs s [ "artifactName" ]
            // {
              plan = [
                {
                  name = "contract.probe";
                  run = ''mkdir -p "$out"; printf '%s\n' 'edited plan executed' > "$out/marker"'';
                }
              ];
            }
          );
        in
        ''cat ${control}/marker'';
      expected = "edited plan executed";
    };
    version = {
      script = "python3 -I -c 'import platform; print(platform.python_version())'";
      expected = package.version;
    };
    stdlib = {
      script = ''python3 -I ${./fixtures/archives.py}'';
      expected = "42";
    };
    subprocess = {
      script = ''env -i ${package}/bin/python3 -I -c 'import subprocess; assert subprocess.check_output("printf 42", shell=True, text=True) == "42"; print("42")' '';
      expected = "42";
    };
    profile = {
      script = ''python3 -I -c 'import importlib.util, sys; assert all(importlib.util.find_spec(m) is None for m in sys.argv[1:]); assert importlib.util.find_spec("pip") is None; assert importlib.util.find_spec("_testcapi") is None; print("profile")' ${lib.escapeShellArgs package.tvp.disabledModules}'';
      expected = "profile";
    };
    embed = {
      script = ''
        cc ${./fixtures/embed.c} $(python3-config --cflags --embed --ldflags) -o embed
        ./embed
      '';
      expected = "42";
    };
    development = {
      script = ''
        printf '%s\n' '#include <Python.h>' 'static PyObject *answer(PyObject *s, PyObject *args) {return PyLong_FromLong(42);}' 'static PyMethodDef methods[]={{"answer",answer,METH_NOARGS,NULL},{NULL,NULL,0,NULL}};' 'static struct PyModuleDef module={PyModuleDef_HEAD_INIT,"tvp_probe",NULL,-1,methods};' 'PyMODINIT_FUNC PyInit_tvp_probe(void){return PyModule_Create(&module);}' > probe.c
        suffix=$(python3 -I -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')
        cc -shared -fPIC $(python3-config --includes) probe.c -o "tvp_probe$suffix"
        python3 -I -c 'import sys; sys.path.insert(0,"."); import tvp_probe; assert tvp_probe.answer()==42; print("42")'
        test -f ${package}/lib/libpython3.12.a
        test -f ${package}/include/python3.12/Python.h
      '';
      expected = "42";
    };
    glibc-generator = {
      tools = [
        spec.tools.gnutar
        spec.tools.xz
      ];
      script = ''
        tar -xJf ${tvp.packages.glibc_2_39.src} --strip-components=2 glibc-2.39/scripts/gen-as-const.py glibc-2.39/scripts/glibcextract.py
        printf '%s\n' '#include <limits.h>' 'TVP_INTMAX INT_MAX' > constants.sym
        python3 gen-as-const.py --cc "$CC" constants.sym > constants.h
        test "$(cat constants.h)" = '#define TVP_INTMAX 2147483647'
        echo generator
      '';
      expected = "generator";
    };
    configuration = {
      script = ''
        env -i ${package}/bin/python3-config --prefix > prefix
        test "$(cat prefix)" = ${package}
        python3 -I -c 'import sysconfig,sys; assert sysconfig.get_config_var("prefix")==sys.prefix; assert sysconfig.get_config_var("LIBPL").startswith(sys.prefix); print("config")'
        test -r ${package}/share/licenses/python/LICENSE
      '';
      expected = "config";
    };
    archives = {
      script = ''python3 -I ${./fixtures/archives.py}'';
      expected = "42";
    };
    upstream-ssl = {
      script = ''
        mkdir result evidence
        python3 -I ${../../../../bootstrap/source-python-compat-checks.py} "$PWD/result" "$PWD/evidence" ${
          lib.escapeShellArg (
            builtins.toJSON {
              openssl = "${package.runtime.openssl}/bin/openssl";
              python = toString package;
              source = toString package.src;
            }
          )
        } > upstream.log 2>&1 || { status=$?; cat upstream.log >&2; exit "$status"; }
        cat upstream.log >&2
        test -f result/result
        echo upstream-ssl
      '';
      expected = "upstream-ssl";
    };
    tls-eof = {
      tools = [ package.runtime.openssl ];
      script = ''python3 -I ${./tls-eof.py} ${package.runtime.openssl}'';
      expected = "TLS EOF: strict/suppressed for TLS1.2/TLS1.3";
    };
    tls = {
      tools = [ package.runtime.openssl ];
      script = ''python3 -I ${./tls.py} ${package.runtime.openssl}'';
      expected = "TLS verified: OpenSSL 3.6.3; trusted/untrusted/wrong-host; fixed TLS1.2; decode";
    };
  };
}

{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''python3 -c 'import platform; print(platform.python_version())' '';
      expected = package.version;
    };
    profile = {
      script = ''
        python3 -c 'import importlib.util, ssl, hashlib, zlib, bz2, lzma, sys; assert all(importlib.util.find_spec(m) is None for m in sys.argv[1:]); assert ssl.create_default_context().verify_mode == ssl.CERT_REQUIRED; assert hashlib.sha256(b"42").hexdigest().startswith("73475"); print("build-tools")' ${pkgs.lib.escapeShellArgs package.tvp.disabledModules}
      '';
      expected = "build-tools";
    };
    archives = {
      script = ''python3 ${./fixtures/archives.py}'';
      expected = "42";
    };
    subprocess = {
      script = ''python3 -c 'import subprocess; print(subprocess.check_output("printf 42", shell=True, text=True))' '';
      expected = "42";
    };
    embed = {
      script = ''
        cc ${./fixtures/embed.c} $(python3-config --cflags --embed --ldflags) -o embed
        ./embed
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
  };
}

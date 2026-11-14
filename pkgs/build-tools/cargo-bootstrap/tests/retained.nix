{
  pkgs,
  tvpLib,
  package,
  rustc,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''cargo --version | awk '{print $2}' '';
      expected = package.version;
    };
    offline = {
      script = ''
        export CARGO_HOME="$PWD/cache" CARGO_NET_OFFLINE=true
        cargo new --vcs none --bin hello
        cd hello
        cargo run --offline --quiet
      '';
      expected = "Hello, world!";
      extraInputs = [ rustc ];
    };
  };
}

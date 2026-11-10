{ package }:
let
  s = package.specification;
  rustc = package.tvp.declaredTestDependencies.rustc;
in
package.testContext.mkSuite {
  inherit package;
  tests = {
    version = {
      script = ''cargo --version | ${s.gawk}/bin/awk '{print $2}' '';
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
      tools = [ rustc ];
    };
  };
}

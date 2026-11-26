# Installed application behavior, independent of any private application.
{
  tvp,
  bundle,
  name,
}:
let
  ruby = bundle.ruby;
  base = ruby.specification.base;
  arguments = {
    inherit tvp bundle;
    name = "synthetic-application-${name}";
    version = "1";
    src = ./fixtures/application;
    commands = {
      answer = [
        "ruby"
        "app.rb"
      ];
      manager = [
        "bundle"
        "--version"
      ];
    };
    environment = {
      TVP_EXPECTED_RUBY = ruby.version;
      TVP_EXPECTED_BUNDLER = bundle.bundler.version;
      TVP_APP_MODE = "build and runtime default";
      TVP_APP_LITERAL = "literal ' quote; $HOME $(touch never-executed)";
    };
    buildScript = "ruby build.rb";
  };
  application = tvp.lib.ruby.application arguments;
  badName = tvp.lib.ruby.application (arguments // { commands."../escape" = [ "ruby" ]; });
  badExecutable = tvp.lib.ruby.application (arguments // { commands.answer = [ "../ruby" ]; });
  badEnvironment = tvp.lib.ruby.application (arguments // { environment."INVALID-NAME" = "x"; });
in
assert application.tvpInventory.schema == 1;
assert application.tvpInventory.packages.runtime.drvPath == bundle.ruby.drvPath;
assert application.tvpInventory.packages.manager.drvPath == bundle.bundler.drvPath;
assert !(builtins.tryEval badName.drvPath).success;
assert !(builtins.tryEval badExecutable.drvPath).success;
assert !(builtins.tryEval badEnvironment.drvPath).success;
ruby.testContext.mkTest {
  package = application;
  name = "application";
  tools = [
    bundle
    base.tools.diffutils
  ];
  script = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME" unrelated hostile-bin
    printf '%s\n' '#!${base.shell}/bin/bash' 'exit 98' > hostile-bin/ruby
    cp hostile-bin/ruby hostile-bin/bundle
    chmod +x hostile-bin/ruby hostile-bin/bundle
    export PATH="$PWD/hostile-bin:$PATH"
    cd unrelated
    unset TVP_APP_MODE TVP_APP_LITERAL
    ${application}/bin/answer 'argument with spaces' '$(touch injected)' "single'quote" '; exit 99' > result.json
    ${bundle}/bin/ruby -rjson -e '
      result = JSON.parse(File.read("result.json"))
      abort "Wrong arguments" unless result.fetch("arguments") == ["argument with spaces", %q{$(touch injected)}, "single\u0027quote", "; exit 99"]
      abort "Wrong Ruby" unless result.fetch("ruby") == ARGV[0]
      abort "Wrong Bundler" unless result.fetch("bundler") == ARGV[1]
      abort "Wrong gem activation" unless result.fetch("answer") == [42, 42]
      abort "Asset build did not transform source" unless result.fetch("asset") == "SYNTHETIC SOURCE: 42\ngem answer: 42\n"
      abort "Missing default environment" unless result.fetch("mode") == "build and runtime default"
      abort "Environment value was interpreted as shell code" unless result.fetch("literal") == "literal \u0027 quote; $HOME $(touch never-executed)"
    ' ${ruby.version} ${bundle.bundler.version}
    test ! -e injected
    test ! -e never-executed
    test "$(${application}/bin/manager)" = 'Bundler version ${bundle.bundler.version}'
    export TVP_APP_MODE="caller override with spaces" TVP_APP_LITERAL=""
    ${application}/bin/answer > override.json
    ${bundle}/bin/ruby -rjson -e '
      result = JSON.parse(File.read("override.json"))
      abort "Runtime environment override ignored" unless result.fetch("mode") == "caller override with spaces" && result.fetch("literal") == ""
    '
    if ${application}/bin/answer exit 17; then
      echo "Application exit status was lost" >&2
      exit 1
    else
      test "$?" = 17
    fi
    cmp ${bundle}/project/Gemfile ${application.applicationDirectory}/Gemfile
    cmp ${bundle}/project/Gemfile.lock ${application.applicationDirectory}/Gemfile.lock
    test ! -e ${./fixtures/application}/public/message.txt
    printf application-ok
  '';
  expected = "application-ok";
}

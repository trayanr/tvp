{
  pkgs,
  tvpLib,
  package,
}:
let
  source = pkgs.lib.fileset.toSource {
    root = ./fixtures;
    fileset = pkgs.lib.fileset.unions [
      ./fixtures/settings.gradle
      ./fixtures/build.gradle
      ./fixtures/src/main/java/Main.java
    ];
  };
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''export GRADLE_USER_HOME="$TMPDIR/gradle"; gradle --offline --no-daemon --version | sed -n 's/^Gradle //p' '';
      expected = package.version;
    };
    project = {
      script = ''
        export GRADLE_USER_HOME="$TMPDIR/gradle" JAVA_HOME=${package.tvp.deps.jdk}
        cp -r ${source}/. .; chmod -R u+w .
        gradle --offline --no-daemon --console=plain clean check jar > build.log
        grep -q '^gradle-ok' build.log
        jar tf build/libs/tvp-gradle-fixture.jar | grep -q Main.class
        printf gradle-ok
      '';
      expected = "gradle-ok";
      extraInputs = [ package.tvp.deps.jdk ];
    };
    wrapper = {
      script = ''
        export GRADLE_USER_HOME="$TMPDIR/gradle" JAVA_HOME=${package.tvp.deps.jdk}
        cp -r ${source}/. .; chmod -R u+w .
        gradle --offline --no-daemon --console=plain wrapper > wrapper.log
        patchShebangs gradlew >&2
        tvp-gradle-seed-wrapper
        ./gradlew --offline --no-daemon --console=plain check > build.log
        grep -q '^gradle-ok' build.log
        printf wrapper-offline
      '';
      expected = "wrapper-offline";
      extraInputs = [ package.tvp.deps.jdk ];
    };
  };
}

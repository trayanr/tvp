{
  pkgs,
  tvpLib,
  tvp,
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
package.testContext.mkSuite {
  inherit package;
  tools = [
    package.specification.python
    package.tvp.declaredTestDependencies.grep
  ];
  tests = {
    helper-safety = {
      script = ''${package.specification.python}/bin/python3 -B ${./test_helpers.py} ${package}/bin/tvp-gradle-seed-wrapper ${../native/render.py} >&2; printf helpers-safe'';
      expected = "helpers-safe";
    };
    distribution = {
      script = ''
        ${package.specification.python}/bin/python3 -c "import hashlib; from pathlib import Path; a=Path('${package.distributionArchive}'); assert a.read_bytes()==Path('${package.src}').read_bytes(); assert hashlib.sha256(a.read_bytes()).hexdigest()=='17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43'; s=Path('${package}/bin/gradle').read_text(); assert 'export JAVA_HOME=${package.specification.runtime.jdk}' in s; assert ':\$PATH' in s"
        printf distribution-ok
      '';
      expected = "distribution-ok";
    };
    provider = {
      script = ''test "$GRADLE_HOME" = ${package}/libexec/gradle; test -f "$GRADLE_HOME/lib/gradle-launcher-${package.version}.jar"; printf provider-ok'';
      expected = "provider-ok";
    };
    version = {
      script = ''export GRADLE_USER_HOME="$TMPDIR/gradle"; gradle --offline --no-daemon --version | ${package.specification.python}/bin/python3 -c "import sys; print(next(x.strip().removeprefix('Gradle ') for x in sys.stdin if x.startswith('Gradle ')))" '';
      expected = package.version;
    };
    project = {
      script = ''
        export GRADLE_USER_HOME="$TMPDIR/gradle" JAVA_HOME=${package.tvp.deps.jdk}
        cp -r ${source}/. .; chmod -R u+w .
        gradle --offline --no-daemon --console=plain clean check jar > build.log
        grep -q '^gradle-ok' build.log
        jar tf build/libs/tvp-gradle-fixture.jar > jar.list
        grep -q Main.class jar.list
        printf gradle-ok
      '';
      expected = "gradle-ok";
      tools = [
        package.tvp.deps.jdk
        package.tvp.declaredTestDependencies.grep
        package.tvp.declaredTestDependencies.sed
        package.tvp.declaredTestDependencies.findutils
        package.specification.helperPython
      ];
    };
    wrapper = {
      script = ''
        export GRADLE_USER_HOME="$TMPDIR/gradle" JAVA_HOME=${package.tvp.deps.jdk}
        cp -r ${source}/. .; chmod -R u+w .
        gradle --offline --no-daemon --console=plain wrapper > wrapper.log
        ${package.specification.helperPython}/bin/python3 -c "from pathlib import Path; p=Path('gradlew'); s=p.read_text(); assert s.startswith('#!/bin/sh\n'); p.write_text(s.replace('#!/bin/sh', '#!${package.specification.runtime.shell}/bin/bash', 1))"
        tvp-gradle-seed-wrapper
        ./gradlew --offline --no-daemon --console=plain check > build.log
        grep -q '^gradle-ok' build.log
        printf wrapper-offline
      '';
      expected = "wrapper-offline";
      tools = [
        package.tvp.deps.jdk
        package.tvp.declaredTestDependencies.grep
        package.tvp.declaredTestDependencies.sed
        package.tvp.declaredTestDependencies.findutils
        package.specification.helperPython
      ];
    };
  };
}

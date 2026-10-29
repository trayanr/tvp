{
  pkgs,
  tvpLib,
  package,
}:
let
  closure = pkgs.closureInfo { rootPaths = [ package ]; };
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests =
    {
      version = {
        script = ''java -XshowSettings:properties -version 2>&1 | awk '$1=="java.version" {print $3}' '';
        expected = package.version;
      };
      runtime = {
        script = ''cp ${./fixtures/RuntimeCheck.java} RuntimeCheck.java; javac RuntimeCheck.java -d .; java -Djava.awt.headless=true RuntimeCheck'';
        expected = "runtime-ok";
      };
      native = {
        script = ''
          cp ${./fixtures/NativeCheck.java} NativeCheck.java
          javac -h . -d . NativeCheck.java
          cc -shared -fPIC -I${package}/include -I${package}/include/linux -I. ${./fixtures/native.c} -o libanswer.so
          java -Djava.library.path="$PWD" NativeCheck
        '';
        expected = "42";
        extraInputs = [ package.tvp.cc ];
      };
      shell = {
        script = ''cp ${./fixtures/ShellCheck.java} ShellCheck.java; javac ShellCheck.java -d .; export PATH="$PWD:$PATH"; java ShellCheck '${package.tvp.deps.bash}/bin/bash' '';
        expected = "shell-ok";
      };
      shell-fork = {
        script = ''cp ${./fixtures/ShellCheck.java} ShellCheck.java; javac ShellCheck.java -d .; export PATH="$PWD:$PATH"; java -Djdk.lang.Process.launchMechanism=FORK ShellCheck '${package.tvp.deps.bash}/bin/bash' '';
        expected = "shell-ok";
      };
      image = {
        script = ''
          cp ${./fixtures/NativeCheck.java} NativeCheck.java
          javac NativeCheck.java -d classes
          jar --create --file consumer.jar -C classes .
          jar --list --file consumer.jar | grep -q NativeCheck.class
          jlink --add-modules java.base,java.xml --strip-debug --no-man-pages --no-header-files --output image
          image/bin/java -XshowSettings:properties -version 2>&1 | awk '$1=="java.version" {print $3}'
        '';
        expected = package.version;
      };
      desktop = {
        script = ''
          mkdir fonts
          tar -xOf ${package.src} jdk21u-jdk-${package.version}-ga/src/demo/share/jfc/J2Ddemo/fonts/A.ttf > fonts/A.ttf
          printf '<fontconfig><dir>%s/fonts</dir><cachedir>%s/cache</cachedir></fontconfig>\n' "$PWD" "$TMPDIR" > fonts.conf
          export FONTCONFIG_FILE="$PWD/fonts.conf" XDG_CACHE_HOME="$TMPDIR/cache"
          cp ${./fixtures/DesktopCheck.java} DesktopCheck.java
          javac DesktopCheck.java -d .
          LD_DEBUG=libs java -Djava.awt.headless=true DesktopCheck fonts/A.ttf 2> libraries.log
          grep 'calling init:' libraries.log | grep -F '${package.tvp.deps.fontconfig}/lib/libfontconfig.so' >&2
          grep 'calling init:' libraries.log | grep -F '${package.tvp.deps.libcups}/lib/libcups.so' >&2
        '';
        expected = "desktop-headless-ok";
      };
      package-image = {
        script = ''
          cp ${./fixtures/PackageCheck.java} PackageCheck.java
          javac PackageCheck.java -d classes
          mkdir input
          jar --create --file input/consumer.jar --main-class PackageCheck -C classes .
          jlink --add-modules java.base --output runtime
          jpackage --type app-image --runtime-image "$PWD/runtime" --input input \
            --main-jar consumer.jar --name TvpConsumer --dest image
          image/TvpConsumer/bin/TvpConsumer
        '';
        expected = "packaged-42";
      };
    }
    // pkgs.lib.optionalAttrs (package.tvp.features.trimmedRuntime or false) {
      runtime-closure = {
        script = ''
          for path in ${pkgs.lib.escapeShellArgs (map (p: "${p}") package.tvp.runtimeForbiddenReferences)}; do
            if grep -Fx "$path" ${closure}/store-paths; then
              echo "build-only input retained by JDK: $path" >&2
              exit 1
            fi
          done
          printf runtime-closure-clean
        '';
        expected = "runtime-closure-clean";
      };
    };
}

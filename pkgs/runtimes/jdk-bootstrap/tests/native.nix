{ package }:
let
  s = package.specification;
in
package.testContext.mkSuite {
  inherit package;
  tests = {
    version = {
      script = ''java -XshowSettings:properties -version 2>&1 | ${s.gawk}/bin/awk '$1=="java.version" {print $3}' '';
      expected = package.version;
    };
    compiler = {
      script = ''cp ${./fixtures/Hello.java} Hello.java; javac Hello.java -d .; java Hello'';
      expected = "42";
    };
    headless = {
      script = ''
        mkdir fonts
        ${s.tar}/bin/tar --use-compress-program=${s.gzip}/bin/gzip -xOf ${package.tvp.declaredTestDependencies.fontArchive} jdk21u-jdk-${package.version}-ga/src/demo/share/jfc/J2Ddemo/fonts/A.ttf > fonts/A.ttf
        printf '<fontconfig><dir>%s/fonts</dir><cachedir>%s/cache</cachedir></fontconfig>\n' "$PWD" "$TMPDIR" > fonts.conf
        export FONTCONFIG_FILE="$PWD/fonts.conf" XDG_CACHE_HOME="$TMPDIR/cache"
        cp ${./fixtures/Headless.java} Headless.java
        javac Headless.java
        LD_DEBUG=libs java -Djava.awt.headless=true Headless 2> libraries.log
        ${s.grep}/bin/grep 'calling init:' libraries.log | ${s.grep}/bin/grep -F '${s.runtime.fontconfig}/lib/libfontconfig.so' >&2
        test ! -e ${package}/lib/libawt_xawt.so
      '';
      expected = "headless";
    };
    self-runtime = {
      script = ''
        for path in bin/java bin/javac lib/libjava.so lib/server/libjvm.so; do
          value=$(${s.patchelf}/bin/patchelf --print-rpath "${package}/$path")
          case ":$value:" in *":${package}/lib:"*) ;; *) exit 1 ;; esac
          case ":$value:" in *":${package}/lib/server:"*) ;; *) exit 1 ;; esac
        done
        echo ok
      '';
      tools = [ s.patchelf ];
      expected = "ok";
    };
  };
}

{
  package,
  lib,
  context,
}:
let
  zip = package.tvp.declaredTestDependencies.zip;
in
context.mkSuite {
  inherit package;
  tests = {
    version = {
      script = ''
        banner=$(unzip -v)
        case "$banner" in
          ${lib.escapeShellArg "UnZip ${package.version} "}*) printf '%s' ${lib.escapeShellArg package.version} ;;
          *) printf '%s\n' "$banner" >&2; exit 1 ;;
        esac
      '';
      expected = package.version;
    };
    roundtrip = {
      tools = [ zip ];
      script = ''
        printf 'preserved\n' > payload
        zip -q -P secret archive.zip payload
        unzip -P secret -t archive.zip >&2
        unzip -P secret -p archive.zip payload > restored
        cmp payload restored
        if unzip -P incorrect -p archive.zip payload > wrong 2> wrong.log; then exit 1; fi
        test ! -s wrong
        cat restored
      '';
      expected = "preserved";
    };
    helpers = {
      tools = [
        zip
        package.specification.base.tools.grep
        package.specification.base.tools.sed
      ];
      script = ''
        for cmd in unzip funzip unzipsfx zipgrep zipinfo; do
          test -x ${package}/bin/$cmd
          test -s ${package}/share/man/man1/$cmd.1.gz
        done
        test ${package}/bin/unzip -ef ${package}/bin/zipinfo
        test "$(head -n1 ${package}/bin/zipgrep)" = '#!${package.specification.runtime.shell}/bin/bash'
        printf 'preserved\n' > payload
        zip -q archive.zip payload
        funzip archive.zip > streamed
        cmp payload streamed
        zipgrep -h preserved archive.zip > found
        cmp payload found
        test "$(zipinfo -1 archive.zip)" = payload
        cat ${package}/bin/unzipsfx archive.zip > sfx
        chmod +x sfx
        mkdir extracted
        (cd extracted; ../sfx -q) >&2
        cmp payload extracted/payload
        printf helpers-ok
      '';
      expected = "helpers-ok";
    };
  };
}

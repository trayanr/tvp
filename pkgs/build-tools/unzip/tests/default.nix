{
  pkgs,
  tvpLib,
  package,
  zip,
}:
let
  d = package.tvp.deps;
  mkSuite =
    args:
    package.testContext.mkSuite {
      inherit package;
      tests = builtins.mapAttrs (_: spec: {
        inherit (spec) script expected;
        tools = (spec.extraInputs or [ ]) ++ [
          d.gawk
          d.gnugrep
          d.gnused
          d.diffutils
        ];
      }) args.tests;
    };
in
mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''unzip -v | awk 'NR==1 {print $2}' '';
      expected = "6.00";
    };
    roundtrip = {
      script = ''
        mkdir input output
        printf preserved > input/hello.txt
        dd if=/dev/zero of=input/large bs=1024 count=128 2>/dev/null
        zip -q -r archive.zip input
        unzip -t archive.zip > integrity
        unzip -q archive.zip -d output
        cmp input/hello.txt output/input/hello.txt
        cmp input/large output/input/large
        cat output/input/hello.txt
      '';
      expected = "preserved";
      extraInputs = [ zip ];
    };
    archive-features = {
      script = ''
        printf preserved > payload
        dd if=/dev/zero of=large bs=1024 count=128 2>/dev/null
        zip -q -P secret encrypted.zip payload large
        unzip -P secret -t encrypted.zip >&2
        unzip -P secret -p encrypted.zip payload > decrypted
        cmp payload decrypted
        unzip -P secret -p encrypted.zip large > decrypted-large
        cmp large decrypted-large
        status=0
        unzip -P wrong -p encrypted.zip payload > wrong 2> wrong.log || status=$?
        test "$status" != 0
        test ! -s wrong
        zip -q -fz - payload < /dev/null > zip64.zip
        unzip -t zip64.zip >&2
        unzip -p zip64.zip payload > zip64-payload
        cmp payload zip64-payload
        python3 ${./features.py} zip64.zip
        ln -s payload link
        printf unicode > ü.txt
        zip -q -y paths.zip payload link ü.txt
        unzip -q paths.zip -d restored
        test "$(readlink restored/link)" = payload
        cmp payload restored/link
        cmp ü.txt restored/ü.txt
        printf archive-features-ok
      '';
      expected = "archive-features-ok";
      extraInputs = [
        zip
        d.python
      ];
    };
    installed-layout = {
      script = ''
        for cmd in unzip funzip unzipsfx zipgrep zipinfo; do test -x ${package}/bin/$cmd; done
        for man in unzip funzip unzipsfx zipgrep zipinfo; do test -s ${package}/share/man/man1/$man.1.gz; done
        test "$(cat ${package}/nix-support/source-shell)" = '#!${package.specification.bash}/bin/bash'
        test "$(cat ${package}/nix-support/make-shell)" = '${package.specification.bash}/bin/bash'
        grep -F -- '-DLARGE_FILE_SUPPORT' ${package}/nix-support/flags >&2
        env -i ${package}/bin/unzip -v > version
        for feature in LARGE_FILE_SUPPORT ZIP64_SUPPORT UNICODE_SUPPORT; do grep -F "$feature" version >&2; done
        ${d.binutils}/bin/readelf -d ${package}/bin/unzip > dynamic
        ${d.patchelf}/bin/patchelf --print-interpreter ${package}/bin/unzip > interpreter
        test "$(cat interpreter)" = '${package.compiler.libc}/lib/ld-linux-x86-64.so.2'
        env -i LD_DEBUG=libs ${package}/bin/unzip -v > /dev/null 2> loader
        test "$(head -n1 ${package}/bin/zipgrep)" = '#!${package.specification.runtime.shell}/bin/bash'
        test ${package}/bin/unzip -ef ${package}/bin/zipinfo
        cmp ${../setup-hook.sh} ${package}/nix-support/setup-hook
        if grep -F libbz2 dynamic; then exit 1; fi
        if grep -F BZIP2_SUPPORT version; then exit 1; fi
        printf installed-layout-ok
      '';
      expected = "installed-layout-ok";
      extraInputs = [
        d.binutils
        d.patchelf
      ];
    };
    helpers = {
      script = ''
        printf 'preserved\n' > payload
        zip -q single.zip payload
        funzip single.zip > streamed
        cmp payload streamed
        zipgrep -h preserved single.zip > found
        cmp payload found
        zipinfo -1 single.zip > names
        test "$(cat names)" = payload
        cat ${package}/bin/unzipsfx single.zip > sfx
        chmod +x sfx
        mkdir extracted
        ( cd extracted; ../sfx -q ) >&2
        cmp payload extracted/payload
        printf helpers-ok
      '';
      expected = "helpers-ok";
      extraInputs = [ zip ];
    };
    upstream-record = {
      script = ''
        test "$(grep -c '#####  testing' ${
          (import ../native/upstream.nix { inherit package; }).passthru.upstreamExecution
        }/raw/upstream-check.log)" = 6
        test "$(cat ${
          (import ../native/upstream.nix { inherit package; }).passthru.upstreamExecution
        }/raw/upstream-check.status)" = 0
        test "$(cat ${
          (import ../native/upstream.nix { inherit package; }).passthru.upstreamExecution
        }/raw/upstream-strict.status)" = 0
        test "$(grep -c '#####  WARNING:' ${
          (import ../native/upstream.nix { inherit package; }).passthru.upstreamExecution
        }/raw/upstream-check.log)" = 0
        grep -F 'FIXTURE-PORT: 1998 zipinfo expectation adapted before comparison' ${
          (import ../native/upstream.nix { inherit package; }).passthru.upstreamExecution
        }/raw/upstream-qualification >&2
        printf upstream-unix-check-qualified
      '';
      expected = "upstream-unix-check-qualified";
    };
  };
}

// (
  if
    (package ? specification)
    && (package.specification ? upstreamPlan)
    && (package.specification.upstreamCheck.enabled or true)
  then
    {
      # Independent native upstream registration.
      upstream = import ../native/upstream.nix { package = package; };
    }
  else
    { }
)

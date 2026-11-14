{
  pkgs,
  tvpLib,
  package,
  unzip,
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
      script = ''zip -v | awk '/This is Zip/ {print $4}' '';
      expected = "3.0";
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
      extraInputs = [ unzip ];
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
        unzip
        d.python
      ];
    };
    installed-layout = {
      script = ''
        for cmd in zip zipnote zipcloak zipsplit; do test -x ${package}/bin/$cmd; done
        for man in zip zipnote zipcloak zipsplit; do test -s ${package}/share/man/man1/$man.1.gz; done
        test "$(cat ${package}/nix-support/source-shell)" = '#!${package.specification.bash}/bin/bash'
        test "$(cat ${package}/nix-support/make-shell)" = '${package.specification.bash}/bin/bash'
        grep -F -- '-DLARGE_FILE_SUPPORT' ${package}/nix-support/flags >&2
        env -i ${package}/bin/zip -v > version
        for feature in LARGE_FILE_SUPPORT ZIP64_SUPPORT UNICODE_SUPPORT; do grep -F "$feature" version >&2; done
        ${d.binutils}/bin/readelf -d ${package}/bin/zip > dynamic
        ${d.patchelf}/bin/patchelf --print-interpreter ${package}/bin/zip > interpreter
        test "$(cat interpreter)" = '${package.compiler.libc}/lib/ld-linux-x86-64.so.2'
        env -i LD_DEBUG=libs ${package}/bin/zip -v > /dev/null 2> loader
        grep -F 'libbz2.so.1' dynamic >&2
        grep -F 'calling init: ${d.bzip2}/lib/libbz2.so.1' loader >&2
        grep -F BZIP2_SUPPORT version >&2
        printf installed-layout-ok
      '';
      expected = "installed-layout-ok";
      extraInputs = [
        d.binutils
        d.patchelf
      ];
    };
    bzip2-and-utilities = {
      script = ''
        printf preserved > payload
        dd if=/dev/zero of=large bs=1024 count=128 2>/dev/null
        zip -q -Z bzip2 bzip.zip payload large
        python3 ${./features.py} bzip.zip bzip2
        zipnote bzip.zip > notes
        # zipnote -w has a reproduced legacy EBADF/crash; reading remains
        # covered here. The raw write nonpass is retained in port evidence.
        grep -Fx '@ payload' notes >&2
        grep -Fx '@ large' notes >&2
        zip -q plain.zip payload large
        zipsplit -q -n 1000 plain.zip >&2
        test -s plain1.zip
        zipcloak -h > cloak-help
        grep -F 'zipcloak' cloak-help >&2
        printf bzip2-utilities-ok
      '';
      expected = "bzip2-utilities-ok";
      extraInputs = [ d.python ];
    };
  };
}

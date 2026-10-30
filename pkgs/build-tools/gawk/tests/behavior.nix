{
  pkgs,
  tvpLib,
  package,
}:
let
  inherit (pkgs) lib;
  atLeast = lib.versionAtLeast package.version;
  awk = "${package}/bin/gawk";
  utf8 = ''
    export LOCPATH=${package.stdenv.cc.libc}/lib/locale LC_ALL=C.utf8
    test "$(${awk} 'BEGIN {print length("σςΣ")}')" = 3
  '';
  # Unlike mkTest's scalar output, these results retain conditional coverage and logs.
  recorded =
    name: script:
    pkgs.runCommand "gawk-${package.version}-${name}"
      {
        nativeBuildInputs = [ package ];
        passthru = {
          inherit package;
          testName = name;
        };
      }
      ''
        set -euo pipefail
        mkdir "$out"
        exec > "$out/log" 2>&1
        ${script}
      '';
in
(tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests =
    {
      printf = {
        script = ''
          ${awk} 'BEGIN {printf "[%*.*f] [%s] [%d] [%x]\n", 8, 3, 1.25, "a%b", -17, 255; print sprintf("%.0f %.2f", 2.5, -0.125)}'
        '';
        expected = "[   1.250] [a%b] [-17] [ff]\n2 -0.12";
      };
      posix-regex = {
        script = ''
          ${awk} --posix 'BEGIN {print match("xabbbz", /a(b|bb)*/), RSTART, RLENGTH; print ("ab" ~ /^(a|ab)$/)}'
        '';
        expected = "2 2 4\n1";
      };
    }
    // lib.optionalAttrs (atLeast "3.1") {
      regex-submatches = {
        script = ''
          ${awk} 'BEGIN {match("aa", /(a|aa)(a?)/, a); printf "<%s><%s><%s>\n",a[0],a[1],a[2]}'
        '';
        expected = if atLeast "5.4" then "<aa><aa><>" else "<aa><a><a>";
      };
    }
    // lib.optionalAttrs package.tvp.features.bignum {
      mpfr-precision = {
        script = ''
          ${awk} -M 'BEGIN {PREC=256; x=2^128; d=sqrt(2)^2-2; print (x+1 != x), ((x+1)-x == 1), (d > -1e-70 && d < 1e-70)}'
        '';
        expected = "1 1 1";
      };
    }
    // lib.optionalAttrs (atLeast "4.1") {
      extension-api = {
        extraInputs = [ package.tvp.cc ];
        script = ''
          cc -Wall -Werror=incompatible-pointer-types -shared -fPIC -I${package}/include ${./extension.c} -o probe.so
          ${awk} -l "$PWD/probe.so" 'BEGIN {print tvp_api()}'
        '';
        expected =
          if atLeast "5.3" then
            "4"
          else if atLeast "5.1" then
            "3"
          else if atLeast "4.2" then
            "2"
          else
            "1";
      };
    }
    // lib.optionalAttrs (atLeast "5.3") {
      csv = {
        script = ''
          printf 'name,note,value\r\n"a,b","say ""hi""",7\r\n"two\nlines","x\r\ny",8\r\n' > input.csv
          ${awk} --csv '{printf "%d|%d|%s|%s|%s\n", NR,NF,$1,$2,$3} END {print "CSV", ("CSV" in PROCINFO)}' input.csv
        '';
        expected = "1|3|name|note|value\n2|3|a,b|say \"hi\"|7\n3|3|two\nlines|x\ny|8\nCSV 1";
      };
      unicode-escape = {
        script =
          utf8
          + ''
            ${awk} 'BEGIN {print "\u03c3" == "σ", length("\u03c3"), toupper("\u03c3")}'
          '';
        expected = "1 1 Σ";
      };
    }
    // lib.optionalAttrs (atLeast "5.4") {
      gnu-matchers = {
        script = ''
          GAWK_GNU_MATCHERS=1 ${awk} 'BEGIN {match("aa", /(a|aa)(a?)/, a); printf "<%s><%s><%s>\n",a[0],a[1],a[2]}'
          GAWK_GNU_MATCHERS=1 ${awk} --posix 'BEGIN {print match("xabbbz", /a(b|bb)*/), RSTART, RLENGTH}'
        '';
        expected = "<aa><a><a>\n2 2 4";
      };
      release54 = {
        script = ''
          ${awk} --posix 'BEGIN {a[1]=1; a[2]=2; print length(a)}'
          ${awk} 'BEGIN {print lshift(1,64), rshift(8,64), 0x1.8p+1, strtonum("0x1.8p+1")}'
          printf 'function value() { return 42 }\n' > included.awk
          printf '@namespace "probe"\n@nsinclude "included.awk"\nBEGIN {print value()}\n' > main.awk
          AWKPATH="$PWD" ${awk} -f main.awk
          printf 'a--b' | ${awk} --traditional 'BEGIN {RS="--"} {print $0}'
        '';
        expected = "2\n0 0 3 3\n42\na\nb";
      };
      sigma-folding = {
        script =
          utf8
          + ''
            ${awk} 'BEGIN {IGNORECASE=1; print ("σ" ~ /ς/), ("ς" ~ /σ/), ("Σ" ~ /ς/), ("ς" ~ /Σ/)}'
            GAWK_GNU_MATCHERS=1 ${awk} 'BEGIN {IGNORECASE=1; print ("σ" ~ /ς/), ("ς" ~ /σ/), ("Σ" ~ /ς/), ("ς" ~ /Σ/)}'
          '';
        # Observed in both packaged 5.4.0 and 5.4.1, not presumed fixed in 5.4.1.
        expected = "0 0 1 0\n1 1 1 1";
      };
    };
})
// lib.optionalAttrs (atLeast "5.2") {
  persistent-memory = recorded "persistent-memory" ''
    if ! ${awk} --version | grep -q PMA; then
      echo 'SKIP: build has no PMA support' | tee "$out/status"
      exit 0
    fi
    # A new, private backing file per invocation; never consume external files.
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    truncate -s 4M "$work/fresh.pma"
    set +e
    GAWK_PERSIST_FILE="$work/fresh.pma" ${awk} 'BEGIN {print ++counter}' > first 2> error
    result=$?
    set -e
    cat error
    if [ "$result" -ne 0 ]; then
      if grep -Eqi 'mmap|address|personality|Operation not permitted|not supported' error; then
        echo 'SKIP: PMA address layout or filesystem unavailable; see log' | tee "$out/status"
        exit 0
      fi
      exit "$result"
    fi
    test "$(cat first)" = 1
    GAWK_PERSIST_FILE="$work/fresh.pma" ${awk} 'BEGIN {print ++counter}' > second
    test "$(cat second)" = 2
    cat first second
    echo PASS | tee "$out/status"
  '';
}

{
  package,
  lib,
  context,
}:
let
  inherit (package.tvp) features;
  hasCompressedInput = features.grepGzip || features.grepBzip2;
in
context.mkSuite {
  inherit package;
  tools =
    package.specification.environment.tools
    ++ [ package.specification.base.compiler.bintools ]
    ++ lib.optional features.grepGzip package.tvp.declaredTestDependencies.gzip
    ++ lib.optional features.grepBzip2 package.specification.bzip2;
  tests = {
    version = {
      script = ''
        ${package}/bin/pcre2grep --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf 'preserved-42\n' | ${package}/bin/pcre2grep -o '[a-z]+(?=-[0-9]+)'
      '';
      expected = "preserved";
    };
  }
  // lib.optionalAttrs hasCompressedInput {
    compressed-input = {
      script = ''
        printf 'ignored\nmessage-42\n' > plain
      ''
      + lib.optionalString features.grepGzip ''
        gzip -c plain > input.gz
        test "$(${package}/bin/pcre2grep -o 'message-[0-9]+' input.gz)" = message-42
      ''
      + lib.optionalString features.grepBzip2 ''
        bzip2 -c plain > input.bz2
        test "$(${package}/bin/pcre2grep -o 'message-[0-9]+' input.bz2)" = message-42
      ''
      + "echo compressed-input";
      expected = "compressed-input";
    };
  }
  // lib.optionalAttrs features.testReadline {
    readline = {
      script = ''
        ${package}/bin/pcre2test -C | grep -Fx '  pcre2test has libreadline support' >&2
        LD_TRACE_LOADED_OBJECTS=1 ${package}/bin/pcre2test \
          | grep -F '${package.specification.readline}/lib/libreadline.so' >&2
        echo readline
      '';
      expected = "readline";
    };
  }
  // import ./installed-consumers.nix { inherit package lib context; }
  // {
    upstream-tags = {
      script =
        let
          upstream = import ../upstream.nix;
          tags = [
            "pcre2-10.00"
            "pcre2-10.49"
            "pcre2-10.49-RC1"
            "pcre2-10.50-dev"
            "pcre2-10.49^{}"
            "pcre2-10.49extra"
            "prefix-pcre2-10.49"
            "v10.49"
            "pcre2-10.49.1"
            "pcre2-10x49"
            "pcre2-10"
            ""
          ];
        in
        "printf '%s' " + lib.escapeShellArg (builtins.toJSON (map upstream.normalise tags));
      expected = ''["10.00","10.49",null,null,null,null,null,null,null,null,null,null]'';
    };
  };
}

// import ./installed-contract.nix { inherit package lib context; }

// lib.optionalAttrs package.specification.doCheck {
  upstream = import ./upstream.nix { inherit package lib context; };
}

{
  package,
  lib,
  context,
}:
let
  s = package.specification;
  tools = (
    builtins.removeAttrs s.base.tools [
      "gcc"
      "bash"
      "coreutils"
      "binutils"
    ]
  );
  commonTools = [
    tools.sed
    tools.grep
    tools.gawk
    tools.diffutils
    s.base.compiler.bintools
  ];

  custom =
    (
      ((package.override { doCheck = false; }).edit (
        s:
        s
        // {
          upstreamCheck = s.upstreamCheck // {
            run = throw "disabled upstream check was forced";
          };
        }
      )).editRuntime
      (runtime: runtime // { libraries = [ ]; })
    ).editSteps
      (
        plan:
        plan
        ++ [
          {
            name = "bzip2.consumer-marker";
            run = ''printf '%s\n' 'edited' > "$out/nix-support/consumer-marker"'';
          }
        ]
      );
in
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = commonTools;
  tests = {
    static-library = {
      tools = commonTools ++ [ s.base.compiler ];
      script = ''
        "$CC" ${./fixtures/shared-library.c} -I${package}/include ${package}/lib/libbz2.a -o consumer
        ./consumer ${package.version}
      '';
      expected = package.version;
    };
    shell-helpers = {
      script = ''
        printf 'helper-ok\n' > plain
        ${package}/bin/bzip2 -c plain > sample.bz2
        ${package}/bin/bzgrep helper sample.bz2
        ${package}/bin/bzcmp sample.bz2 plain
        ${package}/bin/bzdiff sample.bz2 sample.bz2
      '';
      expected = "helper-ok";
    };
    customization = {
      tools = commonTools ++ [ custom ];
      script = ''
        cat ${custom}/nix-support/consumer-marker
        printf 'custom-ok' | ${custom}/bin/bzip2 | ${custom}/bin/bunzip2
      '';
      expected = "edited\ncustom-ok";
    };
  };
}

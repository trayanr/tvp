{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  commonTools = with package.tvp.declaredDependencies; [
    sed
    grep
    gawk
    diffutils
    binutils
  ];

  custom =
    ((package.override { doCheck = false; }).editRuntime (runtime: runtime // { libraries = [ ]; }))
    .editSteps
      (
        plan:
        tvp.builder.steps.replace "bzip2.check" (
          old:
          old
          // {
            tools = throw "disabled Bzip2 check tools were forced";
            run = throw "disabled Bzip2 check command was forced";
          }
        ) plan
        ++ [
          {
            name = "bzip2.consumer-marker";
            run = ''printf '%s\n' 'edited' > "$out/nix-support/consumer-marker"'';
          }
        ]
      );
in
package.testContext.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = commonTools;
  tests = {
    static-library = {
      tools = commonTools ++ [ package.tvp.cc ];
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

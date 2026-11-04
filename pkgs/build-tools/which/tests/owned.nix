{
  pkgs,
  tvpLib,
  package,
}:
let
  make = package.tvp.declaredDependencies.gnumake;
  custom = (package.override { doCheck = false; }).editSteps (
    plan:
    plan
    ++ [
      {
        name = "which.consumer-marker";
        run = ''printf '%s\n' 'edited' > "$out/nix-support/consumer-marker"'';
      }
    ]
  );
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    alias = {
      script = ''
        printf "alias tvp='tvp-no-such-command --flag'\n" | which --read-alias tvp
      '';
      expected = "alias tvp='tvp-no-such-command --flag'";
    };
    make-consumer = {
      extraInputs = [ make ];
      script = ''
        printf 'all:\n\t@printf "consumer-ok\\n"\n' > Makefile
        found=$(PATH=${make}/bin ${package}/bin/which make)
        test "$found" = ${make}/bin/make
        "$found" --no-print-directory
      '';
      expected = "consumer-ok";
    };
    customization = {
      extraInputs = [ custom ];
      script = ''
        cat ${custom}/nix-support/consumer-marker
        mkdir discovery
        touch discovery/tvp-tool
        chmod +x discovery/tvp-tool
        PATH="$PWD/discovery" ${custom}/bin/which tvp-tool | sed "s|$PWD/||"
      '';
      expected = "edited\ndiscovery/tvp-tool";
    };
  };
}

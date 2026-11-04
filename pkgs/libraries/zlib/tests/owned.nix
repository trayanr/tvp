{
  pkgs,
  tvp,
  tvpLib,
  package,
  pkg-config,
}:
let
  custom = (package.override { doCheck = false; }).editSteps (
    plan:
    tvp.builder.steps.replace "zlib.check" (
      old:
      old
      // {
        tools = throw "disabled zlib check tools were forced";
        run = throw "disabled zlib check command was forced";
      }
    ) plan
    ++ [
      {
        name = "zlib.consumer-marker";
        run = ''printf '%s\n' 'edited' > "$out/nix-support/consumer-marker"'';
      }
    ]
  );
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    pkg-config-consumer = {
      extraInputs = [
        package.tvp.cc
        pkg-config
      ];
      script = ''
        unset NIX_CFLAGS_COMPILE NIX_CFLAGS_LINK NIX_LDFLAGS
        export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
        cc ${./fixtures/version.c} $(pkg-config --cflags --libs zlib) -Wl,-rpath,${package}/lib -o shared
        ./shared
        cc ${./fixtures/version.c} $(pkg-config --cflags zlib) -Wl,-Bstatic $(pkg-config --static --libs zlib) -Wl,-Bdynamic -o static
        ./static
      '';
      expected = "${package.version}\n${package.version}";
    };
    customization = {
      extraInputs = [
        package.tvp.cc
        custom
      ];
      script = ''
        cat ${custom}/nix-support/consumer-marker
        cc ${./fixtures/version.c} -I${custom}/include -L${custom}/lib -Wl,-rpath,${custom}/lib -lz -o consumer
        ./consumer
      '';
      expected = "edited\n${package.version}";
    };
  };
}

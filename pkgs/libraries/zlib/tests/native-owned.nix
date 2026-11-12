{
  pkgs,
  tvp,
  tvpLib,
  package,
  pkg-config,
}:
let
  commonTools = with package.tvp.declaredDependencies; [
    sed
    grep
    gawk
    diffutils
    binutils
  ];

  custom = (package.override { doCheck = false; }).editSteps (
    plan:
    plan
    ++ [
      {
        name = "zlib.consumer-marker";
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
    pkg-config-consumer = {
      tools = commonTools ++ [
        package.tvp.cc
        pkg-config
      ];
      script = ''
        unset NIX_CFLAGS_COMPILE NIX_CFLAGS_LINK NIX_LDFLAGS
        export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
        "$CC" ${./fixtures/version.c} $(pkg-config --cflags --libs zlib) -Wl,-rpath,${package}/lib -o shared
        ./shared
        "$CC" ${./fixtures/version.c} $(pkg-config --cflags zlib) -Wl,-Bstatic $(pkg-config --static --libs zlib) -Wl,-Bdynamic -o static
        ./static
      '';
      expected = "${package.version}\n${package.version}";
    };
    customization = {
      tools = commonTools ++ [
        package.tvp.cc
        custom
      ];
      script = ''
        cat ${custom}/nix-support/consumer-marker
        "$CC" ${./fixtures/version.c} -I${custom}/include -L${custom}/lib -Wl,-rpath,${custom}/lib -lz -o consumer
        ./consumer
      '';
      expected = "edited\n${package.version}";
    };
  };
}

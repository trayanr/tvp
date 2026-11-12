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

  custom =
    ((package.override { doCheck = false; }).edit (
      s:
      s
      // {
        upstreamCheck = s.upstreamCheck // {
          command = throw "disabled upstream check was forced";
        };
      }
    )).editSteps
      (
        plan:
        plan
        ++ [
          {
            name = "xz.consumer-marker";
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
        "$CC" ${./fixtures/version.c} $(pkg-config --cflags --libs liblzma) -Wl,-rpath,${package}/lib -o shared
        ./shared
        "$CC" ${./fixtures/version.c} $(pkg-config --cflags liblzma) -Wl,-Bstatic $(pkg-config --static --libs liblzma) -Wl,-Bdynamic -o static
        ./static
      '';
      expected = "${package.version}\n${package.version}";
    };
    shell-helpers = {
      script = ''
        printf 'helper-ok\n' > plain
        ${package}/bin/xz -c plain > sample.xz
        ${package}/bin/xzgrep helper sample.xz
        ${package}/bin/xzcmp sample.xz plain
      '';
      expected = "helper-ok";
    };
    customization = {
      tools = commonTools ++ [ custom ];
      script = ''
        cat ${custom}/nix-support/consumer-marker
        printf 'custom-ok' | ${custom}/bin/xz -T2 | ${custom}/bin/unxz
      '';
      expected = "edited\ncustom-ok";
    };
  };
}

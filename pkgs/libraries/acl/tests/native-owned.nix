{
  pkgs,
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

  compiler = package.tvp.cc;
  pkg-config = package.tvp.declaredTestDependencies.pkg-config;
  binutils = package.tvp.declaredDependencies.binutils;
  coreutils = package.specification.coreutils;
  marked = (package.override { doCheck = false; }).editSteps (
    plan:
    plan
    ++ [
      {
        name = "acl.consumer-marker";
        run = ''printf '%s\n' edited > "$out/nix-support/consumer-marker"'';
      }
    ]
  );
in
package.testContext.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = commonTools;
  tests = {
    isolated-discovery = {
      tools = commonTools ++ [
        compiler
        pkg-config
        coreutils
        binutils
      ];
      script = ''
        cflags=$(PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig ${pkg-config}/bin/pkg-config --cflags libacl)
        shared=$(PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig ${pkg-config}/bin/pkg-config --libs libacl)
        static=$(PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig ${pkg-config}/bin/pkg-config --static --libs libacl)
        ${coreutils}/bin/env -i PATH=${compiler}/bin:${coreutils}/bin \
          ${compiler}/bin/cc ${./fixtures/public.c} $cflags $shared -Wl,-rpath,${package}/lib -o shared
        ${coreutils}/bin/env -i ./shared
        ${coreutils}/bin/env -i PATH=${compiler}/bin:${coreutils}/bin \
          ${compiler}/bin/cc ${./fixtures/public.c} $cflags -Wl,-Bstatic $static -Wl,-Bdynamic -o static
        ${coreutils}/bin/env -i ./static
        if ${binutils}/bin/readelf -d static | grep -q 'Shared library: \[libacl'; then exit 1; fi
        # No Attr headers or libraries were supplied to either public consumer.
        test ! -s ${package}/nix-support/propagated-build-inputs
      '';
      expected = "ok\nok";
    };
    customization = {
      tools = commonTools ++ [
        marked
        compiler
        coreutils
      ];
      script = ''
        cat ${marked}/nix-support/consumer-marker
        ${coreutils}/bin/env -i PATH=${compiler}/bin:${coreutils}/bin \
          ${compiler}/bin/cc -I${marked}/include ${./fixtures/public.c} ${marked}/lib/libacl.a -o consumer
        ${coreutils}/bin/env -i ./consumer
      '';
      expected = "edited\nok";
    };
  };
}

// (if (package ? specification) && (package.specification ? upstreamPlan) && (package.specification.upstreamCheck.enabled or true) then {
  # Independent native upstream registration.
  upstream = import ../native/upstream.nix { package = package; };
} else { })

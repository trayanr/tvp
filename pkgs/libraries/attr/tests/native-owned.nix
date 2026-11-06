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
  coreutils = package.tvp.declaredDependencies.coreutils;
  custom = (package.override { doCheck = false; }).editRuntime (
    r:
    r
    // {
      consumerMessage = "edited";
    }
  );
  marked = custom.edit (
    s:
    s
    // {
      plan = s.plan ++ [
        {
          name = "attr.consumer-marker";
          run = ''printf '%s\n' ${pkgs.lib.escapeShellArg s.runtime.consumerMessage} > "$out/nix-support/consumer-marker"'';
        }
      ];
    }
  );
in
package.testContext.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = commonTools;
  tests = {
    capability-runner = {
      tools = commonTools ++ [ package.tvp.declaredDependencies.python ];
      script = ''
        ${package.tvp.declaredDependencies.python}/bin/python3 -B \
          ${../../../../lib/tests/test-filesystem-runner.py} \
          ${../../../../lib/tests/filesystem-test-runner.py} >&2
        echo ok
      '';
      expected = "ok";
    };
    isolated-discovery = {
      tools = commonTools ++ [
        compiler
        pkg-config
        coreutils
        binutils
      ];
      script = ''
        cflags=$(PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig ${pkg-config}/bin/pkg-config --cflags libattr)
        shared=$(PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig ${pkg-config}/bin/pkg-config --libs libattr)
        static=$(PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig ${pkg-config}/bin/pkg-config --static --libs libattr)
        ${coreutils}/bin/env -i PATH=${compiler}/bin:${coreutils}/bin \
          ${compiler}/bin/cc ${./fixtures/policy.c} $cflags $shared -Wl,-rpath,${package}/lib -o shared
        ${coreutils}/bin/env -i ./shared
        ${coreutils}/bin/env -i PATH=${compiler}/bin:${coreutils}/bin \
          ${compiler}/bin/cc ${./fixtures/policy.c} $cflags -Wl,-Bstatic $static -Wl,-Bdynamic -o static
        ${coreutils}/bin/env -i ./static
        if ${binutils}/bin/readelf -d static | grep -q 'Shared library: \[libattr'; then exit 1; fi
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
          ${compiler}/bin/cc -I${marked}/include ${./fixtures/policy.c} ${marked}/lib/libattr.a -o consumer
        ${coreutils}/bin/env -i ./consumer
      '';
      expected = "edited\nok";
    };
  };
}

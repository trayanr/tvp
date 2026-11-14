{
  package,
  lib,
  context,
}:
let
  locale = (package.testConfiguration or { }).locale or package.tvp.declaredTestDependencies.locale;
  helpers =
    if ((package.testConfiguration or { }).helpers or null) != null then
      package.testConfiguration.helpers
    else
      [
        {
          bin = "gzip";
          package = package.tvp.declaredTestDependencies.gzip;
          flag = "-z";
        }
        {
          bin = "bzip2";
          package = package.tvp.declaredTestDependencies.bzip2;
          flag = "-j";
        }
        {
          bin = "xz";
          package = package.tvp.declaredTestDependencies.xz;
          flag = "-J";
        }
        {
          bin = "zstd";
          package = package.tvp.declaredTestDependencies.zstd;
          flag = "--zstd";
        }
      ];
in

context.mkSuite {
  inherit package;
  tools = package.specification.environment.tools;
  tests = {
    remote-helper = {
      script = ''
        ${package}/libexec/rmt --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    version = {
      script = ''
        ${package}/bin/tar --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        mkdir src dest; printf preserved > src/sample
        ${package}/bin/tar -cf archive.tar -C src sample
        ${package}/bin/tar -xf archive.tar -C dest
        cat dest/sample
      '';
      expected = "preserved";
    };
  };
}
// import ./current-extended.nix {
  inherit
    lib
    context
    package
    helpers
    ;
}

// import ../../../../lib/tests/command-nls.nix {
  inherit package locale;
  command = "tar";
}

// lib.optionalAttrs (package.specification ? features) (
  import ./current-contracts.nix { inherit package lib context; }
)
// lib.optionalAttrs (package.specification ? features) (
  import ./ordinary-consumers.nix { inherit package; }
)

// lib.optionalAttrs (package.specification.upstreamCheck.enabled or false) {
  upstream = context.mkUpstream { inherit package; };
}

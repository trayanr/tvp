{
  package,
  lib,
  context,
}:
let
  d =
    package.tvp.deps
    // package.specification.base.tools
    // {
      binutils = package.specification.base.compiler.bintools;
    };
in
context.mkSuite {
  inherit package;
  libraries = [
    package
    d.ncurses
  ];
  tools = package.specification.environment.tools ++ [ d.binutils ];
  tests =
    (
      if package.tvp.features.completionMatches or true then
        {
          completion-history = {
            script = ''
              cc -std=gnu89 ${./fixtures/ordinary-completion.c} -lreadline -lhistory -lncursesw -o completion
              ./completion
            '';
            expected = "completion-history";
          };
        }
      else
        { }
    )
    // (
      if package.tvp.features.static && package.tvp.features.shared then
        {
          static-shared-contract = {
            script = ''
              cc -I${package}/include ${./fixtures/history.c} ${package}/lib/libhistory.so -Wl,-rpath,${package}/lib -o history
              test "$(./history)" = '2 tvp'
              cc -std=gnu89 -I${package}/include ${./fixtures/version.c} ${package}/lib/libreadline.a -lncursesw -o static-readline
              test "$(./static-readline)" = ${
                if builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" package.version != null then
                  builtins.concatStringsSep "." (
                    builtins.genList (
                      i: builtins.elemAt (builtins.filter builtins.isString (builtins.split "\\." package.version)) i
                    ) 2
                  )
                else
                  package.version
              }
              test -s ${package}/lib/libhistory.a
              readelf -d ${package}/lib/libreadline.so > dynamic
              grep -F 'Shared library: [libncursesw.so.6]' dynamic >/dev/null
              if grep -E 'NEEDED.*libtinfo' dynamic; then exit 1; fi
              echo shared-public-headers-private-curses
            '';
            expected = "shared-public-headers-private-curses";
          };
        }
      else
        { }
    );
}
// (
  if builtins.elem "readline" package.tvp.features.pkgConfigModules then
    context.mkSuite {
      inherit package;
      tools = package.specification.environment.tools;
      libraries = [
        package
        d.ncurses
      ];
      tests.pkg-config-consumer = {
        script = ''
          export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig:${d.ncurses}/lib/pkgconfig
          pkg-config --cflags --libs readline > flags
          cc -std=gnu89 ${./fixtures/version.c} $(cat flags) -o pc-version
          ./pc-version
        '';
        expected =
          if builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" package.version != null then
            lib.versions.majorMinor package.version
          else
            package.version;
      };
    }
  else
    { }
)

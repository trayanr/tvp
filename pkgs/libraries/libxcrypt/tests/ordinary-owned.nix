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

  steps = tvp.builder.steps;
  edited = (package.override { doCheck = false; }).editSteps (
    steps.insertAfter "libxcrypt.install" [
      {
        name = "probe.installed";
        run = ''test -f "$out/include/crypt.h"; printf 'ordered-install-edit\n' > "$out/owned-edit"'';
      }
    ]
  );
  lazy = package.editSteps (
    steps.append [
      {
        name = "probe.disabled";
        enabled = false;
        run = throw "disabled payload evaluated";
        tools = throw "disabled tools evaluated";
      }
    ]
  );
in
assert lazy.drvPath == package.drvPath;
package.testContext.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = commonTools;
  tests = {
    static-consumer = {
      tools = commonTools ++ [
        package.tvp.cc
        package.tvp.declaredTestDependencies.pkg-config
      ];
      script = ''
        export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
        printf '%s\n' '#include <crypt.h>' '#include <string.h>' 'int main(void) { char *v = crypt("abc", "$6$salt$"); return !v || strncmp(v, "$6$salt$", 8); }' > consumer.c
        "$CC" $(pkg-config --cflags libxcrypt) consumer.c ${package}/lib/libcrypt.a $(pkg-config --static --libs libxcrypt | sed 's/-lcrypt//g') -o consumer
        ./consumer
        echo ok
      '';
      expected = "ok";
    };
    named-edit = {
      tools = commonTools ++ [ edited ];
      script = "cat ${edited}/owned-edit";
      expected = "ordered-install-edit";
    };
  };
}

# Bounded installed consumers. The archive test selects this library's .a;
# dependencies and libc may remain dynamic. No full-static closure claim.
{
  package,
  context ? package.testContext,
  pc,
  apiPc,
  archive,
  api,
  consumer,
}:
let
  spec = package.specification;
  providers = spec.base.standardTools // {
    binutils = spec.base.compiler.bintools;
  };
  directory = "${package}/${(spec.installedInterface.libraryDirectory or spec.libraryDirectory)}";
  tools = [
    spec.pkgConfig
    providers.binutils
    providers.patchelf
  ];
in
context.mkSuite {
  inherit package;
  libraries = [ package ];
  inherit tools;
  tests = {
    api = {
      script = ''
        "$CC" $(pkg-config --cflags ${apiPc}) ${api} $(pkg-config --libs ${apiPc}) -o consumer
        timeout 15 ./consumer
      '';
      expected = "api-ok";
    };
    cxx = {
      script = ''
        "$CXX" -x c++ $(pkg-config --cflags ${apiPc}) ${api} -x none $(pkg-config --libs ${apiPc}) -o consumer
        timeout 15 ./consumer
      '';
      expected = "api-ok";
    };
    archive = {
      tools = tools ++ [ providers.grep ];
      script = ''
        read -r -a discovered <<< "$(pkg-config --static --libs ${apiPc})"
        dependencies=()
        for flag in "''${discovered[@]}"; do
          if [[ "$flag" != -l${builtins.substring 3 99 archive} ]]; then dependencies+=("$flag"); fi
        done
        "$CC" $(pkg-config --cflags ${apiPc}) ${api} ${directory}/${archive}.a "''${dependencies[@]}" -o consumer
        # Reject an accidentally shared selection of the target library.
        ${spec.bash}/bin/bash ${./check-archive-dependency.sh} \
          ${providers.binutils}/bin/readelf ${providers.grep}/bin/grep consumer ${archive}.so
        timeout 15 ./consumer
      '';
      expected = "api-ok";
    };
    consumer = {
      script = ''
        "$CC" $(pkg-config --cflags ${apiPc}) ${consumer} $(pkg-config --libs ${apiPc}) -ldl -o consumer
        timeout 15 ./consumer ${directory}/${archive}.so
      '';
      expected = "loaded";
    };
    discovery = {
      script = ''
        test -s ${directory}/${archive}.a
        test -e ${directory}/${archive}.so
        test "$(pkg-config --variable=libdir ${pc})" = ${directory}
        pkg-config --exists --print-errors ${pc} x11 xcb xau xdmcp xproto
        pkg-config --static --libs ${apiPc} > discovered-libraries
        test -s discovered-libraries
        pkg-config --modversion ${pc}
      '';
      expected = package.version;
    };
    runtime = {
      script = ''
        "$CC" $(pkg-config --cflags ${apiPc}) ${api} $(pkg-config --libs ${apiPc}) -o consumer
        test "$(patchelf --print-interpreter consumer)" = ${"${spec.base.compiler.libc}/lib/ld-linux-x86-64.so.2"}
        # env -i removes incidental loader and display settings.
        ${spec.coreutils}/bin/env -i PATH=${spec.coreutils}/bin ${spec.coreutils}/bin/timeout 15 ./consumer
      '';
      expected = "api-ok";
    };
  };
}

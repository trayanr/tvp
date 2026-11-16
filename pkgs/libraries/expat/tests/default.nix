{
  package,
  lib,
  context,
}:
let
  tools = package.specification.base.tools;
in
context.mkSuite {
  inherit package;
  tools = [
    tools.pkg-config
    tools.cmake
    tools.ninja
    tools.grep
    tools.patchelf
  ];
  libraries = [ package ];
  tests =
    {
      customization = {
        script = "echo customization";
        expected = import ./customization.nix { inherit package; };
      };
      steps-replacement = {
        script =
          let
            control = package.editSteps (_: [
              {
                name = "contract.probe";
                run = ''mkdir -p "$out"; printf '%s\n' 'edited plan executed' > "$out/marker"'';
              }
            ]);
          in
          "cat ${control}/marker";
        expected = "edited plan executed";
      };
      consumer = {
        script = "cc ${./fixtures/consumer.c} -lexpat -o consumer; ./consumer";
        expected = package.version;
      };
      entity = {
        script = "cc ${./fixtures/entity.c} -lexpat -o entity; ./entity";
        expected = "42";
      };
      pkg-config = {
        script = "pkg-config --modversion expat";
        expected = package.version;
      };
      cmake = {
        script = ''
          cp ${./fixtures/consumer.c} consumer.c
          printf '%s\n' 'cmake_minimum_required(VERSION 3.20)' 'project(consumer C)' 'find_package(expat ${package.version} CONFIG REQUIRED)' 'add_executable(consumer consumer.c)' 'target_link_libraries(consumer PRIVATE expat::expat)' > CMakeLists.txt
          cmake -S . -B build -G Ninja -DCMAKE_MAKE_PROGRAM=${tools.ninja}/bin/ninja > configure.log
          cmake --build build > build.log
          build/consumer
        '';
        expected = package.version;
      };

    }
    // lib.optionalAttrs package.specification.buildFeatures.tools {
      xmlwf = {
        script = ''
          printf '%s\n' '<!DOCTYPE r [<!ENTITY answer "42">]><r>&answer;</r>' > good.xml
          xmlwf good.xml
          printf '%s\n' '<broken>' > bad.xml
          status=0
          xmlwf bad.xml > bad.log 2>&1 || status=$?
          test "$status" = 2
          xmlwf -v > version
          grep -Fq '${package.version}' version
          echo XML
        '';
        expected = "XML";
      };
    }
    // lib.optionalAttrs package.tvp.features.shared {
      loaded-library = {
        script = ''
          printf '%s\n' '#define _GNU_SOURCE' '#include <dlfcn.h>' '#include <expat.h>' '#include <stdio.h>' '#include <string.h>' 'int main(void){Dl_info i;if(!dladdr(dlsym(RTLD_DEFAULT,"XML_ParserCreate"),&i)||strcmp(i.dli_fname,"${package}/lib/libexpat.so.1"))return 1;puts("loaded");return 0;}' > loaded.c
          cc loaded.c -lexpat -ldl -o loaded
          ./loaded
        '';
        expected = "loaded";
      };
    };
}

// lib.optionalAttrs (package.specification.upstreamCheck.enabled or true) {
  upstream = context.mkUpstream { inherit package; };
}

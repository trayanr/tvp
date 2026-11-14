{
  package,
  lib,
  context,
}:
let
  p = package;
  s = p.specification;
  tools = s.base.standardTools;
  steps = import ../../../../lib/build-steps.nix;
  d = tools // {
    binutils = s.base.compiler.bintools;
  };
  runtimeDirectories =
    if p.runtime.libraries == [ ] then
      s.base.runtimeDirectories
    else
      lib.concatMap (
        provider: (provider.development or { }).libraryDirectories or [ "${provider}/lib" ]
      ) p.runtime.libraries;
  sourceProbe =
    (p.override { src = "${p.tvp.declaredTestDependencies.alternateSource}/source.tar.gz"; }).edit
      (
        s:
        let
          base = s.base.override { compiler = p.tvp.declaredTestDependencies.sentinel; };
        in
        (removeAttrs s [ "artifactName" ])
        // {
          inherit base;
          plan = [
            (builtins.head s.plan)
            (
              (base.environment s.environment)
              // {
                name = "gperf.source-base";
                run = ''
                  test "$(cat source/marker)" = 'alternate source'
                  printf 'int main(void) { return 0; }\n' > probe.c
                  "$CC" probe.c -o probe
                  "$CXX" -x c++ probe.c -o probe-cxx
                  env -i ./probe; env -i ./probe-cxx
                  test "$(cat selected-compiler)" = $'selected\nselected'
                  mkdir "$out"; cp source/marker "$out/source-marker"
                '';
              }
            )
          ];
        }
      );
  runtimeChanged = p.editRuntime (r: r // { dlopenDirectories = [ "${d.python}/lib" ]; });
  optionsChanged = (p.override { configureFlags = [ "CXXFLAGS=-O0" ]; }).editSteps (
    steps.insertAfter "gperf.configure" [
      {
        name = "gperf.option-control";
        cwd = "source";
        tools = [ d.grep ];
        run = "grep -q '^CXXFLAGS = -O0$' src/Makefile";
      }
    ]
  );
  factoryChanged = (p.mkTests.override { tests = import ./installed.nix; }) rebound;
  outputChanged = p.editSteps (
    steps.append [
      {
        name = "gperf.output-control";
        run = ''printf edited > "$out/nix-support/custom-output"'';
      }
    ]
  );
  runtimeProvider = (p.edit (s: removeAttrs s [ "artifactName" ])).editSteps (_: [
    {
      name = "gperf.runtime-provider";
      run = ''
        mkdir -p "$out/lib"
        for directory in ${lib.escapeShellArgs s.base.runtimeDirectories}; do
          for name in libstdc++.so.6 libgcc_s.so.1; do
            if test ! -e "$out/lib/$name" && test -f "$directory/$name"; then
              ln -s "$directory/$name" "$out/lib/$name"
            fi
          done
        done
        test -L "$out/lib/libstdc++.so.6"
        test -L "$out/lib/libgcc_s.so.1"
      '';
    }
  ]);
  rebound = p.override { libstdcxx = runtimeProvider; };

in
context.mkSuite {
  inherit package;
  tools = [
    d.grep
    d.sed
    d.gawk
  ];
  libraries = [ ];
  tests = {
    version = {
      script = "gperf --version | awk 'NR==1 {print $NF}' ";
      expected = p.version;
    };
    generated = {
      script = ''
        gperf ${./fixtures/words.gperf} > words.c
        "$CC" words.c -o words; env -i ./words
        gperf --language=C++ --ignore-case --compare-strncmp --readonly-tables --class-name=Keywords ${./fixtures/case.gperf} > words.cc
        "$CXX" words.cc -o words-cxx; env -i ./words-cxx
        printf generated
      '';
      expected = "generated";
    };
    runtime = {
      script = ''
        env -i ${p}/bin/gperf --version >&2
        readelf -d ${p}/bin/gperf > elf
        grep -Fq '[libstdc++.so.6]' elf
        found=0
        for directory in ${lib.escapeShellArgs runtimeDirectories}; do
          if test -e "$directory/libstdc++.so.6"; then
            grep -Fq "$directory" elf
            found=1; break
          fi
        done
        test "$found" = 1
        grep -Fq '${p.specification.base.compiler.libc}/lib' elf
        if printf 'alpha\nalpha\n' | gperf >bad.out 2>bad.err; then exit 1; fi
        test -s bad.err
        printf runtime
      '';
      expected = "runtime";
    };
    constructor = {
      expected =
        assert (p.override { }).drvPath == p.drvPath;
        assert (p.edit (s: s)).drvPath == p.drvPath;
        assert rebound.tests.version.package.outPath == rebound.outPath;
        assert !(p ? stdenv) && !(p ? overrideAttrs);
        assert factoryChanged.version.package.outPath == rebound.outPath;
        assert factoryChanged.version.drvPath == rebound.tests.version.drvPath;
        assert runtimeChanged.drvPath != p.drvPath;
        assert !(p ? artifact) || runtimeChanged.artifact.drvPath == p.artifact.drvPath;
        assert !(p ? artifact) || outputChanged.artifact.drvPath == p.artifact.drvPath;
        assert !(p ? artifact) || optionsChanged.artifact.drvPath != p.artifact.drvPath;
        "qualified";
      script = ''
        ${optionsChanged}/bin/gperf --version >&2
        test -s ${sourceProbe}/source-marker
        test "$(cat ${outputChanged}/nix-support/custom-output)" = edited
        ${runtimeChanged}/bin/gperf --version >&2
        readelf -d ${runtimeChanged}/bin/gperf | grep -Fq '${d.python}/lib'
        ${rebound}/bin/gperf ${./fixtures/words.gperf} > rebound.c
        "$CC" rebound.c -o rebound; env -i ./rebound
        readelf -d ${rebound}/bin/gperf | grep -Fq '${runtimeProvider}/lib'
        printf qualified
      '';
    };

  };
}

// lib.optionalAttrs package.specification.doCheck (
  let
    upstream = context.mkUpstream { inherit package; };
    raw = upstream.specification.validation.execution;
  in
  {
    inherit upstream;
    upstream-evidence = context.mkTest {
      inherit package;
      name = "upstream-evidence";
      tools = [ tools.grep ];
      script = ''
        test -s ${raw}/raw/log
        test -s ${raw}/raw/records/config.log
        # This is the unmodified compiled-prefix log, not a final-prefix rerun.
        grep -Fq '${package.artifact}' ${raw}/raw/records/config.log
        test ! -e ${raw}/raw/records/normalization.json
        printf raw-artifact-evidence
      '';
      expected = "raw-artifact-evidence";
    };
  }
)

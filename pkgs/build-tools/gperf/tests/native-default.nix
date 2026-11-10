{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  p = package;
  d = p.tvp.deps;
  upstreamUnrelocated = (
    p.editSteps (
      tvp.builder.steps.insertAfter "gperf.build" [
        (
          (p.specification.base.environment (
            p.specification.environment
            // {
              tools = p.specification.environment.tools ++ [
                d.gnutar
                d.gzip
              ];
            }
          ))
          // {
            name = "gperf.upstream";
            cwd = "source";
            run = ''
              export CONFIG_SHELL=${p.specification.bash}/bin/bash SHELL=${p.specification.bash}/bin/bash
              status=0
              ${d.gnumake}/bin/make -j"$NIX_BUILD_CORES" TESTSUITEFLAGS="-j$NIX_BUILD_CORES" check || status=$?
              find . \( -name '*suite.log' -o -name 'test-suite.log' \) -exec cat {} \; >&2
              if (( status )); then exit "$status"; fi
              mkdir -p "$out/nix-support/upstream"
              find . \( -name '*.log' -o -name '*.trs' \) | while read -r file; do
                mkdir -p "$out/nix-support/upstream/$(dirname "$file")"
                cp "$file" "$out/nix-support/upstream/$file"
              done
            '';
          }
        )
      ]
    )
  );
  upstream =
    if !(p ? artifact) then
      upstreamUnrelocated
    else
      upstreamUnrelocated.editSteps (
        tvp.builder.steps.insertAfter "output.copy-artifacts" [
          {
            name = "gperf.normalize-upstream-evidence";
            tools = [ p.specification.tools.python ];
            run = ''
              ${p.specification.tools.python}/bin/python3 -B - "$out/nix-support/upstream" <<'PYTHON'
              import hashlib, json, os, stat, sys
              from pathlib import Path

              root = Path(sys.argv[1])
              prefix = os.fsencode(os.environ['TVP_ARTIFACT_ROOT'])
              marker = b'@TVP_ARTIFACT_PREFIX@'
              records = []
              for directory, directories, files in os.walk(root, followlinks=False):
                  for name in directories:
                      if (Path(directory) / name).is_symlink():
                          raise RuntimeError('symlink in upstream evidence')
                  for name in sorted(files):
                      path = Path(directory) / name
                      info = path.lstat()
                      if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
                          raise RuntimeError('upstream evidence must be independent regular files')
                      raw = path.read_bytes()
                      normalized = raw.replace(prefix, marker)
                      path.write_bytes(normalized)
                      records.append({
                          'path': str(path.relative_to(root)),
                          'rawSha256': hashlib.sha256(raw).hexdigest(),
                          'normalizedSha256': hashlib.sha256(normalized).hexdigest(),
                      })
              (root / 'normalization.json').write_text(json.dumps({
                  'schema': 'tvp.normalized-artifact-evidence/v1',
                  'stage': 'artifact configure/check',
                  'prefixPlaceholder': marker.decode(),
                  'rawEvidence': 'Unmodified originals remain in the upstream-check artifact; its binding is retained externally.',
                  'files': sorted(records, key=lambda record: record['path']),
              }, indent=2) + '\n')
              (root / 'README').write_text(
                  'NORMALIZED ARTIFACT-STAGE EVIDENCE\n'
                  'Configure/check ran during artifact construction, before finalization.\n'
                  'The artifact installation prefix is represented by @TVP_ARTIFACT_PREFIX@.\n'
                  'These logs do not describe commands rerun at the final output prefix.\n'
                  'normalization.json binds the raw and normalized file hashes.\n')
              PYTHON
            '';
          }
        ]
      );
  sourceProbe =
    (p.override { src = "${p.tvp.declaredTestDependencies.alternateSource}/source.tar.gz"; }).edit
      (
        s:
        let
          base = s.base.override { compiler = p.tvp.declaredTestDependencies.sentinel; };
        in
        s
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
    tvp.builder.steps.insertAfter "gperf.configure" [
      {
        name = "gperf.option-control";
        cwd = "source";
        tools = [ d.grep ];
        run = ''grep -q '^CXXFLAGS = -O0$' src/Makefile'';
      }
    ]
  );
  factoryChanged = (p.mkTests.override { inherit pkgs; }) rebound;
  outputChanged = p.editSteps (
    tvp.builder.steps.append [
      {
        name = "gperf.output-control";
        run = ''printf edited > "$out/nix-support/custom-output"'';
      }
    ]
  );
  runtimeProvider = p.editSteps (_: [
    {
      name = "gperf.runtime-provider";
      run = ''
        mkdir -p "$out/lib"
        ln -s ${d.libstdcxx}/lib/libstdc++.so.6 "$out/lib/libstdc++.so.6"
        ln -s ${d.libstdcxx}/lib/libgcc_s.so.1 "$out/lib/libgcc_s.so.1"
      '';
    }
  ]);
  rebound = p.override { libstdcxx = runtimeProvider; };

in
p.testContext.mkSuite {
  inherit package;
  tools = [
    d.grep
    d.sed
    d.gawk
  ];
  libraries = [ ];
  tests = {
    version = {
      script = ''gperf --version | awk 'NR==1 {print $NF}' '';
      expected = p.version;
    };
    upstream = {
      script =
        if !(p ? artifact) then
          ''test -d ${upstream}/nix-support/upstream; printf upstream''
        else
          ''
            ${p.specification.tools.python}/bin/python3 -B - ${upstream} ${upstream.artifact} <<'PYTHON'
            import hashlib, json, os, sys
            from pathlib import Path
            final, artifact = map(Path, sys.argv[1:])
            saved = final / 'nix-support/upstream'
            raw = artifact / 'nix-support/upstream'
            manifest = json.loads((saved / 'normalization.json').read_text())
            assert manifest['stage'] == 'artifact configure/check'
            marker = manifest['prefixPlaceholder'].encode()
            assert marker == b'@TVP_ARTIFACT_PREFIX@'
            assert 'NORMALIZED ARTIFACT-STAGE EVIDENCE' in (saved / 'README').read_text()
            records = {record['path']: record for record in manifest['files']}
            files = {str(path.relative_to(raw)) for path in raw.rglob('*') if path.is_file()}
            assert files and files == set(records)
            for name, record in records.items():
                original, normalized = (raw / name).read_bytes(), (saved / name).read_bytes()
                assert normalized == original.replace(os.fsencode(artifact), marker)
                assert hashlib.sha256(original).hexdigest() == record['rawSha256']
                assert hashlib.sha256(normalized).hexdigest() == record['normalizedSha256']
                assert os.fsencode(artifact) not in normalized
            print('upstream', end="")
            PYTHON
          '';
      expected = "upstream";
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
        grep -Fq '${d.libstdcxx}/lib' elf
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

# These scripts intentionally retain their existing ambient command boundary.
{
  package,
  bash,
  coreutils,
  gnugrep,
}:
let
  native = package ? testContext;
  interpreter = if native then "${bash}/bin/bash" else "${builtins.dirOf package.stdenv.shell}/sh";
  script = ''
    mkdir -p "$out" empty supplied
    test "$(head -n1 ${package}/bin/zstdgrep)" = '#!${interpreter}'
    test "$(head -n1 ${package}/bin/zstdless)" = '#!${interpreter}'
    printf 'haystack\nneedle preserved\n' | ${package}/bin/zstd -qc > sample.zst
    # Their owned interpreter works, but empty PATH supplies neither command.
    if ${coreutils}/bin/env -i PATH="$PWD/empty" ${package}/bin/zstdgrep needle sample.zst > empty-grep.out 2> empty-grep.err; then
      echo 'unexpected isolated zstdgrep success' >&2; exit 1
    fi
    ${gnugrep}/bin/grep -F 'grep: command not found' empty-grep.err
    ${gnugrep}/bin/grep -F 'zstdcat: command not found' empty-grep.err
    if ${coreutils}/bin/env -i PATH="$PWD/empty" ${package}/bin/zstdless sample.zst > empty-less.out 2> empty-less.err; then
      echo 'unexpected isolated zstdless success' >&2; exit 1
    fi
    ${gnugrep}/bin/grep -F 'less: not found' empty-less.err
    # Real grep/decompression, first through PATH and then explicit overrides.
    ln -s ${gnugrep}/bin/grep supplied/grep
    ln -s ${package}/bin/zstdcat supplied/zstdcat
    ${coreutils}/bin/env -i PATH="$PWD/supplied" ${package}/bin/zstdgrep needle sample.zst > "$out/grep-path"
    ${coreutils}/bin/env -i PATH="$PWD/empty" GREP=${gnugrep}/bin/grep ZCAT=${package}/bin/zstdcat ${package}/bin/zstdgrep needle sample.zst > "$out/grep-explicit"
    test "$(cat "$out/grep-path")" = 'needle preserved'
    cmp "$out/grep-path" "$out/grep-explicit"
    # Dispatch probe only: this is not coverage of a real pager.
    cat > supplied/less <<'SCRIPT'
    #!${bash}/bin/bash
    printf '%s\n' "$LESSOPEN" "$@"
    SCRIPT
    chmod +x supplied/less
    ${coreutils}/bin/env -i PATH="$PWD/supplied" ${package}/bin/zstdless sample.zst > "$out/less-dispatch-default"
    ${coreutils}/bin/env -i PATH="$PWD/supplied" ZSTD=${package}/bin/zstd ${package}/bin/zstdless sample.zst > "$out/less-dispatch-explicit"
    test "$(head -n1 "$out/less-dispatch-default")" = '|-zstd -cdfq %s'
    test "$(head -n1 "$out/less-dispatch-explicit")" = '|-${package}/bin/zstd -cdfq %s'
    cp empty-*.err "$out/"
  '';
in
if native then
  package.testContext.mkTest {
    inherit package;
    name = "helper-boundary";
    tools = [
      bash
      coreutils
      gnugrep
      package.tvp.deps.diffutils
    ];
    script = ''
      ( export out="$PWD/helper-results"
        ${script}
      ) >&2
      echo ok
    '';
    expected = "ok";
  }
else
  package.stdenv.mkDerivation {
    name = "zstd-${package.version}-helper-boundary";
    dontUnpack = true;
    dontFixup = true;
    buildCommand = script;
    passthru = {
      inherit package;
    };
  }

# Test-only standalone execution of the matching support sources. Its objects
# never replace the support objects produced inside the compiler bootstrap.
{
  lib,
  base,
  bash,
  coreutils,
  source,
  version,
  gnumake,
  zlib,
  zstd,
  tools,
}:
final: {
  pname = "source-full-gcc-libbacktrace-check";
  inherit
    version
    base
    bash
    coreutils
    ;
  src = source;
  outputs = [
    "out"
    "evidence"
  ];
  environment = {
    inherit tools;
    libraries = [
      zlib
      zstd
    ];
  };
  plan = [
    (
      (final.base.environment final.environment)
      // {
        name = "libbacktrace.check";
        tools = (final.base.environment final.environment).tools ++ [ gnumake ];
        run = ''
          mkdir -p "$out" "$evidence/raw"
          export SHELL=${bash}/bin/bash CONFIG_SHELL=${bash}/bin/bash
          export CFLAGS="-O2 -g" CXXFLAGS="-O2 -g"
          printf '%s\n' "CC=$CC" "CXX=$CXX" > "$evidence/toolchain.txt"
          ${bash}/bin/bash ${final.src}/libbacktrace/configure \
            --prefix="$out" --build=x86_64-unknown-linux-gnu \
            --host=x86_64-unknown-linux-gnu > "$evidence/configure.log" 2>&1
          status=0
          ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash check > "$evidence/check.log" 2>&1 || status=$?
          printf '%s\n' "$status" > "$evidence/check.status"
          cp config.log config.status "$evidence/"
          find . -type f \( -name '*.log' -o -name '*.trs' \) -exec cp --parents {} "$evidence/raw" \;
          printf '{"makeStatus":%s,"productionObjectsReplaced":false}\n' "$status" > "$out/result.json"
        '';
      }
    )
  ];
}

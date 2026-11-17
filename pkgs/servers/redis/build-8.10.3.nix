# Redis core server and command-line tools. Optional search/JSON module builds,
# jemalloc, TLS, systemd and replication compression are separate future profiles.
{
  tvp,
  lib,
  base,
  src,
  version,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command = name: steps.command { environment = final.environment; } "redis.${name}";
  binaries = [
    "redis-server"
    "redis-cli"
    "redis-benchmark"
    "redis-check-rdb"
    "redis-check-aof"
    "redis-sentinel"
  ];
  # Explicit targets avoid both the top-level module orchestrator and src/all's
  # test-module compilation. Source-shipped static dependencies are built here.
  make = ''
    ${tools.gnumake}/bin/make -C src -j"$NIX_BUILD_CORES" \
      SHELL=${tools.bash}/bin/bash CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
      PYTHON=${tools.python}/bin/python3 MALLOC=libc BUILD_TLS=no \
      BUILD_COMPRESSION=no USE_SYSTEMD=no OPTIMIZATION=-O2 ENABLE_LTO= \
      ${lib.escapeShellArgs binaries}
  '';
in
{
  pname = "redis";
  inherit base src version;
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.findutils
      tools.python
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.shebangs {
      name = "redis.source-shells";
      paths = [
        "src"
        "deps"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "build" make)
    (command "install" ''
      mkdir -p "$out/bin" "$out/share/licenses/redis"
      for binary in ${lib.escapeShellArgs binaries}; do
        cp "src/$binary" "$out/bin/$binary"
      done
      cp LICENSE.txt REDISCONTRIBUTIONS.txt "$out/share/licenses/redis/"
    '')
    (steps.split "redis.finalize")
    (outputs.copyArtifacts { })
    (outputs.strip {
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.rpaths {
      paths = [ "bin" ];
      libraries = final.runtime.libraries;
      elfKinds = [ "runtime" ];
    })
    (outputs.checkPaths {
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = {
    core = true;
    tls = false;
    systemd = false;
    search = false;
    json = false;
    replicationCompression = false;
    libcAllocator = true;
    jemalloc = false;
  };
  meta = {
    description = "Redis core in-memory data server and command-line tools";
    homepage = "https://redis.io/";
    # Redis 8 offers AGPLv3 as one of its three licensing alternatives.
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "redis-server";
  };
}

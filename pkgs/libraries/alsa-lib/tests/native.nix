{ package }:
let
  p = package;
  d = p.specification;
in
p.testContext.mkSuite {
  inherit package;
  tools = [
    d.binutils
    package.tvp.declaredTestDependencies.pkgConfig
  ];
  libraries = [ p ];
  tests = {
    consumer = {
      script = ''
        cc ${./fixtures/consumer.c} -lasound -o consumer
        ./consumer
      '';
      expected = p.version;
    };
    topology = {
      script = "cc ${./fixtures/topology.c} -latopology -lasound -o topology; ./topology";
      expected = "topology-binary-roundtrip";
    };
    installed-profile = {
      script = ''
        test "$(pkg-config --modversion alsa)" = ${p.version}
        test -s ${p}/share/alsa/alsa.conf
        test -s ${p}/share/alsa/pcm/default.conf
        test -s ${p}/lib/pkgconfig/alsa.pc
        readelf -d ${p}/lib/libasound.so.2 > dynamic
        test -s dynamic
        test ! -e ${p}/lib/libasound.a
        PATH=${d.coreutils}/bin ${p}/bin/aserver --help > helper-help 2>&1
        test -s helper-help
        printf '%s\n' 'alsa-config-shared-topology'
      '';
      expected = "alsa-config-shared-topology";
    };
  };
}

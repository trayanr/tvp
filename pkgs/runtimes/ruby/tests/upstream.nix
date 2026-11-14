# Upstream bootstrap runner against F; no compiler, build tree or producer test edge.
{ tvp, package }:
let
  spec = package.specification;
  inherit (spec) tools;
in
if !spec.tvp.features.doCheck then
  { }
else
  {
    upstream-basic = package.testContext.mkTest {
      inherit package;
      name = "upstream-basic";
      tools = [
        tools.gnutar
        tools.gzip
        tools.findutils
      ];
      script = ''
        ${tools.gnutar}/bin/tar -xzf ${spec.src}
        cd ruby-${package.version}
        export HOME="$TMPDIR"
        # The same native runner used by make test-basic; failures remain failures.
        # stdout/stderr are retained in the build log, never normalized to success.
        if ${package}/bin/ruby bootstraptest/runner.rb --ruby=${package}/bin/ruby > upstream.log 2>&1; then
          cat upstream.log >&2
        else
          status=$?
          cat upstream.log >&2
          exit "$status"
        fi
        printf upstream-basic-ok
      '';
      expected = "upstream-basic-ok";
    };
  }

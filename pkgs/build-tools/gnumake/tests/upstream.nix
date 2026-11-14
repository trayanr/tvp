# Preserve Make's established source-bound known-result policy independently of A/F.
{
  package,
  context,
  lib,
}:
let
  s = package.specification;
  perl = package.tvp.declaredTestDependencies.perl;
  checked = package.edit (
    spec:
    spec
    // {
      upstreamCheck = spec.upstreamCheck // {
        tools = spec.upstreamCheck.tools ++ [ perl ];
        env = spec.upstreamCheck.env // {
          MAKE_TEST_PERL = "${perl}/bin/perl";
        };
      };
    }
  );
  shared = context.mkUpstream { package = checked; };
  raw = shared.specification.validation.execution;
  classifier =
    {
      "4.3" = ./upstream/check-4.3.py;
      "4.4" = ./upstream/check-4.4.py;
      "4.4.1" = ./upstream/check-4.4.1.py;
    }
    .${s.upstreamProfile};
  python = s.base.standardTools.python;
in
(context.mkTest {
  inherit package;
  name = "upstream";
  tools = [ python ];
  script = ''
    test -s ${raw}/raw/upstream.log
    mkdir -p classifier/tests
    cp ${raw}/raw/upstream.log classifier/upstream.log
    cp -R ${raw}/raw/work classifier/tests/work
    cp ${package.artifact}/nix-support/gnumake-build-tree/source/make classifier/make
    cd classifier
    # Keep exact historical diff/base/log assertions and their fresh control runs.
    # Known nonzero outcomes remain recorded and unwaived; no strict-pass claim.
    ${python}/bin/python3 -B ${classifier} "$(cat ${raw}/raw/status)" "${s.coreutils}/bin" >&2
    printf upstream-qualified
  '';
  expected = "upstream-qualified";
}).edit
  (
    test:
    test
    // {
      validation = {
        role = "upstream-acceptance";
        execution = raw;
        production = package.artifact;
        factory = "owned.mkTest";
        policy = "source-bound Make known-result classification; nonpasses remain unwaived";
      };
      passthru = test.passthru // {
        upstreamExecution = raw;
      };
    }
  )

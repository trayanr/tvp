# TVP CI architecture

GitHub hosts PRs and exposes the `tvp/smoke` status. Buildbot runs the standard
TVP smoke plan and reports the result for the exact commit.

## Revision selection

- Repository-owned branches are eligible, including drafts and stacked PRs.
  The current worker pool covers branches whose head and target are in TVP.
  External fork PRs require an isolated worker pool.
- A request records the exact head and current target SHAs. CI checks the
  target and its ancestry again before evaluating the candidate. A behind or
  diverged branch must include the current target before validation can run.
  CI tests the actual PR head without producing a synthetic merge commit.
- A newer automatic PR revision can supersede an older queued request for
  the same PR and target. Running work keeps its original head and result.
  Individual updates to `master` get separate validation.

## What smoke validation does

1. Fetch the admitted revisions and recheck the target.
2. Compare the resolved producer graphs of the target and candidate for a PR.
   The report includes added, changed, and removed producers. It also shows
   affected consumers when a dependency selector moves. CI records the
   differences for review and rejects malformed graph data.
3. Prepare the candidate's frozen smoke plan and run
   `nix flake check --no-build`. The flake check uses one evaluator.
4. Run `test all --smoke` through the deployed trusted TVP runner. Nix
   reuses valid outputs and schedules work using the configured builders.
5. Check the terminal receipt against the exact run and report the result.
   Retained evidence includes the source identity, plan, logs, and counts.

A smoke pass means the selected outputs, including cached check results, are
valid. Full catalogue and upstream suites can be requested separately as
described in [TESTING.md](../TESTING.md).

## Reading results

The `tvp/smoke` check gives the queue or terminal result. The build logs show
graph evaluation, flake checking, plan preparation, and progress through
compilation, finalization, and tests. Use the [CI guide](README.md) to run the
same standard test plan locally.

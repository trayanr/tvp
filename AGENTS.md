# Repository guidance

Follow [TESTING.md](TESTING.md): use a few focused package smoke checks by default,
reuse valid artifacts/results, and run full upstream or catalogue suites only
when the user explicitly requests them. Do not interpret a request to repair,
validate, review or merge as permission for a full regression run.

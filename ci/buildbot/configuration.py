"""Buildbot's durable queue and trusted worker commands; no candidate imports."""
from pathlib import Path
from buildbot.plugins import changes, reporters, schedulers, steps, util, worker
from buildbot.reporters.generators.build import BuildStartEndStatusGenerator
from buildbot.reporters.generators.buildrequest import BuildRequestGenerator
from buildbot.reporters.message import MessageFormatterRenderable
from changes import LabelledPullRequests
from policy import REPOSITORY, SHA, STATUS_CONTEXT, eligible, result_properties
from queue_policy import CATALOGUE, CATALOGUE_REASON, supersedes_queued_pr


def make_config(settings, source):
    source = Path(source).resolve()
    repository = settings["repository"]
    if not REPOSITORY.fullmatch(repository):
        raise ValueError("Invalid repository")
    owner, repo = repository.split("/")
    revision = settings["controller_revision"]
    if not SHA.fullmatch(revision):
        raise ValueError("controller_revision must be a full trusted commit SHA")
    tools_ref = settings.get("tools_ref", f"github:{repository}/{revision}")
    secrets = Path(settings["secrets_directory"]).resolve()
    def secret(name):
        return (secrets / name).read_text().strip()
    github_enabled = settings.get("github_enabled", True)
    github_token = secret("github-token") if github_enabled else None
    publication = settings.get("catalogue_publication")
    catalogue = publication is not None
    status_context = "tvp/catalogue" if catalogue else STATUS_CONTEXT
    allowed = lambda pr: eligible(pr, repository)
    directory = util.Interpolate("runs/%(prop:buildnumber)s")
    factory = util.BuildFactory()
    factory.addStep(steps.FileDownload(
        name="trusted-harness", mastersrc=str(source / "ci/buildbot/job.py"),
        workerdest="job.py", workdir=directory, haltOnFailure=True))
    factory.addStep(steps.FileDownload(
        name="trusted-graph-comparator", mastersrc=str(source / "tools/graph/compare.py"),
        workerdest="compare.py", workdir=directory, haltOnFailure=True))
    @util.renderer
    def validation_command(props):
        target_branch = settings.get("branch", "master")
        if props.getProperty("tvp_pr") is not None:
            # Only the controller's admitted PR change supplies this property.
            target_branch = props.getProperty("tvp_target_branch")
            if not isinstance(target_branch, str) or not target_branch:
                raise ValueError("Admitted PR change is missing its target branch")
        command = ["python3", "job.py", "--repository", repository,
                   "--head", props.getProperty("revision"),
                   "--base", props.getProperty("tvp_base", ""),
                   "--target-branch", target_branch,
                   "--tools-ref", tools_ref, "--compare", "compare.py"]
        return command + (["--catalogue"] if catalogue else [])
    factory.addStep(steps.SetPropertyFromCommand(
        name="validate-catalogue" if catalogue else "smoke-catalogue", workdir=directory,
        command=validation_command,
        extract_fn=result_properties, haltOnFailure=True,
        timeout=None, maxTime=None, sigtermTime=30,
        logfiles={
            "graph-diff": "evidence/graph-diff.log",
            "flake-evaluation": "evidence/flake-check.log",
            "preparation": "validation/latest/prepare.log",
            "nix": "validation/latest/nix.log",
        },
    ))
    # Evidence stays in controller history even if a worker checkout is later removed.
    factory.addStep(steps.DirectoryUpload(
        name="collect-evidence", workersrc="evidence", workdir=directory,
        masterdest=util.Interpolate("artifacts/%(prop:buildnumber)s"),
        alwaysRun=True, flunkOnFailure=True,
    ))
    if catalogue:
        publisher = Path(publication["script"])
        evidence_root = Path(publication["evidence_root"])
        signing_key = Path(publication["signing_key"])
        if not all(path.is_absolute() for path in (publisher, evidence_root, signing_key)):
            raise ValueError("Catalogue publication requires absolute controller-side paths")

        @util.renderer
        def publish_command(props):
            number = str(props.getProperty("buildnumber"))
            if not number.isdecimal():
                raise ValueError("Catalogue publication requires a Buildbot build number")
            head = props.getProperty("revision")
            base = props.getProperty("tvp_base") or head
            evidence = evidence_root / number
            return [
                "python3", str(publisher), "--evidence", str(evidence),
                "--head", head, "--base", base, "--repository", repository,
                "--cache-uri", publication["cache_uri"],
                "--signing-key", str(signing_key),
                "--cache-public-key", publication["cache_public_key"],
                "--receipt", str(evidence / "nas-publication.json"),
            ]

        factory.addStep(steps.MasterShellCommand(
            name="publish-and-verify-nas", command=publish_command,
            haltOnFailure=True, flunkOnFailure=True, logEnviron=False,
        ))
    change_source = []
    if github_enabled:
        pull_requests = LabelledPullRequests(
            owner=owner, repo=repo, token=github_token,
            pullrequest_filter=allowed, pollInterval=60, pollAtLaunch=True,
        )
        pull_requests.status_context = status_context
        change_source = [
            pull_requests,
            changes.GitPoller(repourl=f"https://github.com/{repository}.git",
                              branches=[settings.get("branch", "master")],
                              category="tvp-master", project=repository,
                              pollInterval=60, pollAtLaunch=True),
        ]
    return {
        "title": "TVP", "titleURL": f"https://github.com/{repository}",
        "buildbotURL": settings.get("dashboard_url", "http://localhost:8010/"),
        "db": {"db_url": "sqlite:///state.sqlite"},
        "protocols": {"pb": {"port": "tcp:9989:interface=127.0.0.1"}},
        "workers": [worker.Worker("tvp-linux", secret("worker-password"), max_builds=1)],
        "change_source": change_source,
        "schedulers": [schedulers.AnyBranchScheduler(
            name=CATALOGUE, reason=CATALOGUE_REASON, treeStableTimer=None, builderNames=["tvp-full"],
            change_filter=util.ChangeFilter(category=["tvp-pr", "tvp-master"]),
        ), schedulers.ForceScheduler(
            name="build-commit", label="Build commit", builderNames=["tvp-full"],
            codebases=[util.CodebaseParameter(
                "", branch=settings.get("branch", "master"),
                repository=f"https://github.com/{repository}.git", project=repository,
                revision=util.StringParameter(
                    name="revision", label="Full commit SHA", required=True,
                    regex=r"^[0-9a-f]{40}$", maxsize=40,
                ),
            )],
        )],
        "builders": [util.BuilderConfig(name="tvp-full", workernames=["tvp-linux"],
                                         factory=factory, collapseRequests=supersedes_queued_pr)],
        "services": [reporters.GitHubStatusPush(
            token=github_token, context=status_context,
            generators=[BuildRequestGenerator(formatter=MessageFormatterRenderable("Queued on local TVP builder")),
                        BuildStartEndStatusGenerator(
                            start_formatter=MessageFormatterRenderable(
                                "Validating catalogue and NAS publication" if catalogue else "Checking package smoke tests locally"
                            ),
                            end_formatter=MessageFormatterRenderable(util.Property("ci_summary", default="Validation stopped before its final report")),
                        )],
        )] if github_enabled else [],
        "www": {
            "port": "tcp:8010:interface=127.0.0.1",
            "plugins": {"waterfall_view": {}, "console_view": {}, "grid_view": {}},
            "auth": util.UserPasswordAuth({"operator": secret("operator-password")}),
            "authz": util.Authz(
                allowRules=[util.AnyControlEndpointMatcher(role="operator")],
                roleMatchers=[util.RolesFromUsername(roles=["operator"], usernames=["operator"])],
            ),
        },
        "buildbotNetUsageData": None,
    }

"""Buildbot's durable queue and trusted worker commands; no candidate imports."""
from pathlib import Path
from buildbot.plugins import changes, reporters, schedulers, steps, util, worker
from buildbot.reporters.generators.build import BuildStartEndStatusGenerator
from buildbot.reporters.generators.buildrequest import BuildRequestGenerator
from buildbot.reporters.message import MessageFormatterRenderable
from changes import LabelledPullRequests
from policy import REPOSITORY, SHA, eligible, result_properties


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
    allowed = lambda pr: eligible(pr, repository, settings.get("label", "ci:build"), settings.get("branch", "master"))
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
        command = ["python3", "job.py", "--repository", repository,
                   "--head", props.getProperty("revision"),
                   "--base", props.getProperty("tvp_base", ""),
                   "--tools-ref", tools_ref, "--compare", "compare.py"]
        return command
    factory.addStep(steps.SetPropertyFromCommand(
        name="full-catalogue", workdir=directory,
        command=validation_command,
        extract_fn=result_properties, haltOnFailure=True,
        timeout=None, maxTime=None, sigtermTime=30,
    ))
    # Evidence stays in controller history even if a worker checkout is later removed.
    factory.addStep(steps.DirectoryUpload(
        name="collect-evidence", workersrc="evidence", workdir=directory,
        masterdest=util.Interpolate("artifacts/%(prop:buildnumber)s"),
        alwaysRun=True, flunkOnFailure=True,
    ))
    return {
        "title": "TVP", "titleURL": f"https://github.com/{repository}",
        "buildbotURL": settings.get("dashboard_url", "http://localhost:8010/"),
        "db": {"db_url": "sqlite:///state.sqlite"},
        "protocols": {"pb": {"port": "tcp:9989:interface=127.0.0.1"}},
        "workers": [worker.Worker("tvp-linux", secret("worker-password"), max_builds=1)],
        "change_source": [
            LabelledPullRequests(owner=owner, repo=repo, token=github_token,
                                 pullrequest_filter=allowed, pollInterval=60, pollAtLaunch=True),
            changes.GitPoller(repourl=f"https://github.com/{repository}.git",
                              branches=[settings.get("branch", "master")],
                              category="tvp-master", project=repository,
                              pollInterval=60, pollAtLaunch=True),
        ] if github_enabled else [],
        "schedulers": [schedulers.AnyBranchScheduler(
            name="catalogue", treeStableTimer=None, builderNames=["tvp-full"],
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
                                         factory=factory, collapseRequests=False)],
        "services": [reporters.GitHubStatusPush(
            token=github_token, context="tvp/full",
            generators=[BuildRequestGenerator(formatter=MessageFormatterRenderable("Queued on local TVP builder")),
                        BuildStartEndStatusGenerator(
                            start_formatter=MessageFormatterRenderable("Building full catalogue locally"),
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

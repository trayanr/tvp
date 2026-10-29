"""Label-gated GitHub polling with complete pagination and durable SHA tracking."""
from twisted.internet import defer
from buildbot.changes.github import GitHubPullrequestPoller


class LabelledPullRequests(GitHubPullrequestPoller):
    db_class_name = "TVPLabelledPullRequestsV1"

    @defer.inlineCallbacks
    def _getPulls(self):
        pulls, page = [], 1
        while True:
            response = yield self._http.get(
                f"/repos/{self.owner}/{self.repo}/pulls?state=open&per_page=100&page={page}"
            )
            if response.code != 200:
                raise RuntimeError(f"GitHub PR polling failed: HTTP {response.code}")
            batch = yield response.json()
            if not isinstance(batch, list):
                raise ValueError("Invalid GitHub pull request response")
            pulls.extend(batch)
            if len(batch) < 100:
                return sorted(pulls, key=lambda pr: pr["number"])
            page += 1

    @defer.inlineCallbacks
    def _processChanges(self, pulls):
        for pr in pulls:
            if not self.pullrequest_filter(pr):
                continue
            number = pr["number"]
            head, base = pr["head"]["sha"], pr["base"]["sha"]
            # Revalidate the integration when master moves, even with the same PR head.
            identity = [head, base]
            if (yield self._getCurrentRev(number)) == identity:
                continue
            yield self.master.data.updates.addChange(
                author=pr["user"]["login"],
                revision=head,
                branch=f"refs/pull/{number}/head",
                repository=f"https://github.com/{self.owner}/{self.repo}.git",
                project=f"{self.owner}/{self.repo}",
                category="tvp-pr",
                comments=f"PR #{number}: {pr['title']}",
                revlink=pr["html_url"],
                properties={"tvp_pr": number, "tvp_base": base},
            )
            # Persist after emitting: interruption may duplicate a request, never lose it.
            yield self._setCurrentRev(number, identity)

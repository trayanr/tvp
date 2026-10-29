"""Label-gated GitHub polling with complete pagination and durable SHA tracking."""
from urllib.parse import quote

from twisted.internet import defer
from buildbot.changes.github import GitHubPullrequestPoller

from policy import SHA


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
        targets = {}
        for pr in pulls:
            if not self.pullrequest_filter(pr):
                continue
            number = pr["number"]
            head, branch = pr["head"]["sha"], pr["base"]["ref"]
            prefix = f"/repos/{self.owner}/{self.repo}"
            # PR payload base.sha may lag the target. Resolve each eligible target
            # once per poll, even when all heads have already been delivered.
            if branch not in targets:
                response = yield self._http.get(f"{prefix}/git/ref/heads/{quote(branch, safe='')}")
                if response.code != 200:
                    raise RuntimeError(f"GitHub target lookup failed: HTTP {response.code}")
                ref = yield response.json()
                if (not isinstance(ref, dict) or ref.get("ref") != f"refs/heads/{branch}"
                        or not isinstance(ref.get("object"), dict)
                        or ref["object"].get("type") != "commit"
                        or not isinstance(ref["object"].get("sha"), str)
                        or not SHA.fullmatch(ref["object"]["sha"])):
                    raise ValueError("Invalid GitHub target ref response")
                targets[branch] = ref["object"]["sha"]
            base = targets[branch]
            identity = [head, base, branch]
            previous = yield self._getCurrentRev(number)
            if (isinstance(previous, dict) and previous.get("identity") == identity
                    and previous.get("decision") in ("admitted", "blocked")):
                continue
            response = yield self._http.get(f"{prefix}/compare/{base}...{head}")
            if response.code != 200:
                raise RuntimeError(f"GitHub ancestry comparison failed: HTTP {response.code}")
            comparison = yield response.json()
            if (not isinstance(comparison, dict)
                    or comparison.get("status") not in ("ahead", "identical", "behind", "diverged")
                    or not isinstance(comparison.get("base_commit"), dict)
                    or comparison["base_commit"].get("sha") != base
                    or not isinstance(comparison.get("merge_base_commit"), dict)
                    or not isinstance(comparison["merge_base_commit"].get("sha"), str)
                    or not SHA.fullmatch(comparison["merge_base_commit"]["sha"])
                    or (comparison["status"] in ("ahead", "identical")
                        and comparison["merge_base_commit"]["sha"] != base)):
                raise ValueError("Invalid GitHub compare response")
            if comparison["status"] in ("behind", "diverged"):
                response = yield self._http.post(f"{prefix}/statuses/{head}", json={
                    "state": "pending", "context": "tvp/full",
                    "description": "Rebase or merge the current target branch into this PR before testing.",
                })
                if response.code != 201:
                    raise RuntimeError(f"GitHub blocked status failed: HTTP {response.code}")
                status = yield response.json()
                if (not isinstance(status, dict) or status.get("state") != "pending"
                        or status.get("context") != "tvp/full"):
                    raise ValueError("Invalid GitHub blocked status response")
                yield self._setCurrentRev(number, {"identity": identity, "decision": "blocked"})
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
            yield self._setCurrentRev(number, {"identity": identity, "decision": "admitted"})

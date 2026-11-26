"""Offline contract checks for the experimental OSV adapter."""

from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import audit_osv


def component(identifier="variant-a", version="1.0.0"):
    return {
        "id": identifier, "name": "bundler", "version": version,
        "identity": {"osv": {"ecosystem": "RubyGems", "name": "bundler"}},
        "drvPath": "/nix/store/private-derivation.drv", "usedBy": ["private-application"],
    }


def advisory(identifier="TEST-2026-0001"):
    return {
        "id": identifier, "aliases": ["TEST-ALIAS"], "summary": "Synthetic advisory",
        "references": [{"type": "ADVISORY", "url": "https://example.invalid/advisory"}],
        "database_specific": {"severity": "HIGH"},
        "affected": [
            {"package": {"ecosystem": "RubyGems", "name": "bundler", "purl": "pkg:gem/bundler"},
             "ranges": [{"type": "ECOSYSTEM", "events": [{"introduced": "0"}, {"fixed": "1.1.0"}]}]},
            {"package": {"ecosystem": "RubyGems", "name": "unrelated"},
             "ranges": [{"type": "ECOSYSTEM", "events": [{"fixed": "99.0"}]}]},
        ],
    }


class OSVAdapterTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tvp-osv-test-")
        self.addCleanup(self.temporary.cleanup)
        self.cache = Path(self.temporary.name) / "cache"

    def scan(self, components=None, **kwargs):
        return audit_osv.scan(components or [component()], cache_dir=self.cache, **kwargs)

    def fetch_advisory(self, record=None):
        record = advisory() if record is None else record
        return patch.object(audit_osv, "_request", side_effect=[
            {"results": [{"vulns": [{"id": record["id"]}]}]}, record,
        ])

    def test_complete_pages_details_deduplication_and_query_privacy(self):
        first = advisory()
        second = advisory("TEST-2026-0002")
        second.pop("database_specific")
        second["severity"] = [{"type": "CVSS_V3", "score": "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H"}]
        with patch.object(audit_osv, "_request", side_effect=[
            {"results": [{"vulns": [{"id": first["id"]}], "next_page_token": "page-2"}]},
            {"results": [{"vulns": [{"id": second["id"]}, {"id": first["id"]}]}]},
            first, second,
        ]) as request:
            result = self.scan([component(), component("variant-b"), {
                "id": "unmapped", "version": "1", "identity": {},
            }])
        self.assertEqual(request.call_count, 4)
        self.assertEqual(request.call_args_list[0].args, ("/querybatch", {"queries": [{
            "package": {"name": "bundler", "ecosystem": "RubyGems"}, "version": "1.0.0",
        }]}))
        transmitted = json.dumps([call.args for call in request.call_args_list])
        self.assertNotIn("private", transmitted)
        self.assertNotIn("variant", transmitted)
        self.assertEqual(result["results"][0]["vulnerabilities"], result["results"][1]["vulnerabilities"])
        found = result["results"][0]["vulnerabilities"]
        self.assertEqual(found[0]["severity"], "high")
        self.assertEqual(found[0]["fixedVersions"], ["1.1.0"])
        self.assertEqual(found[0]["aliases"], ["TEST-ALIAS"])
        self.assertEqual(found[1]["severity"], "unknown")
        self.assertEqual(result["results"][2]["status"], "unsupported")
        self.assertEqual(result["database"]["kind"], "query-responses")
        self.assertEqual(result["database"]["queries"], 1)
        self.assertEqual(len(list(self.cache.iterdir())), 1)

    def test_cache_reuse_offline_age_and_expired_online_refresh(self):
        with self.fetch_advisory():
            initial = self.scan()
        with patch.object(audit_osv, "_request") as request:
            reused = self.scan()
            offline = self.scan(offline=True)
            request.assert_not_called()
        self.assertEqual(reused["database"]["cachedQueries"], 1)
        self.assertEqual(offline["results"], initial["results"])
        self.assertEqual(offline["database"]["sha256"], initial["database"]["sha256"])
        cached_file, = self.cache.glob("*.json")
        entry = json.loads(cached_file.read_text())
        entry["retrievedAt"] = (datetime.now(timezone.utc) - timedelta(days=2)).isoformat()
        cached_file.write_text(json.dumps(entry))
        with patch.object(audit_osv, "_request") as request:
            old = self.scan(offline=True)
            request.assert_not_called()
        self.assertTrue(old["database"]["stale"])
        self.assertGreaterEqual(old["database"]["maxAgeSeconds"], 2 * 86400)
        with patch.object(audit_osv, "_request", return_value={"results": [{}]}) as request:
            refreshed = self.scan()
        request.assert_called_once()
        self.assertFalse(refreshed["database"]["stale"])
        self.assertNotEqual(refreshed["database"]["sha256"], initial["database"]["sha256"])
        self.assertEqual(refreshed["results"][0]["vulnerabilities"], [])

    def test_missing_cache_and_corrupt_cache_are_errors(self):
        with patch.object(audit_osv, "_request") as request:
            with self.assertRaisesRegex(RuntimeError, "offline mode needs"):
                self.scan(offline=True)
            request.assert_not_called()
        with self.fetch_advisory():
            self.scan()
        cached_file, = self.cache.glob("*.json")
        entry = json.loads(cached_file.read_text())
        entry["records"][0]["summary"] = "modified after digest"
        cached_file.write_text(json.dumps(entry))
        with self.assertRaisesRegex(ValueError, "digest differs"):
            self.scan(offline=True)

    def test_invalid_batches_and_incomplete_pagination_never_cache_clean_results(self):
        invalid = [
            {"results": []}, {"results": [None]}, {"results": [{"vulns": None}]},
            {"results": [{"error": "query failed"}]},
            {"results": [{"next_page_token": 123}]},
            {"results": [{"vulns": [{"modified": "no identifier"}]}]},
        ]
        for response in invalid:
            with self.subTest(response=response), patch.object(audit_osv, "_request", return_value=response):
                with self.assertRaises(ValueError):
                    self.scan()
                self.assertFalse(self.cache.exists())
        response = {"results": [{"next_page_token": "repeated"}]}
        with patch.object(audit_osv, "_request", return_value=response):
            with self.assertRaisesRegex(ValueError, "pagination did not complete"):
                self.scan()
        self.assertFalse(self.cache.exists())

    def test_detail_mismatch_and_malformed_metadata_are_errors(self):
        invalid = [
            {"id": "different"}, {**advisory(), "aliases": [42]},
            {**advisory(), "withdrawn": True}, {**advisory(), "affected": None},
        ]
        for record in invalid:
            with self.subTest(record=record), patch.object(audit_osv, "_request", side_effect=[
                {"results": [{"vulns": [{"id": "TEST-2026-0001"}]}]}, record,
            ]):
                with self.assertRaises(ValueError):
                    self.scan()
                self.assertFalse(self.cache.exists())

    def test_unsupported_components_do_not_make_requests_or_create_cache(self):
        with patch.object(audit_osv, "_request") as request:
            result = self.scan([{"id": "missing", "version": "1", "identity": {}}, component(version=None)])
        request.assert_not_called()
        self.assertTrue(all(item["status"] == "unsupported" for item in result["results"]))
        self.assertFalse(self.cache.exists())
        self.assertIsNone(result["database"]["oldestResponseAt"])

    def test_declared_git_tag_query_and_fixed_commit_is_not_a_release(self):
        selected = component()
        selected["identity"]["osv"] = {
            "ecosystem": "GIT", "name": "https://github.com/example/project.git", "version": "v1_0_0",
        }
        record = advisory()
        record["affected"] = [{
            "package": selected["identity"]["osv"],
            "ranges": [{"type": "GIT", "events": [{"fixed": "a" * 40}]}],
        }]
        with self.fetch_advisory(record) as request:
            result = self.scan([selected])
        sent = request.call_args_list[0].args[1]["queries"][0]
        self.assertEqual(sent["version"], "v1_0_0")
        self.assertNotIn("version", sent["package"])
        self.assertEqual(result["results"][0]["vulnerabilities"][0]["fixedVersions"], [])
        selected["identity"]["osv"]["version"] = ""
        with self.assertRaisesRegex(ValueError, "Invalid OSV query version"):
            self.scan([selected])

    def test_withdrawn_record_and_missing_package_metadata(self):
        record = advisory()
        record["affected"] = [{"ranges": [{"type": "ECOSYSTEM", "events": [{"fixed": "1.1.0"}]}]}]
        with self.fetch_advisory(record):
            result = self.scan()
        self.assertEqual(len(result["results"][0]["vulnerabilities"]), 1)
        self.assertEqual(result["results"][0]["vulnerabilities"][0]["fixedVersions"], [])
        record["withdrawn"] = "2026-01-01T00:00:00Z"
        with tempfile.TemporaryDirectory() as cache, self.fetch_advisory(record):
            result = audit_osv.scan([component()], cache_dir=cache)
        self.assertEqual(result["results"][0]["vulnerabilities"], [])

    def test_git_query_attributes_release_fixes_only_to_the_same_repository(self):
        selected = component()
        repository = "https://github.com/example/project.git"
        selected["identity"]["osv"] = {"ecosystem": "GIT", "name": repository}
        record = advisory()
        record["affected"] = [
            {"ranges": [
                {"type": "SEMVER", "events": [{"introduced": "0"}, {"fixed": "1.1.0"}]},
                {"type": "GIT", "repo": repository, "events": [{"fixed": "a" * 40}]},
            ]},
            {"ranges": [
                {"type": "SEMVER", "events": [{"fixed": "99.0"}]},
                {"type": "GIT", "repo": "https://example.invalid/other.git", "events": []},
            ]},
        ]
        with self.fetch_advisory(record):
            result = self.scan([selected])
        self.assertEqual(result["results"][0]["vulnerabilities"][0]["fixedVersions"], ["1.1.0"])


if __name__ == "__main__":
    unittest.main()

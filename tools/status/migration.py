"""Pure migration inventory renderer. Runtime reads JSON only; no Nix APIs."""
import argparse
import json
from pathlib import Path
import sys


class Invalid(ValueError):
    pass


def obj(value, where):
    if not isinstance(value, dict):
        raise Invalid(f"{where}: expected an object")
    return value


def array(value, where):
    if not isinstance(value, list):
        raise Invalid(f"{where}: expected an array")
    return value


def string(value, where, nullable=False):
    if nullable and value is None:
        return None
    if not isinstance(value, str) or not value.strip() or len(value) > 1024:
        raise Invalid(f"{where}: expected a nonempty string (at most 1024 characters)")
    if any(ord(c) < 32 for c in value):
        raise Invalid(f"{where}: control characters are not supported")
    return value


def boolean(value, where, nullable=False):
    if nullable and value is None:
        return None
    if type(value) is not bool:
        raise Invalid(f"{where}: expected a boolean")
    return value


def count(value, where):
    if value is None:
        return None
    if type(value) is not int or value < 0:
        raise Invalid(f"{where}: expected a nonnegative integer or null")
    return value


def load(path):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise Invalid(f"duplicate JSON key: {key}")
            result[key] = value
        return result
    with Path(path).open(encoding="utf-8") as stream:
        return json.load(stream, object_pairs_hook=pairs)


def binding_source(value):
    value = obj(value, "source")
    return {key: string(value.get(key), f"source.{key}", True)
            for key in ("path", "revision", "tree", "narHash")}


def provider_facts(value, where):
    value = obj(value, where)
    result = {key: string(value.get(key), f"{where}.{key}", key != "path")
              for key in ("name", "version", "drvPath", "path", "builtBy")}
    selection = value.get("selection")
    result["selection"] = (None if selection is None else {
        string(key, f"{where}.selection key"): string(item, f"{where}.selection.{key}", True)
        for key, item in obj(selection, f"{where}.selection").items()})
    return result


def build_context(value, row):
    if value is None:
        return None
    obj(value, "row.buildContext")
    if row["status"] == "broken" or row["constructor"] == "unavailable":
        raise Invalid("broken or unavailable row must not claim a build context")
    base = obj(value.get("base"), "buildContext.base")
    base_name = string(base.get("name"), "buildContext.base.name", True)
    if row.get("selectedBase") != base_name:
        raise Invalid("build context disagrees with selected base")
    construction = base.get("construction")
    if construction is not None:
        construction = {
            string(key, "buildContext.base.construction key"):
            string(item, f"buildContext.base.construction.{key}", True)
            for key, item in obj(construction, "buildContext.base.construction").items()}
    tools = {}
    for name, tool in obj(value.get("usedTools"), "buildContext.usedTools").items():
        string(name, "buildContext used tool name")
        provider = provider_facts(tool, f"buildContext.usedTools.{name}")
        role = string(tool.get("role"), f"buildContext.usedTools.{name}.role")
        origin = string(tool.get("origin"), f"buildContext.usedTools.{name}.origin")
        if origin not in ("selected-base", "package-dependency"):
            raise Invalid("unknown used tool provider origin")
        tools[name] = {**provider, "role": role, "origin": origin}
    providers = {key: provider_facts(value.get(key), f"buildContext.{key}")
                 for key in ("gcc", "binutils", "libc")}
    return {"system": string(value.get("system"), "buildContext.system"),
            "compilerVersion": string(value.get("compilerVersion", providers["gcc"]["version"]), "buildContext.compilerVersion", True),
            "config": string(value.get("config"), "buildContext.config", True),
            "base": {"name": base_name, "construction": construction},
            **providers,
            "usedTools": tools}


def summarize_contexts(rows):
    selections = {}
    for row in rows:
        context = row["buildContext"]
        if context is None:
            continue
        selection = {key: value for key, value in context.items() if key != "usedTools"}
        key = json.dumps(selection, sort_keys=True)
        if key not in selections:
            selections[key] = {**selection, "rows": 0}
        selections[key]["rows"] += 1
    return {"availableRows": sum(r["buildContext"] is not None for r in rows),
            "unknownRows": sum(r["buildContext"] is None and r["status"] != "broken"
                               and r["constructor"] != "unavailable" for r in rows),
            "excludedBrokenRows": sum(r["status"] == "broken" or r["constructor"] == "unavailable"
                                      for r in rows),
            "selections": [selections[key] for key in sorted(selections)]}


def summarize(rows):
    constructors = {key: sum(r["constructor"] == key for r in rows)
                    for key in ("owned", "legacy", "native-plan", "unavailable")}
    return {
        "total": len(rows),
        "canonical": sum(r["namespace"] == "canonical" for r in rows),
        "publicVariants": sum(r["namespace"] != "canonical" for r in rows),
        "declaredBroken": sum(r["status"] == "broken" for r in rows),
        "constructors": constructors,
        "sourceCandidateSelected": sum(r["selectedBase"] == "source-gnu-candidate" for r in rows),
        "splitCompliant": sum(r["compliant"] for r in rows),
        "splitDebt": sum(not r["compliant"] for r in rows),
        "remainingLegacyPorts": constructors["legacy"],
        "ownedUnsplit": sum(r["failure"] == "owned-unsplit" for r in rows),
        "otherSplitDebt": sum(not r["compliant"] and r["failure"] not in
                              ("legacy-no-plan", "owned-unsplit") for r in rows),
    }



AUTHORING_ORIGIN = {"origin": "tvp.lib.packages.mkFamily", "model": "ordinary-family/v1"}


def authoring(facts, rows, family=None):
    """Index declarations only: never infer builder/caller/runtime completion."""
    unknown = {
        "compatibilityCallersRemaining": None,
        "builderCleanupVerified": None,
        "runtimeQualifiedRows": None,
    }
    if facts is None:
        return {"measurement": "unavailable", "scope": "No evaluated family-origin facts supplied.",
                "summary": None, "categories": None, "families": None,
                "verification": unknown}
    obj(facts, "authoring")
    if facts.get("schema") != "tvp.family-authoring-facts/v1":
        raise Invalid("unsupported family-authoring facts schema")
    scope = string(facts.get("scope"), "authoring.scope")

    def origin(value):
        if value is None:
            return None
        obj(value, "authoring origin")
        return {key: string(value.get(key), f"authoring origin.{key}")
                for key in ("origin", "model")}

    def component(value, where):
        value = string(value, where)
        if "/" in value or value in (".", ".."):
            raise Invalid(f"{where}: expected a registration path component")
        return value

    entries, paths, owners = [], set(), {}
    for raw in array(facts.get("entries"), "authoring.entries"):
        obj(raw, "authoring entry")
        category = component(raw.get("category"), "authoring category")
        name = component(raw.get("family"), "authoring family")
        path = string(raw.get("entrypoint"), "authoring entrypoint")
        if path != f"pkgs/{category}/{name}/default.nix" or path in paths:
            raise Invalid("inconsistent or duplicate family entrypoint")
        paths.add(path)
        recipes = obj(raw.get("recipes"), "authoring recipes")
        if not recipes:
            raise Invalid("family entrypoint has no registered recipes")
        selected, models, retained = [], {}, False
        for recipe, metadata in recipes.items():
            string(recipe, "authoring recipe")
            if recipe in owners:
                raise Invalid("recipe belongs to multiple family entrypoints")
            owners[recipe] = path
            obj(metadata, "authoring recipe metadata")
            model = origin(metadata.get("origin"))
            models[recipe] = model
            versions = obj(metadata.get("versionOrigins"), "authoring version origins")
            version_origins = {}
            for version, value in versions.items():
                string(version, "authoring version")
                version_origins[version] = origin(value)
            retained = boolean(metadata.get("retainedConstructionRecipe"),
                               "authoring retained construction recipe") or retained
            for row in rows:
                if row["namespace"] == "canonical" and row["family"] == recipe:
                    selected.append({"broken": row["status"] == "broken",
                                     "marked": model == AUTHORING_ORIGIN
                                     and version_origins.get(row["version"]) == AUTHORING_ORIGIN})
        states = list(models.values())
        state = ("adopted" if all(value == AUTHORING_ORIGIN for value in states) else
                 "earlier-wiring" if all(value is None for value in states) else
                 "unrecognized" if any(value not in (None, AUTHORING_ORIGIN) for value in states) else
                 "partial")
        entries.append({"family": name, "category": category, "entrypoint": path,
                        "indexState": state, "origins": models,
                        "eligibleCanonicalRows": sum(not r["broken"] for r in selected),
                        "markedEligibleCanonicalRows": sum(not r["broken"] and r["marked"] for r in selected),
                        "excludedBrokenCanonicalRows": sum(r["broken"] for r in selected),
                        "retainedConstructionRecipe": retained,
                        "recipes": sorted(recipes)})
    if {r["family"] for r in rows if r["namespace"] == "canonical"} - set(owners):
        raise Invalid("family-origin inventory does not cover canonical families")
    selected = [entry for entry in entries if family is None or family in entry["recipes"]]

    def summary(values):
        return {"familyIndexes": len(values),
                "adoptedIndexes": sum(e["indexState"] == "adopted" for e in values),
                "earlierWiringIndexes": sum(e["indexState"] == "earlier-wiring" for e in values),
                "partialIndexes": sum(e["indexState"] == "partial" for e in values),
                "unrecognizedIndexes": sum(e["indexState"] == "unrecognized" for e in values),
                "eligibleCanonicalRows": sum(e["eligibleCanonicalRows"] for e in values),
                "markedEligibleCanonicalRows": sum(e["markedEligibleCanonicalRows"] for e in values),
                "excludedBrokenCanonicalRows": sum(e["excludedBrokenCanonicalRows"] for e in values),
                "indexesWithRetainedConstructionRecipe": sum(e["retainedConstructionRecipe"] for e in values)}

    return {"measurement": "evaluated-index-origin", "scope": scope,
            "summary": summary(selected),
            "categories": {category: summary([e for e in selected if e["category"] == category])
                           for category in sorted({e["category"] for e in selected})},
            "families": {entry["entrypoint"]: entry for entry in selected},
            "verification": unknown}

def repository(facts, family=None):
    obj(facts, "facts")
    if facts.get("schema") != "tvp.migration-facts/v1":
        raise Invalid("unsupported repository facts schema")
    rows, ids = [], set()
    failures = {
        "owned": {None, "owned-unsplit", "missing-owned-plan", "invalid-plan", "missing-artifact", "invalid-artifact-producer"},
        "legacy": {"legacy-no-plan"},
        "native-plan": {"native-plan-constructor", "invalid-plan"},
        "unavailable": {"evaluation-failed"},
    }
    for row in array(facts.get("rows"), "rows"):
        obj(row, "row")
        for key in ("id", "namespace", "name", "constructor", "family", "version", "status"):
            string(row.get(key), f"row.{key}")
        ns = row["namespace"]
        if ns != "canonical" and not ns.startswith("variants."):
            raise Invalid(f"unsupported namespace: {ns}")
        if row["id"] != f'{ns}/{row["name"]}' or row["id"] in ids:
            raise Invalid("inconsistent or duplicate inventory ID")
        ids.add(row["id"])
        constructor = row["constructor"]
        string(row.get("failure"), "row.failure", True)
        if constructor not in failures or row.get("failure") not in failures[constructor]:
            raise Invalid("unknown constructor/failure classification")
        if boolean(row.get("compliant"), "row.compliant") != (row.get("failure") is None):
            raise Invalid("contradictory split compliance")
        string(row.get("selectedBase"), "row.selectedBase", True)
        rows.append({**row, "buildContext": build_context(row.get("buildContext"), row)})
    families = sorted({r["family"] for r in rows})
    if family is not None and family not in families:
        raise Invalid(f"unknown family: {family}")
    latest = obj(facts.get("latest"), "latest")
    latest_rows = []
    for name, entry in obj(latest.get("families"), "latest.families").items():
        obj(entry, "latest entry")
        job = string(entry.get("job"), "latest.job")
        matches = [r for r in rows if r["id"] == f"canonical/{job}" and r["family"] == name]
        if len(matches) != 1 or matches[0]["status"] == "broken" or entry.get("version") != matches[0]["version"]:
            raise Invalid(f"latest selector does not match eligible canonical row: {name}")
        latest_rows.append(matches[0])
    skipped = array(latest.get("skipped"), "latest.skipped")
    for entry in skipped:
        obj(entry, "latest.skipped entry")
        string(entry.get("family"), "skipped.family")
        string(entry.get("reason"), "skipped.reason")
    canonical_families = {r["family"] for r in rows if r["namespace"] == "canonical"}
    skipped_names = [entry["family"] for entry in skipped]
    selected_names = set(latest["families"])
    if (len(skipped_names) != len(set(skipped_names)) or selected_names & set(skipped_names)
            or selected_names | set(skipped_names) != canonical_families):
        raise Invalid("latest selected/skipped families do not cover canonical families exactly")
    for name in skipped_names:
        if any(r["status"] != "broken" for r in rows if r["namespace"] == "canonical" and r["family"] == name):
            raise Invalid("latest skipped family has an eligible release")
    policy = obj(facts.get("splitPolicy"), "splitPolicy")
    string(policy.get("status"), "splitPolicy.status")
    boolean(policy.get("success"), "splitPolicy.success")
    if boolean(policy.get("allSplit"), "splitPolicy.allSplit") != all(r["compliant"] for r in rows):
        raise Invalid("split policy disagrees with inventory")
    for error in array(policy.get("errors"), "splitPolicy.errors"):
        string(error, "splitPolicy error")
    outside = obj(facts.get("outsideOrdinaryScope"), "outsideOrdinaryScope")
    string(outside.get("disposition"), "outsideOrdinaryScope.disposition")
    for name, entry in obj(outside.get("producers"), "outside producers").items():
        string(name, "outside producer ID")
        obj(entry, "outside producer")
        for key in ("role", "disposition", "validation"):
            string(entry.get(key), f"outside producer.{key}")
    selected = [r for r in rows if family is None or r["family"] == family]
    selected_latest = [r for r in latest_rows if family is None or r["family"] == family]
    return {
        "scope": string(facts.get("scope"), "scope"),
        "filter": family,
        "summary": summarize(selected),
        "buildContexts": summarize_contexts(selected),
        "splitPolicy": policy,
        "strictSplitAdmission": "eligible" if policy["success"] and all(r["compliant"] for r in rows) else "blocked",
        "families": {name: summarize([r for r in selected if r["family"] == name])
                     for name in families if family is None or family == name},
        "latest": {"summary": summarize(selected_latest),
                   "measurement": string(latest.get("measurement", "unspecified"), "latest.measurement"),
                   "runtimeQualifiedRows": None,
                   "selected": [{"family": r["family"], "job": r["name"], "version": r["version"],
                                 "constructor": r["constructor"], "selectedBase": r["selectedBase"]}
                                for r in selected_latest],
                   "skipped": [s for s in skipped if family is None or s["family"] == family]},
        "rows": selected,
        "outsideOrdinaryScope": outside,
        "authoring": authoring(facts.get("authoring"), rows, family),
    }


def workflow(data, source):
    obj(data, "workflow")
    if type(data.get("schema")) is not int or data["schema"] != 1:
        raise Invalid("unsupported workflow schema (expected schema: 1)")
    def record(key):
        return obj(data.get(key, {}), f"workflow.{key}")
    def text(value, key):
        return string(value, key, True)
    baseline = record("workingBaseline")
    recorded = {"path": baseline.get("normalized", baseline.get("source", baseline.get("path"))),
                "revision": baseline.get("revision", baseline.get("head")),
                "tree": baseline.get("tree"), "narHash": baseline.get("narHash")}
    recorded = binding_source(recorded)
    comparable = [(source[k], recorded[k]) for k in source if source[k] is not None and recorded[k] is not None]
    state = ("unbound" if not comparable else
             "different-source" if any(a != b for a, b in comparable) else "matching-source")
    pause = data.get("pausedByUser")
    if pause is not None and type(pause) is not bool and not isinstance(pause, dict):
        raise Invalid("workflow.pausedByUser: expected a boolean or object")
    if isinstance(pause, dict):
        paused = pause.get("noNewWorkUntilUserResumes")
        boolean(paused, "pausedByUser.noNewWorkUntilUserResumes", True)
        paused = paused is True or pause.get("status") == "PAUSED_BY_USER"
    else:
        paused = pause is True
    status = text(data.get("status"), "workflow.status")
    older = record("olderRecipeMigration")
    accepted = {
        "acceptedOlderPorts": count(older.get("ordinaryReleasesPortedThisPass"), "accepted older ports"),
        "representativeNamedQualified": count(older.get("representativesBuiltThisPass"), "representative named qualified"),
        "withoutRepresentativeCompilation": count(older.get("evaluationOnlyThisPass"), "without representative compilation"),
        "extraArtifactBuildsWithoutNamedQualification": count(older.get("additionalArtifactBuildsWithoutNamedQualificationThisPass"), "extra artifact builds"),
    }
    parts = list(accepted.values())
    if parts[0] is not None and sum(v for v in parts[1:] if v is not None) > parts[0]:
        raise Invalid("qualification counters exceed accepted older ports")
    if all(v is not None for v in parts) and parts[0] != sum(parts[1:]):
        raise Invalid("accepted qualification counters do not sum to accepted older ports")
    waves = record("waves")
    pending = []
    # An allowlist of display fields: never expose raw task/evidence/operator records.
    current_wave = text(data.get("currentWave"), "workflow.currentWave")
    normalize = lambda name: "".join(c.lower() for c in name if c.isalnum())
    current_matches = []
    for name, batch in waves.items():
        obj(batch, "workflow wave")
        if current_wave is not None and normalize(name) == normalize(current_wave):
            current_matches.append((name, batch))
    if len(current_matches) > 1:
        raise Invalid("ambiguous currentWave batch binding")
    current_batch = None
    for name, batch in current_matches:
        is_accepted = boolean(batch.get("sourceAccepted"), "wave.sourceAccepted", True)
        item = {"batch": string(name, "batch"), "status": text(batch.get("status"), "batch.status"),
                "sourceAccepted": is_accepted}
        for key in ("selectedReleases", "implementedReleases", "representativesBuilt"):
            item[key] = count(batch.get(key), f"batch.{key}")
        uncompiled = batch.get("preflightEvaluationOnly")
        if uncompiled is not None:
            for value in array(uncompiled, "batch.preflightEvaluationOnly"):
                string(value, "uncompiled release")
            if len(uncompiled) != len(set(uncompiled)):
                raise Invalid("duplicate uncompiled release")
        item["withoutCompilation"] = None if uncompiled is None else len(uncompiled)
        selected = item["selectedReleases"]
        for key in ("implementedReleases", "representativesBuilt", "withoutCompilation"):
            if selected is not None and item[key] is not None and item[key] > selected:
                raise Invalid(f"batch.{key} exceeds selected releases")
        representatives = item["representativesBuilt"]
        implemented = item["implementedReleases"]
        if representatives is not None and implemented is not None and representatives > implemented:
            raise Invalid("batch representatives exceed implemented releases")
        if (selected is not None and representatives is not None and item["withoutCompilation"] is not None
                and representatives + item["withoutCompilation"] > selected):
            raise Invalid("batch qualification counters exceed selected releases")
        task = obj(batch.get("implementationTask", {}), "batch.implementationTask")
        subject = obj(batch.get("source", {}), "batch.source")
        item["PR"] = text(subject.get("PR", task.get("PR")), "batch.PR")
        item["sourceReviewPending"] = boolean(batch.get("sourceReviewPending"), "batch.sourceReviewPending", True)
        current_batch = item
        if is_accepted is False:
            pending.append(item)
    holds = []
    for name, hold in record("pendingDownstreamQualification").items():
        obj(hold, "hold")
        holds.append({"name": string(name, "hold.name"), "status": text(hold.get("status"), "hold.status"),
                      "count": count(hold.get("count"), "hold.count"),
                      "requiredBeforeDefaultSwitch": boolean(hold.get("requiredBeforeDefaultSwitch"), "hold.requiredBeforeDefaultSwitch", True)})
    hardening = record("defaultSwitchHardeningGate")
    ci = record("ci")
    pause_details = ({key: text(pause.get(key), f"pause.{key}") for key in ("at", "R1", "R2")}
                     if isinstance(pause, dict) else None)
    return {
        "authority": "External reported claims; no certification or fresh execution proof.",
        "binding": {"state": state, "recordedBaseline": recorded,
                    "updatedAt": text(data.get("updatedAt"), "workflow.updatedAt")},
        "status": "paused" if paused else status,
        "currentWave": current_wave,
        "currentStep": text(data.get("currentStep"), "workflow.currentStep"),
        "pause": pause_details, "accepted": accepted,
        "currentBatch": current_batch,
        "pendingBatches": pending if current_batch is not None and current_batch["sourceAccepted"] is not None else None,
        "holds": holds if "pendingDownstreamQualification" in data else None,
        "gates": {"CI": text(ci.get("status"), "ci.status"),
                  "defaultSwitchHardening": text(hardening.get("status"), "hardening.status"),
                  "defaultSwitchBlocked": boolean(hardening.get("defaultSwitchBlocked"), "defaultSwitchBlocked", True),
                  "splitAudit": text(record("splitAudit").get("status"), "splitAudit.status")},
    }


def report(facts, family=None, external=None):
    source = binding_source(obj(facts, "facts").get("source"))
    return {"schema": "tvp.migration-status/v1", "source": source,
            "system": string(facts.get("system"), "system"),
            "repository": repository(facts, family),
            "workflow": None if external is None else workflow(external, source),
            "limitations": ["Evaluated metadata only: source selection is not realization, test execution, review acceptance or admission.",
                            "Selected base metadata does not prove source-built bootstrap inputs or conformance.",
                            "Strict split eligibility is only one gate; full validation, hardening and default switch remain separate.",
                            "A mkFamily origin marks ordinary index adoption only; builder cleanup, construction callers and runtime qualification are separate and unmeasured here."]}


def render(result):
    def show(value):
        return "unknown" if value is None else str(value).lower() if type(value) is bool else str(value)
    repo = result["repository"]
    s, latest = repo["summary"], repo["latest"]["summary"]
    lines = ["MIGRATION — evaluated repository facts", f'Source: {show(result["source"]["path"])} ({result["system"]})',
             f'Ordinary policy: {s["total"]} rows = {s["canonical"]} canonical + {s["publicVariants"]} public variants; {s["declaredBroken"]} declared broken (included)',
             'Constructors: ' + "; ".join(f"{k} {v}" for k, v in s["constructors"].items()),
             f'Selected source-gnu-candidate base: {s["sourceCandidateSelected"]}/{s["total"]}',
             f'Split compliant: {s["splitCompliant"]}/{s["total"]}; debt {s["splitDebt"]} (legacy ports {s["remainingLegacyPorts"]}, owned-unsplit {s["ownedUnsplit"]}, other {s["otherSplitDebt"]})',
             f'Strict split admission (whole inventory): {repo["strictSplitAdmission"]}; policy {repo["splitPolicy"]["status"]}',
             f'Latest applicable selectors: {latest["total"]} families; owned {latest["constructors"]["owned"]}/{latest["total"]}; selected candidate base {latest["sourceCandidateSelected"]}/{latest["total"]}; skipped {len(repo["latest"]["skipped"])}',
             'Outside ordinary policy: ' + repo["outsideOrdinaryScope"]["disposition"]]
    lines.append(f'Latest view: {repo["latest"]["measurement"]}; test-suite and runtime qualification unknown.')
    contexts = repo["buildContexts"]
    lines.append(f'Effective build contexts: {contexts["availableRows"]} supplied; {contexts["unknownRows"]} unknown; {contexts["excludedBrokenRows"]} broken/unavailable excluded.')

    def provider_name(provider):
        return " ".join(str(provider[key]) for key in ("name", "version")
                        if provider[key] is not None) or "unknown"

    for index, context in enumerate(contexts["selections"], 1):
        lines.append(f'  Context {index} ({context["rows"]} rows): {context["system"]}; target {show(context["config"])}; base {show(context["base"]["name"])}; GCC {show(context["compilerVersion"])}; driver {provider_name(context["gcc"])}; Binutils {provider_name(context["binutils"])}; libc {provider_name(context["libc"])}')
        if context["base"]["construction"] is not None:
            lines.append("    Construction: " + "; ".join(
                f"{key}={show(value)}" for key, value in context["base"]["construction"].items()))
    adoption = repo["authoring"]
    lines.extend(["", "AUTHORING — ordinary family index adoption"])
    if adoption["summary"] is None:
        lines.append("Index adoption: unknown; this manifest has no evaluated family-origin inventory.")
    else:
        a = adoption["summary"]
        lines.extend([
            f'Indexes using mkFamily: {a["adoptedIndexes"]}/{a["familyIndexes"]}; earlier wiring {a["earlierWiringIndexes"]}; partial {a["partialIndexes"]}; unrecognized {a["unrecognizedIndexes"]}',
            f'Eligible canonical rows in marked definitions: {a["markedEligibleCanonicalRows"]}/{a["eligibleCanonicalRows"]}; declared-broken excluded {a["excludedBrokenCanonicalRows"]}',
            "By category (indexes; eligible canonical rows):",
        ])
        for category, value in adoption["categories"].items():
            lines.append(f'  {category}: {value["adoptedIndexes"]}/{value["familyIndexes"]}; {value["markedEligibleCanonicalRows"]}/{value["eligibleCanonicalRows"]}')
        lines.append(f'Retained construction recipe definitions present in {a["indexesWithRetainedConstructionRecipe"]}/{a["familyIndexes"]} indexes; this is not a caller count.')
    lines.append("Builder cleanup verified: unknown; compatibility callers remaining: unknown; runtime-qualified rows: unknown.")
    lines.append("Index adoption is separate from split coverage and full migration completion.")
    if repo["filter"]:
        lines.append(f'Family {repo["filter"]} (workflow and outside-scope remain global):')
        for entry in (adoption["families"] or {}).values():
            lines.append(f'  {entry["entrypoint"]}: index {entry["indexState"]}; retained construction recipe {show(entry["retainedConstructionRecipe"])}')
        for row in repo["rows"]:
            context = row["buildContext"]
            selected = None if context is None else {
                key: value for key, value in context.items() if key != "usedTools"}
            index = next((index for index, item in enumerate(contexts["selections"], 1)
                          if selected == {key: value for key, value in item.items() if key != "rows"}), None)
            lines.append(f'  {row["id"]} {row["version"]}: {row["constructor"]}; base {show(row["selectedBase"])}; {row["failure"] or "split-compliant"}; {row["status"]}; context {show(index)}')
        providers = {}
        for row in repo["rows"]:
            for name, provider in (row["buildContext"] or {}).get("usedTools", {}).items():
                key = (name, json.dumps(provider, sort_keys=True))
                if key not in providers:
                    providers[key] = {"name": name, "provider": provider, "rows": 0}
                providers[key]["rows"] += 1
        if providers:
            lines.append("Used named tools (tracked production dependencies; distinct selections):")
            for key in sorted(providers):
                entry = providers[key]
                provider = entry["provider"]
                lines.append(f'  {entry["name"]} (role {provider["role"]}, {entry["rows"]} rows): {provider_name(provider)}; {provider["origin"]}; built by {show(provider["builtBy"])}')
                lines.append(f'    Output: {provider["path"]}')
                if provider["selection"]:
                    lines.append("    Selection: " + "; ".join(
                        f"{name}={show(value)}" for name, value in provider["selection"].items()))
        elif contexts["availableRows"]:
            lines.append("Used named tools: none recorded in tracked production dependencies.")
    w = result["workflow"]
    lines.extend(["", "WORKFLOW — optional external reported claims"])
    if w is None:
        lines.append("Not supplied; qualification, pause, holds and CI are unknown. Use --workflow /absolute/progress.json.")
    else:
        lines.extend([f'Binding: {w["binding"]["state"]}; recorded source {show(w["binding"]["recordedBaseline"]["path"])}; updated {show(w["binding"]["updatedAt"])}',
                      f'Status: {show(w["status"])}; wave {show(w["currentWave"])}; step {show(w["currentStep"])}',
                      "Accepted older ports (separate from pending batches): " + "; ".join(f"{k}={show(v)}" for k, v in w["accepted"].items())])
        if w["pendingBatches"] is None:
            lines.append("Pending batches: unknown")
        for b in [w["currentBatch"]] if w["currentBatch"] else []:
            lines.append("Current batch (separate from accepted counts): " + "; ".join(f"{k}={show(v)}" for k, v in b.items()))
        lines.append("Holds: " + ("unknown" if w["holds"] is None else json.dumps(w["holds"], sort_keys=True)))
        lines.append("Gates: " + "; ".join(f"{k}={show(v)}" for k, v in w["gates"].items()))
        if w["pause"]:
            lines.append("Pause: " + "; ".join(f"{k}={show(v)}" for k, v in w["pause"].items()))
        lines.append(w["authority"])
    lines.extend(["", *result["limitations"], "Details: --migration --family NAME / --migration --json"])
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tvp-status --migration", allow_abbrev=False,
                                     description="Read baked evaluated migration facts; never query Nix or the store. Legacy status and --json retain store measurement.")
    parser.add_argument("--migration", action="store_true")
    parser.add_argument("--json", action="store_true", help="emit tvp.migration-status/v1")
    parser.add_argument("--family", help="filter repository facts to one exact family; workflow stays global")
    parser.add_argument("--workflow", type=Path, help="explicit absolute schema-1 progress JSON; claims only")
    args = parser.parse_args(argv)
    if not args.migration:
        parser.error("--family/--workflow require --migration")
    if args.workflow is not None and not args.workflow.is_absolute():
        parser.error("--workflow requires an absolute path")
    try:
        facts = load(Path(__file__).with_name("manifest.json"))
        result = report(facts, args.family, None if args.workflow is None else load(args.workflow))
        print(json.dumps(result, sort_keys=True, indent=2) if args.json else render(result))
    except (Invalid, OSError, ValueError, TypeError, KeyError) as error:
        parser.exit(2, f"tvp-status: {error}\n")


if __name__ == "__main__":
    main()

"""Read and compare a downstream flake's selected TVP packages."""

from collections import defaultdict
from contextlib import contextmanager
from copy import deepcopy
import json
from pathlib import Path
import re
import subprocess
import tempfile


INVENTORY = r"""
includeSecurity:
subject:
let
  isPackage = value: builtins.isAttrs value && (value.type or null) == "derivation";
  record = role: location: package:
    let
      selection = package.__tvpSelection or { };
    in {
      inherit role location;
      namespace = selection.namespace or null;
      selector = selection.selector or null;
      kind = selection.kind or "unknown";
      pname = package.pname or (selection.pname or package.name);
      version = package.version or (selection.version or null);
      inherit (package) drvPath;
      outputName = package.outputName or "out";
    } // (if includeSecurity then {
      security = package.tvp.security or null;
    } else { });
  managed = role: location: package:
    if isPackage package && package ? __tvpSelection
    then [ (record role location package) ] else [ ];
  inventoryError = location: message:
    throw "TVP inventory at ${location}: ${message}";
  inventoryReferences = location: references:
    if isPackage references then
      if references ? tvpInventory
      then inventoryContract "${location}.tvpInventory" references.tvpInventory
      else managed "package" location references
    else if builtins.isAttrs references then
      builtins.concatMap (name:
        inventoryReferences "${location}.${name}" references.${name}
      ) (builtins.attrNames references)
    else if builtins.isList references then
      builtins.concatLists (builtins.genList (index:
        inventoryReferences "${location}[${toString index}]" (builtins.elemAt references index)
      ) (builtins.length references))
    else inventoryError location "expected a package reference, attribute set or list";
  inventoryContract = location: contract:
    if !builtins.isAttrs contract then
      inventoryError location "tvpInventory must be an attribute set"
    else if !(contract ? schema) || !builtins.isInt contract.schema || contract.schema != 1 then
      inventoryError location "unsupported tvpInventory schema; expected schema = 1"
    else if !(contract ? packages) || !builtins.isAttrs contract.packages || isPackage contract.packages then
      inventoryError location "tvpInventory.packages must be an attribute set"
    else inventoryReferences "${location}.packages" contract.packages;
  observeGem = location: gem:
    let
      gemName = gem.gemName or (gem.pname or gem.name);
      providers = gem.nativeProviders or { };
    in builtins.concatMap (providerName:
      map (row: row // { inherit gemName providerName; })
        (managed "ruby-native-package" "${location}.nativeProviders.${providerName}" providers.${providerName})
    ) (builtins.attrNames providers);
  observe = location: package:
    if !isPackage package then [ ]
    else if package ? tvpInventory then
      inventoryContract "${location}.tvpInventory" package.tvpInventory
    else if (package.tvp.kind or null) == "ruby-application" && package ? bundle then
      observe "${location}.bundle" package.bundle
    else if (package.tvp.kind or null) == "ruby-bundle"
        && package ? ruby && package ? bundler && package ? gems then
      managed "ruby-engine" "${location}.ruby" package.ruby
      ++ managed "ruby-manager" "${location}.bundler" package.bundler
      ++ builtins.concatMap (name:
        let
          gem = package.gems.${name};
        in observeGem "${location}.gems.${name}" (gem // { gemName = gem.gemName or name; })
      ) (builtins.attrNames package.gems)
    else if (package.tvp.kind or null) == "ruby-gem"
        || (package ? gemName && package ? ruby && package ? nativeProviders) then
      observeRuby location package
      ++ observeGem location package
    else if (package.tvp.kind or null) == "php-runtime"
        && package ? unwrapped && package ? enabledExtensions then
      managed "php-engine" "${location}.unwrapped" package.unwrapped
      ++ builtins.concatMap (extension:
        managed "php-extension" "${location}.enabledExtensions.${extension.extensionName}" extension
      ) package.enabledExtensions
    else if package ? __tvpSelection then [ (record "package" location package) ]
    else [ ];
  observeRuby = location: package:
    if package ? ruby then managed "ruby-engine" "${location}.ruby" package.ruby else [ ];
  observeInputs = name:
    let values = subject.${name} or [ ];
    in if builtins.isList values then builtins.concatLists (builtins.genList
      (index: observe "${name}[${toString index}]" (builtins.elemAt values index))
      (builtins.length values)
    ) else [ ];
in
if !isPackage subject then throw "TVP inventory expects a package or dev shell derivation"
else observe "output" subject
  ++ (if subject ? tvpInventory then [ ] else builtins.concatMap observeInputs [
    "buildInputs" "nativeBuildInputs" "propagatedBuildInputs" "propagatedNativeBuildInputs"
  ])
"""


def nix_json(arguments, *, capture_errors=False):
    result = subprocess.run(["nix", *arguments], check=True, stdout=subprocess.PIPE, text=True,
                            **({"stderr": subprocess.PIPE} if capture_errors else {}))
    return json.loads(result.stdout)


def locked_input(lock_graph, input_name):
    """Resolve a lock input path, including inputs which follow another path."""
    root = lock_graph["root"]
    nodes = lock_graph["nodes"]

    def descend(node, path, following):
        for component in path:
            target = nodes[node].get("inputs", {}).get(component)
            if isinstance(target, list):
                link = (node, component)
                if link in following:
                    raise ValueError(f"Lock input {input_name!r} has a circular follows path")
                node = descend(root, target, following | {link})
            elif isinstance(target, str) and target in nodes:
                node = target
            else:
                raise ValueError(f"Lock file does not contain input {input_name!r}")
        return node

    node = descend(root, input_name.split("/"), set())
    locked = nodes[node].get("locked")
    if not isinstance(locked, dict):
        raise ValueError(f"Input {input_name!r} has no locked source")
    return {"name": input_name, "locked": locked}


SUPPORTED_OUTPUTS = ("devShells", "packages", "checks", "formatter")
SKIPPED_OUTPUT_REASONS = {
    "apps": "app program paths do not expose package inventory",
    "legacyPackages": "nested package collections require an explicit --attr",
    "nixosConfigurations": "system configurations require a dedicated inventory adapter",
    "darwinConfigurations": "system configurations require a dedicated inventory adapter",
    "homeConfigurations": "home configurations require a dedicated inventory adapter",
    "nixosModules": "modules must be applied before their packages can be inspected",
    "darwinModules": "modules must be applied before their packages can be inspected",
    "homeModules": "modules must be applied before their packages can be inspected",
    "overlays": "overlays must be applied before their packages can be inspected",
}


def _nix_string(value):
    return json.dumps(value, ensure_ascii=False).replace("${", r"\${")


def _attribute_path(*parts):
    keywords = {"assert", "else", "if", "in", "inherit", "let", "or", "rec", "then", "with"}
    return ".".join(part if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_'-]*", part)
                    and part not in keywords else _nix_string(part) for part in parts)


@contextmanager
def _inventory_flake(metadata):
    """Expose the consumer's outputs using its exact source and candidate locks.

    An expression using getFlake ignores --reference-lock-file. Graft the graph
    already resolved by Nix under a temporary input instead, retaining the source
    metadata (including self.rev) and rebasing root-relative follows paths.
    """
    graph = deepcopy(metadata["locks"])
    nodes = graph["nodes"]
    root = graph["root"]
    for node in nodes.values():
        if isinstance(node.get("parent"), list):
            node["parent"] = ["subject", *node["parent"]]
        for name, target in node.get("inputs", {}).items():
            if isinstance(target, list):
                node["inputs"][name] = ["subject", *target]
    nodes[root].update(
        locked={key: value for key, value in metadata["locked"].items() if key != "__final"},
        original=metadata["original"],
    )
    wrapper_root = "tvp-inventory-wrapper-root"
    while wrapper_root in nodes:
        wrapper_root += "-root"
    nodes[wrapper_root] = {"inputs": {"subject": root}}
    graph["root"] = wrapper_root
    with tempfile.TemporaryDirectory(prefix="tvp-discovery-") as directory:
        wrapper = Path(directory)
        (wrapper / "flake.nix").write_text(
            "{ inputs.subject.url = " + _nix_string(metadata["originalUrl"]) + "; "
            "outputs = { self, subject }: { consumerOutputs = subject.outputs; }; }\n"
        )
        (wrapper / "flake.lock").write_text(json.dumps(graph))
        yield wrapper


def _error_message(error):
    return (getattr(error, "stderr", None) or str(error)).strip()[-4000:]


def _merge_output_packages(groups):
    merged = {}
    for attribute, packages in groups:
        for original in packages:
            key = tuple(original[name] for name in (
                "role", "namespace", "selector", "kind", "pname", "version", "drvPath", "outputName",
            ))
            if key not in merged:
                merged[key] = {**original, "usedBy": []}
            elif merged[key].get("security") != original.get("security"):
                raise ValueError("Conflicting TVP security identities across output inventories")
            for usage in original["usedBy"]:
                origin = {**usage, "attribute": attribute}
                if origin not in merged[key]["usedBy"]:
                    merged[key]["usedBy"].append(origin)
    return list(merged.values())


def _output_coverage(outputs):
    failed = sum(output["status"] == "failed" for output in outputs)
    return {"evaluated": len(outputs) - failed, "failed": failed, "complete": failed == 0}


def _snapshot_flags(flags):
    # The wrapper has its own exact lock graph. The caller's reference lock has
    # already been consumed by metadata and must not replace the wrapper lock.
    evaluation_flags = list(flags)
    if "--reference-lock-file" in evaluation_flags:
        offset = evaluation_flags.index("--reference-lock-file")
        del evaluation_flags[offset:offset + 2]
    return evaluation_flags


def _discover_inventory(metadata, flags, system, expression):
    outputs, skipped, groups = [], [], []
    evaluation_flags = _snapshot_flags(flags)
    with _inventory_flake(metadata) as wrapper:
        def evaluate(attribute, apply):
            return nix_json(["eval", *evaluation_flags,
                             f"{wrapper}#consumerOutputs" + (f".{attribute}" if attribute else ""),
                             "--apply", apply], capture_errors=True)

        def failed(attribute, error):
            outputs.append({"attribute": attribute, "status": "failed", "error": _error_message(error)})

        try:
            namespaces = evaluate("", "builtins.attrNames")
        except (OSError, ValueError, subprocess.CalledProcessError) as error:
            failed("<outputs>", error)
            return {"outputs": outputs, "skippedOutputs": skipped, "packages": [],
                    "outputCoverage": _output_coverage(outputs)}
        for namespace in namespaces:
            if namespace not in SUPPORTED_OUTPUTS:
                skipped.append({"attribute": namespace, "reason": SKIPPED_OUTPUT_REASONS.get(
                    namespace, "output namespace is not supported by automatic inventory discovery")})
                continue
            try:
                systems = evaluate(namespace, "builtins.attrNames")
            except (OSError, ValueError, subprocess.CalledProcessError) as error:
                failed(namespace, error)
                continue
            for other in systems:
                if other != system:
                    skipped.append({"attribute": _attribute_path(namespace, other),
                                    "reason": f"other platform; selected platform is {system}"})
            if system not in systems:
                continue
            prefix = _attribute_path(namespace, system)
            try:
                names = [None] if namespace == "formatter" else evaluate(prefix, "builtins.attrNames")
            except (OSError, ValueError, subprocess.CalledProcessError) as error:
                failed(prefix, error)
                continue
            for name in names:
                attribute = prefix if name is None else _attribute_path(namespace, system, name)
                try:
                    packages = managed_packages(evaluate(attribute, expression))
                except (OSError, ValueError, subprocess.CalledProcessError) as error:
                    failed(attribute, error)
                    continue
                outputs.append({"attribute": attribute, "status": "evaluated", "packageCount": len(packages)})
                groups.append((attribute, packages))
    return {"outputs": sorted(outputs, key=lambda row: row["attribute"]),
            "skippedOutputs": skipped, "packages": _merge_output_packages(groups),
            "outputCoverage": _output_coverage(outputs)}


def inventory(flake, attribute=None, lock=None, input_name="tvp", *, impure=False, include_security=False,
              system="x86_64-linux"):
    flags = ["--json", "--no-write-lock-file", "--no-update-lock-file",
             "--option", "allow-import-from-derivation", "false"]
    if impure:
        flags.append("--impure")
    if lock is not None:
        flags += ["--reference-lock-file", str(Path(lock).resolve(strict=True))]
    metadata = nix_json(["flake", "metadata", *flags, flake])
    selected = locked_input(metadata["locks"], input_name)
    expression = f"({INVENTORY}) {'true' if include_security else 'false'}"
    if attribute is None:
        return {"schema": 1, "attribute": None, "system": system, "scope": "discovered", "input": selected,
                **_discover_inventory(metadata, flags, system, expression)}
    # Nix's normal installable lookup tries packages/legacyPackages fallbacks
    # even for a full attribute path. The wrapper ensures exact selection never
    # evaluates an unrelated consumer namespace during that lookup.
    with _inventory_flake(metadata) as wrapper:
        packages = managed_packages(nix_json([
            "eval", *_snapshot_flags(flags), f"{wrapper}#consumerOutputs.{attribute}", "--apply", expression,
        ]))
    return {
        "schema": 1,
        "attribute": attribute,
        "scope": "direct",
        "input": selected,
        "packages": packages,
    }


def managed_packages(observed):
    """Collapse repeated package selections while retaining their consumers."""
    packages = {}
    for original in observed:
        package = dict(original)
        usage = {"location": package["location"], "role": package["role"]}
        for name in ("gemName", "providerName"):
            if name in package:
                usage[name] = package.pop(name)
        if package["role"] in (
            "ruby-engine", "ruby-manager", "ruby-native-package", "php-engine", "php-extension",
        ):
            package["role"] = "package"
        identity = tuple(
            package[name] for name in
            ("role", "namespace", "selector", "kind", "pname", "version", "drvPath", "outputName")
        )
        if identity not in packages:
            package["usedBy"] = []
            packages[identity] = package
        if usage not in packages[identity]["usedBy"]:
            packages[identity]["usedBy"].append(usage)
    return list(packages.values())


def package_key(package):
    location = package["location"]
    if package["role"] == "package":
        # Reordering ordinary shell inputs does not change their selections.
        location = ""
        identity = [package["namespace"], package["selector"] or package["pname"]]
    else:
        # Runtime compositions retain their component roles across selector updates.
        identity = [package.get("gemName") or package["pname"]]
    return (location, package["role"], *(value or "" for value in identity), package["outputName"])


def index(inventory):
    packages = defaultdict(list)
    for package in inventory["packages"]:
        packages[package_key(package)].append(package)
    return packages


def without_location(package):
    return {
        name: value for name, value in package.items()
        if name not in ("location", "usedBy", "security")
    }


def unmatched(left, right):
    """Match unchanged duplicate selectors before pairing changed instances."""
    right = list(right)
    old = []
    for package in left:
        for position, candidate in enumerate(right):
            if without_location(package) == without_location(candidate):
                del right[position]
                break
        else:
            old.append(package)
    return old, right


def _failed_output_prefixes(*reports):
    return {row["attribute"] for report in reports for row in report.get("outputs", [])
            if row["status"] == "failed"}


def _blocked_output(attribute, failures):
    return any(prefix == "<outputs>" or attribute == prefix or attribute.startswith(prefix + ".")
               for prefix in failures)


def _reliable_inventory(report, failures):
    if not failures:
        return report
    packages = []
    for package in report["packages"]:
        uses = [usage for usage in package["usedBy"]
                if usage.get("attribute") and not _blocked_output(usage["attribute"], failures)]
        if uses:
            packages.append({**package, "usedBy": uses})
    return {**report, "packages": packages}


def diff(before, after):
    if before["attribute"] != after["attribute"]:
        raise ValueError("Compare the same flake attribute on both sides")
    discovered = before["attribute"] is None
    if discovered and before["system"] != after["system"]:
        raise ValueError("Compare the same platform on both sides")
    failures = _failed_output_prefixes(before, after) if discovered else set()
    old = index(_reliable_inventory(before, failures))
    new = index(_reliable_inventory(after, failures))
    changes = []
    for key in sorted(old.keys() | new.keys()):
        left, right = unmatched(old.get(key, []), new.get(key, []))
        for position in range(max(len(left), len(right))):
            a = left[position] if position < len(left) else None
            b = right[position] if position < len(right) else None
            changes.append({
                "change": "added" if a is None else "removed" if b is None else "changed",
                "before": a,
                "after": b,
                "versionChanged": (a or {}).get("version") != (b or {}).get("version"),
                "derivationChanged": (a or {}).get("drvPath") != (b or {}).get("drvPath"),
            })
    result = {
        "schema": 1,
        "attribute": before["attribute"],
        "beforeInput": before["input"],
        "afterInput": after["input"],
        "changes": changes,
    }
    if discovered:
        before_names = {row["attribute"] for row in before["outputs"] if row["status"] == "evaluated"}
        after_names = {row["attribute"] for row in after["outputs"] if row["status"] == "evaluated"}
        skipped = list(before["skippedOutputs"])
        skipped.extend(row for row in after["skippedOutputs"] if row not in skipped)
        result.update({
            "scope": "discovered", "system": before["system"],
            "beforeOutputs": before["outputs"], "afterOutputs": after["outputs"],
            "beforeSkippedOutputs": before["skippedOutputs"], "afterSkippedOutputs": after["skippedOutputs"],
            "skippedOutputs": skipped,
            "outputCoverage": _output_coverage([*before["outputs"], *after["outputs"]]),
            "outputChanges": [
                {"attribute": name, "change": "added" if name in after_names else "removed"}
                for name in sorted(before_names ^ after_names) if not _blocked_output(name, failures)
            ],
        })
    return result


def format_output_scope(result):
    """Describe the selected scope and retain incomplete discovery evidence."""
    if result["attribute"] is not None:
        return [result["attribute"]]
    lines = [f'All supported outputs for {result["system"]}']
    snapshots = [("Outputs", result.get("outputs", []))]
    if "beforeOutputs" in result:
        snapshots = [("Before outputs", result["beforeOutputs"]), ("After outputs", result["afterOutputs"])]
    for label, outputs in snapshots:
        coverage = _output_coverage(outputs)
        lines.append(f'{label}: {coverage["evaluated"]} evaluated; {coverage["failed"]} failed.')
        for output in outputs:
            attribute = output["attribute"]
            if output["status"] == "failed":
                detail = output["error"].replace("\n", "\n      ")
                lines.append(f"  {attribute}: FAILED — {detail}")
            else:
                lines.append(f'  {attribute}: {output.get("packageCount", 0)} TVP selections')
    for skipped in result.get("skippedOutputs", []):
        lines.append(f'  Skipped {skipped["attribute"]}: {skipped["reason"]}')
    return lines

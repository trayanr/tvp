"""Read and compare a downstream flake's selected TVP packages."""

from collections import defaultdict
import json
from pathlib import Path
import subprocess


INVENTORY = r"""
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
    };
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


def nix_json(arguments):
    result = subprocess.run(["nix", *arguments], check=True, stdout=subprocess.PIPE, text=True)
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


def inventory(flake, attribute, lock=None, input_name="tvp", *, impure=False):
    flags = ["--json", "--no-write-lock-file", "--no-update-lock-file",
             "--option", "allow-import-from-derivation", "false"]
    if impure:
        flags.append("--impure")
    if lock is not None:
        flags += ["--reference-lock-file", str(Path(lock).resolve(strict=True))]
    metadata = nix_json(["flake", "metadata", *flags, flake])
    selected = locked_input(metadata["locks"], input_name)
    packages = managed_packages(nix_json(["eval", *flags, f"{flake}#{attribute}", "--apply", INVENTORY]))
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
    return {name: value for name, value in package.items() if name not in ("location", "usedBy")}


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


def diff(before, after):
    if before["attribute"] != after["attribute"]:
        raise ValueError("Compare the same flake attribute on both sides")
    old = index(before)
    new = index(after)
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
    return {
        "schema": 1,
        "attribute": before["attribute"],
        "beforeInput": before["input"],
        "afterInput": after["input"],
        "changes": changes,
    }

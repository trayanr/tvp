"""Inspect TVP selections in a downstream flake and preview input updates."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from report import diff, inventory


def parser():
    command_parser = argparse.ArgumentParser(prog="tvp", description=__doc__)
    commands = command_parser.add_subparsers(dest="command", required=True)
    used = commands.add_parser("used", help="show the selected TVP packages")
    compare = commands.add_parser("diff", help="compare two existing lockfiles")
    update = commands.add_parser("update", help="preview a TVP input update")

    for command in (used, compare, update):
        command.add_argument("--flake", type=Path, default=Path("."), help="local flake directory")
        command.add_argument("--attr", help="package or shell output (default: devShells.<system>.default)")
        command.add_argument("--input", default="tvp", help="top-level TVP input name")
        command.add_argument("--impure", action="store_true", help="allow outputs to read environment variables and local paths")
        command.add_argument("--json", action="store_true", help="emit a machine-readable report")

    used.add_argument("--lock", type=Path, help="evaluate against an alternate lockfile")
    compare.add_argument("before", type=Path, help="baseline lockfile")
    compare.add_argument("after", nargs="?", type=Path, help="candidate (default: flake.lock)")
    update.add_argument("--preview", required=True, action="store_true", help="leave flake.lock untouched")
    return command_parser


def read_inventory(args, lock):
    return inventory(args.flake, args.attr, lock.resolve(strict=True), args.input, impure=args.impure)


def preview(args, current):
    with tempfile.TemporaryDirectory(prefix="tvp-update-") as directory:
        baseline = Path(directory) / "before.lock"
        candidate = Path(directory) / "after.lock"
        shutil.copyfile(current, baseline)
        before = read_inventory(args, baseline)
        subprocess.run(
            [
                "nix", "flake", "update",
                "--flake", str(args.flake),
                "--reference-lock-file", str(baseline),
                "--output-lock-file", str(candidate),
                *(["--impure"] if args.impure else []),
                "--", args.input,
            ],
            stdout=sys.stderr,
            check=True,
        )
        # Nix can omit writing the candidate if the lockfile has no changes.
        after = read_inventory(args, candidate if candidate.exists() else baseline)
        return diff(before, after)


def package_label(package):
    selector = package["selector"] or package["pname"]
    namespace = package["namespace"]
    if namespace and namespace != "packages":
        selector = f"{namespace}.{selector}"
    return f'{package["location"]}  {selector}'


def input_label(source):
    locked = source["locked"]
    return locked.get("rev") or locked.get("narHash") or "unknown revision"


def format_report(args, result):
    lines = [result["attribute"]]
    if args.command == "used":
        lines.append(f'{args.input}  {input_label(result["input"])}')
        if not result["packages"]:
            lines.append("No TVP selections found in this output.")
        for package in result["packages"]:
            lines.append(f'  {package_label(package)}  {package["version"]}')
        return "\n".join(lines)

    before_rev = input_label(result["beforeInput"])
    after_rev = input_label(result["afterInput"])
    lines.append(f"{args.input}  {before_rev} → {after_rev}")
    if not result["changes"]:
        lines.append("No changes to the observed TVP selections.")
    for entry in result["changes"]:
        before, after = entry["before"], entry["after"]
        if before is None:
            lines.append(f'  + {package_label(after)}  {after["version"]}')
        elif after is None:
            lines.append(f'  - {package_label(before)}  {before["version"]}')
        else:
            detail = ""
            if not entry["versionChanged"]:
                detail = " (derivation changed)" if entry["derivationChanged"] else " (selection changed)"
            lines.append(f'  {package_label(after)}  {before["version"]} → {after["version"]}{detail}')
    return "\n".join(lines)


def main():
    args = parser().parse_args()
    try:
        args.flake = args.flake.resolve(strict=True)
        if not (args.flake / "flake.nix").is_file():
            raise ValueError(f"no flake.nix in {args.flake}")
        if args.attr is None:
            system = os.environ.get("TVP_CONSUMER_SYSTEM", "x86_64-linux")
            args.attr = f"devShells.{system}.default"
        current = args.flake / "flake.lock"
        if args.command == "used":
            result = read_inventory(args, args.lock or current)
        elif args.command == "diff":
            result = diff(
                read_inventory(args, args.before),
                read_inventory(args, args.after or current),
            )
        else:
            result = preview(args, current)
        if args.json:
            print(json.dumps(result, indent=2, sort_keys=True))
        else:
            print(format_report(args, result))
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"tvp: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

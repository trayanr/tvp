"""Narrow workspace scope for the unchanged shrink-only output operation."""
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, sys.argv[3])
from common import invocation, selected  # noqa: E402

workspace, config = invocation()
root = selected(workspace, config.pop("workspaceRoot"))
if not root.is_dir():
    raise ValueError(f"expected staged directory: {root}")
kinds = config.pop("elfKinds")
if kinds is None:
    command = [str(Path(sys.argv[3]) / "rpaths.py"), str(root), json.dumps(config)]
else:
    config["kinds"] = kinds
    command = [sys.argv[4], str(root), json.dumps(config), sys.argv[3], "rpaths"]
subprocess.run([sys.executable, "-B", *command], check=True)

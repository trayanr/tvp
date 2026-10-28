import concurrent.futures
import decimal
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

assert hashlib.sha256(b"tvp").hexdigest() == "f6f6ead0bd85c3127bd5004115a60942d61204561649d9e713bf4f74058de4d1"
assert decimal.Decimal("0.1") + decimal.Decimal("0.2") == decimal.Decimal("0.3")
assert ET.fromstring("<answer>42</answer>").text == "42"
with tempfile.TemporaryDirectory() as directory:
    path = pathlib.Path(directory) / "answer.json"
    path.write_text(json.dumps({"answer": 42}))
    assert json.loads(path.read_text())["answer"] == 42
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    assert sum(pool.map(int, ["20", "22"])) == 42
assert subprocess.check_output([sys.executable, "-c", "print(42)"], text=True).strip() == "42"
assert subprocess.check_output("echo 42", shell=True, text=True).strip() == "42"
print(42)

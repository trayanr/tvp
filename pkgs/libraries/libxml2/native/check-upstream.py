"""Reject a changed raw corpus baseline; compatibility is not conformance."""
from pathlib import Path
import re

text = Path("runsuite.log").read_text()
expected = [616, 759, 775, 784, 793, 874, 6583]
assert [int(n) for n in re.findall(r"Failed to detect incorrect RNG line (\d+)", text)] == expected, text
assert [int(n) for n in re.findall(r"Failed to validate valid instance line (\d+)", text)] == [3799, 3958, 3961], text
assert len(re.findall(r"Failed", text)) == 10, text
print("Raw strict corpus audit: FAIL (seven incorrect RNG schemas accepted); compatibility baseline unchanged. Missing XSTC corpora are not covered.")

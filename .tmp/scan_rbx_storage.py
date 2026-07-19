import collections
import os
import sys
from pathlib import Path


root = Path(sys.argv[1])
signatures = collections.Counter()
roblox_candidates = []
for path in root.rglob("*"):
    if not path.is_file():
        continue
    try:
        with path.open("rb") as handle:
            head = handle.read(64)
    except OSError:
        continue
    signature = head[:16]
    signatures[signature] += 1
    lowered = head.lower()
    if (
        b"roblox" in lowered
        or head.startswith(b"<roblox!")
        or head.startswith(b"<roblox")
        or head.startswith(b"RBXL")
        or head.startswith(b"RBXM")
    ):
        roblox_candidates.append((path, path.stat().st_size, head.hex()))

print("Roblox-like candidates:")
for candidate in sorted(roblox_candidates, key=lambda item: item[1], reverse=True):
    print(*candidate)
print("Most common signatures:")
for signature, count in signatures.most_common(80):
    print(count, signature.hex(), repr(signature))

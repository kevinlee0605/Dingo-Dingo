from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


def digest(text: str) -> str:
    return hashlib.sha256(text.replace("\r\n", "\n").encode("utf-8")).hexdigest()[:12]


def main() -> int:
    payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    source_root = Path(sys.argv[2])
    authored: dict[str, list[Path]] = {}
    for path in source_root.rglob("*.luau"):
        stem = path.name.removesuffix(".client.luau").removesuffix(".server.luau").removesuffix(".luau")
        authored.setdefault(stem.casefold(), []).append(path)

    for item in payload["scripts"]:
        path = item["path"]
        if not (
            path.startswith("StarterGui.")
            or path.startswith("StarterPlayer.StarterPlayerScripts.")
        ):
            continue
        if "AquariumViewer" in path:
            continue
        name = path.rsplit(".", 1)[-1]
        candidates = authored.get(name.casefold(), [])
        reference_hash = digest(item["source"])
        if not candidates:
            print(f"MISSING\t{reference_hash}\t{len(item['source'])}\t{path}")
            continue
        for candidate in candidates:
            current = candidate.read_text(encoding="utf-8")
            state = "MATCH" if current.replace("\r\n", "\n") == item["source"].replace("\r\n", "\n") else "DIFF"
            print(
                f"{state}\t{reference_hash}\t{digest(current)}\t"
                f"{len(item['source'])}\t{len(current)}\t{path}\t{candidate.as_posix()}"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

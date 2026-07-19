from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("dump", type=Path)
    parser.add_argument("prefix")
    parser.add_argument("--direct", action="store_true")
    args = parser.parse_args()
    payload = json.loads(args.dump.read_text(encoding="utf-8"))
    for item in payload["items"]:
        if args.direct:
            relative = item["path"].removeprefix(args.prefix + "/")
            matched = item["path"].startswith(args.prefix + "/") and "/" not in relative
        else:
            matched = item["path"] == args.prefix or item["path"].startswith(args.prefix + "/")
        if matched:
            print(json.dumps(item, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

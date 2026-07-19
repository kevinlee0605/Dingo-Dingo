from __future__ import annotations

import collections
import html
import re
import sys
import json
from pathlib import Path


ITEM_RE = re.compile(r'<Item class="([^"]+)"')
NAME_RE = re.compile(r'<string name="Name">(.*?)</string>')
TEXT_RE = re.compile(r'<string name="Text">(.*?)</string>')


def read_text_items(path: Path):
    if path.suffix.lower() == ".json":
        payload = json.loads(path.read_text(encoding="utf-8"))
        return [
            (item["path"], item["class"], str(item["props"]["Text"]))
            for item in payload["items"]
            if isinstance(item.get("props"), dict) and "Text" in item["props"]
        ]
    stack: list[dict[str, object]] = []
    found: list[tuple[str, str, str]] = []
    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        item_match = ITEM_RE.search(line)
        if item_match:
            stack.append({"class": item_match.group(1), "name": "?", "text": None})
            continue
        if line == "</Item>":
            if not stack:
                continue
            item = stack.pop()
            text = item["text"]
            if text is not None:
                path_names = [str(entry["name"]) for entry in stack] + [str(item["name"])]
                found.append(("/".join(path_names), str(item["class"]), str(text)))
            continue
        if not stack:
            continue
        name_match = NAME_RE.search(line)
        if name_match:
            stack[-1]["name"] = html.unescape(name_match.group(1))
            continue
        text_match = TEXT_RE.search(line)
        if text_match:
            stack[-1]["text"] = html.unescape(text_match.group(1))
    return found


def signature(item: tuple[str, str, str]):
    path, class_name, text = item
    return class_name, path.rsplit("/", 1)[-1], text


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: compare_ui_text.py GOLDEN.rbxlx CURRENT.rbxlx")
    golden = read_text_items(Path(sys.argv[1]))
    current = read_text_items(Path(sys.argv[2]))
    golden_counts = collections.Counter(signature(item) for item in golden)
    current_counts = collections.Counter(signature(item) for item in current)

    print("MISSING OR CHANGED FROM GOLDEN")
    for key, count in sorted((golden_counts - current_counts).items()):
        print(count, *key, sep="\t")
    print("CURRENT ADDITIONS OR CHANGES")
    for key, count in sorted((current_counts - golden_counts).items()):
        print(count, *key, sep="\t")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

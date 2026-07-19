from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


VISUAL_PROPERTIES = (
    "Text",
    "Font",
    "TextSize",
    "TextScaled",
    "TextColor3",
    "TextStrokeColor3",
    "TextStrokeTransparency",
    "TextXAlignment",
    "TextYAlignment",
    "Position",
    "Size",
    "AnchorPoint",
    "Rotation",
    "Visible",
    "Image",
    "ImageRectOffset",
    "ImageRectSize",
    "ImageColor3",
    "ScaleType",
    "SliceCenter",
    "BackgroundColor3",
    "BackgroundTransparency",
    "ClipsDescendants",
    "ScrollBarThickness",
    "CanvasSize",
)


def load_items(path: Path) -> dict[str, dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    return {item["path"]: item for item in payload["items"]}


def compact(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("golden", type=Path)
    parser.add_argument("current", type=Path)
    parser.add_argument("--prefix", default="PlayerGui/")
    parser.add_argument("--show-missing", action="store_true")
    args = parser.parse_args()

    golden = load_items(args.golden)
    current = load_items(args.current)
    prefixes = tuple(part.strip() for part in args.prefix.split(",") if part.strip())

    screen_roots = sorted(
        item["path"]
        for item in golden.values()
        if item["class"] == "ScreenGui" and item["path"].startswith(prefixes)
    )
    print("GOLDEN SCREEN GUIS")
    for path in screen_roots:
        item = golden[path]
        print(f"{path}\tDisplayOrder={item['props'].get('DisplayOrder')}")

    if args.show_missing:
        print("\nMISSING MATCHED PATHS")
        for path in sorted(golden.keys() - current.keys()):
            if path.startswith(prefixes):
                print(path)

    print("\nMATCHED VISUAL DIFFERENCES")
    difference_count = 0
    for path in sorted(golden.keys() & current.keys()):
        if not path.startswith(prefixes):
            continue
        expected = golden[path]
        actual = current[path]
        expected_props = expected["props"] if isinstance(expected.get("props"), dict) else {}
        actual_props = actual["props"] if isinstance(actual.get("props"), dict) else {}
        differences = []
        if expected["class"] != actual["class"]:
            differences.append(("ClassName", expected["class"], actual["class"]))
        for prop in VISUAL_PROPERTIES:
            expected_value = expected_props.get(prop)
            actual_value = actual_props.get(prop)
            if expected_value != actual_value:
                differences.append((prop, expected_value, actual_value))
        if differences:
            difference_count += len(differences)
            print(path)
            for prop, expected_value, actual_value in differences:
                print(f"  {prop}: {compact(expected_value)} -> {compact(actual_value)}")
    print(f"\n{difference_count} differing matched properties")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

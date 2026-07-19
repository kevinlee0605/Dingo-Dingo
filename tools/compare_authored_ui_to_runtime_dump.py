from __future__ import annotations

import json
import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


PROPERTIES = (
    "Text", "Font", "TextSize", "TextScaled", "TextColor3",
    "TextStrokeColor3", "TextStrokeTransparency", "TextXAlignment",
    "TextYAlignment", "TextTransparency", "TextWrapped", "RichText",
    "LineHeight", "TextTruncate", "Position", "Size", "AnchorPoint", "Rotation",
    "Visible", "Image", "ImageRectOffset", "ImageRectSize", "ImageColor3",
    "ImageTransparency", "ScaleType", "SliceCenter", "BackgroundColor3",
    "BackgroundTransparency", "ClipsDescendants", "ScrollBarThickness",
    "ScrollBarImageTransparency", "ScrollBarImageColor3", "CanvasSize",
    "AutomaticCanvasSize", "ScrollingDirection", "ScrollingEnabled",
    "ElasticBehavior", "VerticalScrollBarInset", "HorizontalScrollBarInset",
    "Scale", "Padding", "FillDirection", "HorizontalAlignment",
    "VerticalAlignment", "SortOrder", "MinTextSize", "MaxTextSize",
    "Thickness", "Transparency", "Color", "Enabled", "ApplyStrokeMode",
    "LineJoinMode", "CornerRadius", "AspectRatio", "AspectType",
    "DominantAxis", "MinSize", "MaxSize", "CellPadding", "CellSize",
    "FillDirectionMaxCells", "StartCorner", "PaddingLeft", "PaddingRight",
    "PaddingTop", "PaddingBottom",
)


ENUM_TOKENS = {
    "ScaleType": {0: "Stretch", 1: "Slice", 2: "Tile", 3: "Fit", 4: "Crop"},
    "TextXAlignment": {0: "Left", 1: "Right", 2: "Center"},
    "TextYAlignment": {0: "Top", 1: "Center", 2: "Bottom"},
    "FillDirection": {0: "Horizontal", 1: "Vertical"},
    "HorizontalAlignment": {0: "Left", 1: "Center", 2: "Right"},
    "VerticalAlignment": {0: "Top", 1: "Center", 2: "Bottom"},
    "SortOrder": {0: "Name", 1: "Custom", 2: "LayoutOrder"},
    "AutomaticCanvasSize": {0: "None", 1: "X", 2: "Y", 3: "XY"},
    "ScrollingDirection": {1: "X", 2: "Y", 4: "XY"},
    "ApplyStrokeMode": {0: "Contextual", 1: "Border"},
    "LineJoinMode": {0: "Round", 1: "Bevel", 2: "Miter"},
    "TextTruncate": {0: "None", 1: "AtEnd", 2: "SplitWord"},
    "StartCorner": {0: "TopLeft", 1: "TopRight", 2: "BottomLeft", 3: "BottomRight"},
    "Font": {0: "Legacy", 18: "GothamBold", 20: "GothamBlack", 26: "FredokaOne"},
}


def name_of(item: ET.Element) -> str:
    value = item.find("./Properties/string[@name='Name']")
    return value.text if value is not None and value.text else item.attrib.get("class", "Item")


def scalar(value: ET.Element):
    if value.tag == "bool":
        return (value.text or "false").lower() == "true"
    if value.tag in {"int", "int64", "token"}:
        return int(value.text or "0")
    if value.tag in {"float", "double"}:
        return round(float(value.text or "0"), 6)
    if value.tag == "Content":
        return value.findtext("url", "")
    if value.tag == "UDim":
        return tuple(round(float(value.findtext(key, "0")), 6) for key in ("S", "O"))
    if value.tag == "UDim2":
        return tuple(round(float(value.findtext(key, "0")), 6) for key in ("XS", "XO", "YS", "YO"))
    if value.tag == "Vector2":
        return tuple(round(float(value.findtext(key, "0")), 6) for key in ("X", "Y"))
    if value.tag == "Color3":
        return tuple(round(float(value.findtext(key, "0")), 6) for key in ("R", "G", "B"))
    if value.tag == "Rect2D":
        return tuple(
            round(float(value.findtext(f"{side}/{axis}", "0")), 6)
            for side in ("min", "max") for axis in ("X", "Y")
        )
    return value.text or ""


def authored_items(place_path: Path) -> dict[str, dict]:
    root = ET.parse(place_path).getroot()
    result: dict[str, dict] = {}

    def visit(item: ET.Element, parent: str) -> None:
        name = name_of(item)
        path = f"{parent}/{name}" if parent else name
        if path.startswith("StarterGui/"):
            props = {}
            properties = item.find("Properties")
            if properties is not None:
                for value in properties:
                    prop_name = value.attrib.get("name")
                    if prop_name in PROPERTIES:
                        props[prop_name] = scalar(value)
            result[path.removeprefix("StarterGui/")] = {
                "class": item.attrib.get("class"),
                "props": props,
            }
        for child in item.findall("Item"):
            visit(child, path)

    for item in root.findall("Item"):
        visit(item, "")
    return result


def golden_items(path: Path) -> dict[str, dict]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    result = {}
    for item in payload["items"]:
        player_path = item["path"]
        if player_path.startswith("PlayerGui/"):
            result[player_path.removeprefix("PlayerGui/")] = item
    return result


def normalize_golden(value):
    if isinstance(value, dict):
        kind = value.get("type")
        if kind == "UDim2":
            return tuple(round(float(value[key]), 6) for key in ("xs", "xo", "ys", "yo"))
        if kind == "Vector2":
            return tuple(round(float(value[key]), 6) for key in ("x", "y"))
        if kind == "Color3":
            return tuple(round(float(value[key]), 6) for key in ("r", "g", "b"))
        if kind == "Rect":
            return tuple(round(float(value[side][axis]), 6) for side in ("min", "max") for axis in ("x", "y"))
        if kind == "UDim":
            return tuple(round(float(value[key]), 6) for key in ("s", "o"))
    if isinstance(value, float):
        return round(value, 6)
    if isinstance(value, str) and value.startswith("Enum."):
        return value.rsplit(".", 1)[-1]
    return value


def authored_path_for(golden_path: str, authored: dict[str, dict]) -> str | None:
    candidates = [golden_path]

    if golden_path.startswith("FishyFishPhase3Gui_SeaStarHudFixed/"):
        suffix = golden_path.removeprefix("FishyFishPhase3Gui_SeaStarHudFixed/")
        candidates.insert(0, f"Phase3EconomyGui/DailyRewardSurface/{suffix}")
    elif golden_path == "FishyFishPhase3Gui_SeaStarHudFixed":
        candidates.insert(0, "Phase3EconomyGui")

    # The migrated Decor Editor keeps the v1636 surface beneath an authored
    # Interface container.  Treat that container as transparent for parity
    # comparisons so the report describes real visual differences instead of
    # listing the entire reference hierarchy as missing.
    if golden_path.startswith("AquariumFreePlacementGui/"):
        candidates.insert(
            0,
            golden_path.replace(
                "AquariumFreePlacementGui/",
                "AquariumFreePlacementGui/Interface/",
                1,
            ),
        )

    if golden_path.startswith("FishingGui/Root/"):
        direct = golden_path.replace("FishingGui/Root/", "FishingGui/", 1)
        candidates.append(direct)

        for surface, canvas in (
            ("ModernQuestUI", "QuestCanvas"),
            ("ModernBagRoot", "Canvas"),
            ("ModernFishdex", "ModernFishdex"),
        ):
            prefix = f"FishingGui/Root/{surface}"
            if golden_path == prefix or golden_path.startswith(prefix + "/"):
                suffix = golden_path.removeprefix(prefix)
                candidates.insert(0, f"FishingGui/{surface}/{canvas}{suffix}")

    if golden_path.startswith("FishingGui/TopButtonsFrame"):
        candidates.insert(0, golden_path.replace("FishingGui/", "TopHudGui/", 1))

    if golden_path.startswith("ForcedTopHudGui/ForcedTopButtonsFrame"):
        forced_candidate = golden_path.replace(
            "ForcedTopHudGui/ForcedTopButtonsFrame",
            "TopHudGui/TopButtonsFrame",
            1,
        )
        forced_candidate = forced_candidate.replace(
            "/DailyRewardButton", "/TopLoginRewardButton"
        )
        forced_candidate = forced_candidate.replace(
            "/ForcedLayout", "/UIListLayout"
        )
        forced_candidate = forced_candidate.replace(
            "/FishyFishDeviceScale", "/TopHudScale"
        )
        candidates.insert(0, forced_candidate)

    scale_aliases = {
        "/FishyFishDeviceScale": "/LeftStatsScale",
        "/BottomButtonsFrame/UIScale": "/BottomButtonsFrame/BottomHudScale",
    }
    for candidate in tuple(candidates):
        for old, new in scale_aliases.items():
            if old in candidate:
                candidates.insert(0, candidate.replace(old, new))

    for candidate in candidates:
        if candidate in authored:
            return candidate
    return None


def normalize_authored(value, prop_name: str):
    if isinstance(value, int) and prop_name in ENUM_TOKENS:
        return ENUM_TOKENS[prop_name].get(value, value)
    return value


def values_equal(left, right) -> bool:
    if isinstance(left, float) and isinstance(right, float):
        return abs(left - right) <= 1e-5
    if isinstance(left, tuple) and isinstance(right, tuple) and len(left) == len(right):
        return all(values_equal(a, b) for a, b in zip(left, right))
    return left == right


def visually_inert_difference(expected: dict, actual: dict, prop: str) -> bool:
    if prop == "BackgroundColor3":
        return (
            expected.get("props", {}).get("BackgroundTransparency") == 1
            and actual.get("props", {}).get("BackgroundTransparency") == 1
        )
    return False


def surface_for(path: str) -> str:
    parts = path.split("/")
    if not parts:
        return path
    if parts[0] == "FishingGui" and len(parts) > 1:
        if parts[1] == "Root" and len(parts) > 2:
            return "/".join(parts[:3])
        return "/".join(parts[:2])
    if parts[0] == "AquariumFreePlacementGui":
        return parts[0]
    return "/".join(parts[:2]) if len(parts) > 1 else parts[0]


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("golden", type=Path)
    parser.add_argument("authored", type=Path)
    parser.add_argument("roots", nargs="?", default="FishingGui")
    parser.add_argument("--summary", action="store_true")
    parser.add_argument("--include-inert", action="store_true")
    args = parser.parse_args()
    golden = golden_items(args.golden)
    authored = authored_items(args.authored)
    roots = tuple(args.roots.split(","))
    differences = []
    missing = []
    for path, expected in golden.items():
        if not path.startswith(roots):
            continue
        authored_path = authored_path_for(path, authored)
        if authored_path is None:
            missing.append(path)
            continue
        actual = authored[authored_path]
        if expected["class"] != actual["class"]:
            differences.append((path, "ClassName", expected["class"], actual["class"]))
        for prop in PROPERTIES:
            if prop not in expected.get("props", {}) or prop not in actual["props"]:
                continue
            left = normalize_golden(expected["props"][prop])
            right = normalize_authored(actual["props"][prop], prop)
            if not values_equal(left, right) and (
                args.include_inert or not visually_inert_difference(expected, actual, prop)
            ):
                differences.append((path, prop, left, right))
    print(f"matched visual differences: {len(differences)}")
    if args.summary:
        counts = {}
        for path, _prop, _expected, _actual in differences:
            surface = surface_for(path)
            counts[surface] = counts.get(surface, 0) + 1
        for surface in sorted(counts):
            print(f"{surface}\t{counts[surface]}")
    else:
        for path, prop, expected, actual in differences:
            print(f"{path}\t{prop}\t{expected!r}\t{actual!r}")
    print(f"missing golden paths: {len(missing)}")
    if args.summary:
        counts = {}
        for path in missing:
            surface = surface_for(path)
            counts[surface] = counts.get(surface, 0) + 1
        for surface in sorted(counts):
            print(f"MISSING\t{surface}\t{counts[surface]}")
    else:
        for path in missing:
            print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

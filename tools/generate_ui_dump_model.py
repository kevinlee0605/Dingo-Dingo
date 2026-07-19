from __future__ import annotations

import json
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


SAFE_PROPERTIES = {
    "Active", "Interactable", "AnchorPoint", "SizeConstraint", "ZIndex",
    "AutomaticSize", "Size", "SelectionOrder", "ClipsDescendants",
    "BorderColor3", "Style", "Visible", "Rotation", "Transparency",
    "BackgroundTransparency", "Position", "BorderMode", "Selectable",
    "BorderSizePixel", "BackgroundColor3", "LayoutOrder", "Image",
    "ImageColor3", "ImageRectOffset", "ImageRectSize", "ImageTransparency",
    "ResampleMode", "ScaleType", "SliceCenter", "SliceScale", "TileSize",
    "AutoButtonColor", "Modal", "Text", "TextColor3", "TextScaled",
    "TextSize", "TextStrokeColor3", "TextStrokeTransparency",
    "TextTransparency", "TextTruncate", "TextWrapped", "TextXAlignment",
    "TextYAlignment", "RichText", "LineHeight", "Font", "Scale",
    "FillDirection", "FillDirectionMaxCells", "CellSize", "CellPadding",
    "HorizontalAlignment", "VerticalAlignment", "SortOrder", "StartCorner",
    "CornerRadius", "ApplyStrokeMode", "Color", "Enabled", "LineJoinMode",
    "Thickness", "MaxTextSize", "MinTextSize", "AspectRatio", "AspectType",
    "DominantAxis", "MinSize", "MaxSize", "Padding", "PaddingLeft",
    "PaddingRight", "PaddingTop", "PaddingBottom", "CanvasSize",
    "AutomaticCanvasSize", "ScrollBarImageColor3", "ScrollBarImageTransparency",
    "ScrollBarThickness", "ScrollingDirection", "ScrollingEnabled",
    "ElasticBehavior", "VerticalScrollBarInset", "HorizontalScrollBarInset",
}


ENUM_TOKENS = {
    "AutomaticSize": {"None": 0, "X": 1, "Y": 2, "XY": 3},
    "SizeConstraint": {"RelativeXY": 0, "RelativeXX": 1, "RelativeYY": 2},
    "BorderMode": {"Outline": 0, "Middle": 1, "Inset": 2},
    "Style": {"Custom": 0, "ChatBlue": 1, "RobloxSquare": 2, "RobloxRound": 3,
              "DropShadow": 4, "DropShadow2": 5},
    "ScaleType": {"Stretch": 0, "Slice": 1, "Tile": 2, "Fit": 3, "Crop": 4},
    "ResampleMode": {"Default": 0, "Pixelated": 1},
    "TextTruncate": {"None": 0, "AtEnd": 1, "SplitWord": 2},
    "TextXAlignment": {"Left": 0, "Right": 1, "Center": 2},
    "TextYAlignment": {"Top": 0, "Center": 1, "Bottom": 2},
    "TextDirection": {"Auto": 0, "LeftToRight": 1, "RightToLeft": 2},
    "Font": {"Legacy": 0, "Arial": 1, "ArialBold": 2, "SourceSans": 3,
             "SourceSansBold": 4, "SourceSansLight": 5, "SourceSansItalic": 6,
             "Bodoni": 7, "Garamond": 8, "Cartoon": 9, "Code": 10,
             "Highway": 11, "SciFi": 12, "Arcade": 13, "Fantasy": 14,
             "Antique": 15, "SourceSansSemibold": 16, "Gotham": 17,
             "GothamBold": 18, "GothamBlack": 20, "AmaticSC": 21,
             "Bangers": 22, "Creepster": 23, "DenkOne": 24,
             "Fondamento": 25, "FredokaOne": 26, "GrenzeGotisch": 27,
             "IndieFlower": 28, "JosefinSans": 29, "Jura": 30,
             "Kalam": 31, "LuckiestGuy": 32, "Merriweather": 33,
             "Michroma": 34, "Nunito": 35, "Oswald": 36, "PatrickHand": 37,
             "PermanentMarker": 38, "Roboto": 39, "RobotoCondensed": 40,
             "RobotoMono": 41, "Sarpanch": 42, "SpecialElite": 43,
             "TitilliumWeb": 44, "Ubuntu": 45},
    "FillDirection": {"Horizontal": 0, "Vertical": 1},
    "HorizontalAlignment": {"Left": 0, "Center": 1, "Right": 2},
    "VerticalAlignment": {"Top": 0, "Center": 1, "Bottom": 2},
    "SortOrder": {"Name": 0, "Custom": 1, "LayoutOrder": 2},
    "StartCorner": {"TopLeft": 0, "TopRight": 1, "BottomLeft": 2, "BottomRight": 3},
    "ApplyStrokeMode": {"Contextual": 0, "Border": 1},
    "LineJoinMode": {"Round": 0, "Bevel": 1, "Miter": 2},
    "AspectType": {"FitWithinMaxSize": 0, "ScaleWithParentSize": 1},
    "DominantAxis": {"Width": 0, "Height": 1},
    "AutomaticCanvasSize": {"None": 0, "X": 1, "Y": 2, "XY": 3},
    "ScrollingDirection": {"X": 1, "Y": 2, "XY": 4},
    "ElasticBehavior": {"WhenScrollable": 0, "Always": 1, "Never": 2},
    "VerticalScrollBarInset": {"None": 0, "ScrollBar": 1, "Always": 2},
    "HorizontalScrollBarInset": {"None": 0, "ScrollBar": 1, "Always": 2},
}


@dataclass
class Node:
    class_name: str
    name: str
    order: int
    props: dict[str, Any] = field(default_factory=dict)
    children: list["Node"] = field(default_factory=list)


def enum_token(prop_name: str, value: str) -> int:
    enum_name = value.rsplit(".", 1)[-1]
    table = ENUM_TOKENS.get(prop_name, {})
    if enum_name not in table:
        raise ValueError(f"Missing enum token for {prop_name}={value}")
    return table[enum_name]


def add_value(properties: ET.Element, name: str, value: Any) -> None:
    if isinstance(value, bool):
        ET.SubElement(properties, "bool", {"name": name}).text = str(value).lower()
        return
    if isinstance(value, int):
        ET.SubElement(properties, "int", {"name": name}).text = str(value)
        return
    if isinstance(value, float):
        ET.SubElement(properties, "float", {"name": name}).text = repr(value)
        return
    if isinstance(value, str):
        if value.startswith("Enum."):
            ET.SubElement(properties, "token", {"name": name}).text = str(enum_token(name, value))
        elif name == "Image":
            content = ET.SubElement(properties, "Content", {"name": name})
            ET.SubElement(content, "url").text = value
        else:
            ET.SubElement(properties, "string", {"name": name}).text = value
        return
    if not isinstance(value, dict):
        raise ValueError(f"Unsupported {name} value: {value!r}")

    kind = value.get("type")
    if kind == "Vector2":
        element = ET.SubElement(properties, "Vector2", {"name": name})
        ET.SubElement(element, "X").text = repr(value["x"])
        ET.SubElement(element, "Y").text = repr(value["y"])
    elif kind == "Color3":
        element = ET.SubElement(properties, "Color3", {"name": name})
        ET.SubElement(element, "R").text = repr(value["r"])
        ET.SubElement(element, "G").text = repr(value["g"])
        ET.SubElement(element, "B").text = repr(value["b"])
    elif kind == "UDim":
        element = ET.SubElement(properties, "UDim", {"name": name})
        ET.SubElement(element, "S").text = repr(value["s"])
        ET.SubElement(element, "O").text = str(round(value["o"]))
    elif kind == "UDim2":
        element = ET.SubElement(properties, "UDim2", {"name": name})
        for key, output_name in (("xs", "XS"), ("xo", "XO"), ("ys", "YS"), ("yo", "YO")):
            text = repr(value[key]) if key.endswith("s") else str(round(value[key]))
            ET.SubElement(element, output_name).text = text
    elif kind == "Rect":
        element = ET.SubElement(properties, "Rect2D", {"name": name})
        for side in ("min", "max"):
            side_element = ET.SubElement(element, side)
            ET.SubElement(side_element, "X").text = repr(value[side]["x"])
            ET.SubElement(side_element, "Y").text = repr(value[side]["y"])
    else:
        raise ValueError(f"Unsupported {name} structure: {value!r}")


def add_node(parent: ET.Element, node: Node, referent: list[int]) -> None:
    referent[0] += 1
    item = ET.SubElement(parent, "Item", {"class": node.class_name, "referent": f"RBX{referent[0]:08X}"})
    properties = ET.SubElement(item, "Properties")
    ET.SubElement(properties, "string", {"name": "Name"}).text = node.name
    for name in sorted(node.props):
        if name in SAFE_PROPERTIES:
            add_value(properties, name, node.props[name])
    for child in sorted(node.children, key=lambda item: (item.order, item.name)):
        add_node(item, child, referent)


def main() -> int:
    if len(sys.argv) != 5:
        print("Usage: generate_ui_dump_model.py DUMP.json PREFIX WRAPPER_NAME OUTPUT.rbxmx")
        return 2

    payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    prefix = sys.argv[2].rstrip("/")
    wrapper = Node(
        "Frame",
        sys.argv[3],
        0,
        {
            "AnchorPoint": {"type": "Vector2", "x": 0, "y": 0},
            "Position": {"type": "UDim2", "xs": 0, "xo": 0, "ys": 0, "yo": 0},
            "Size": {"type": "UDim2", "xs": 1, "xo": 0, "ys": 1, "yo": 0},
            "BackgroundTransparency": 1,
            "BorderSizePixel": 0,
            "Visible": True,
            "ZIndex": 1,
        },
    )

    by_path: dict[str, Node] = {prefix: wrapper}
    for raw in sorted(payload["items"], key=lambda item: (item["path"].count("/"), item.get("order", 0))):
        path = raw["path"]
        if not path.startswith(prefix + "/"):
            continue
        relative = path.removeprefix(prefix + "/")
        if "/" not in relative:
            parent_path = prefix
        else:
            parent_path = path.rsplit("/", 1)[0]
        parent = by_path.get(parent_path)
        if parent is None:
            raise KeyError(f"Missing parent {parent_path} for {path}")
        node = Node(raw["class"], raw["name"], raw.get("order", 0), raw.get("props", {}))
        parent.children.append(node)
        by_path[path] = node

    document = ET.Element(
        "roblox",
        {
            "xmlns:xmime": "http://www.w3.org/2005/05/xmlmime",
            "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
            "xsi:noNamespaceSchemaLocation": "http://www.roblox.com/roblox.xsd",
            "version": "4",
        },
    )
    ET.SubElement(document, "Meta", {"name": "ExplicitAutoJoints"}).text = "true"
    ET.SubElement(document, "External").text = "null"
    ET.SubElement(document, "External").text = "nil"
    add_node(document, wrapper, [0])
    ET.indent(document, space="\t")
    Path(sys.argv[4]).write_text(ET.tostring(document, encoding="unicode") + "\n", encoding="utf-8")
    print(f"Wrote {len(by_path) - 1} v1636 instances to {sys.argv[4]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Generate the hidden legacy fishing/cast compatibility hierarchy.

The live FishingClient still keeps references to the former minigame and cast
widgets while the exact authored modern surfaces own presentation.  Persisting
this tree in StarterGui avoids rebuilding fixed compatibility UI on every join.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "src/ui/FishingGui/FishingMinigame.rbxmx"


@dataclass
class Node:
    class_name: str
    name: str
    props: dict[str, tuple[str, Any]] = field(default_factory=dict)
    children: list["Node"] = field(default_factory=list)


def scalar(kind: str, value: Any) -> tuple[str, Any]:
    return kind, value


def udim(scale: float, offset: float) -> tuple[str, Any]:
    return "UDim", (scale, offset)


def udim2(xs: float, xo: float, ys: float, yo: float) -> tuple[str, Any]:
    return "UDim2", (xs, xo, ys, yo)


def vec2(x: float, y: float) -> tuple[str, Any]:
    return "Vector2", (x, y)


def color(r: int, g: int, b: int) -> tuple[str, Any]:
    return "Color3", (r / 255, g / 255, b / 255)


def gui(
    *,
    position: tuple[str, Any] = udim2(0, 0, 0, 0),
    size: tuple[str, Any] = udim2(1, 0, 1, 0),
    anchor: tuple[str, Any] = vec2(0, 0),
    background: tuple[str, Any] = color(255, 255, 255),
    transparency: float = 1,
    visible: bool = True,
    zindex: int = 1,
) -> dict[str, tuple[str, Any]]:
    return {
        "AnchorPoint": anchor,
        "BackgroundColor3": background,
        "BackgroundTransparency": scalar("float", transparency),
        "BorderSizePixel": scalar("int", 0),
        "ClipsDescendants": scalar("bool", False),
        "Position": position,
        "Size": size,
        "Visible": scalar("bool", visible),
        "ZIndex": scalar("int", zindex),
    }


def frame(name: str, **kwargs: Any) -> Node:
    return Node("Frame", name, gui(**kwargs))


def label(
    name: str,
    text: str,
    position: tuple[str, Any],
    size: tuple[str, Any],
    text_size: float,
    text_color: tuple[str, Any],
    zindex: int,
    *,
    font: int,
    xalign: int = 0,
    scaled: bool = False,
    wrapped: bool = False,
    outlined: bool = False,
) -> Node:
    props = gui(position=position, size=size, zindex=zindex)
    props.update(
        {
            "Font": scalar("token", font),
            "RichText": scalar("bool", False),
            "Text": scalar("string", text),
            "TextColor3": text_color,
            "TextScaled": scalar("bool", scaled),
            "TextSize": scalar("float", text_size),
            "TextStrokeColor3": color(255, 255, 255) if outlined else color(0, 0, 0),
            "TextStrokeTransparency": scalar("float", 1),
            "TextTransparency": scalar("float", 0),
            "TextWrapped": scalar("bool", wrapped),
            "TextXAlignment": scalar("token", xalign),
            "TextYAlignment": scalar("token", 1),
        }
    )
    return Node("TextLabel", name, props)


def corner(name: str, radius: float) -> Node:
    return Node("UICorner", name, {"CornerRadius": udim(0, radius)})


def stroke(name: str, rgb: tuple[int, int, int], thickness: float, transparency: float = 0) -> Node:
    return Node(
        "UIStroke",
        name,
        {
            "Color": color(*rgb),
            "Thickness": scalar("float", thickness),
            "Transparency": scalar("float", transparency),
        },
    )


def gradient(name: str, top: tuple[int, int, int], bottom: tuple[int, int, int], rotation: float = 90) -> Node:
    return Node(
        "UIGradient",
        name,
        {
            "Color": scalar("ColorSequence", ((0, *top), (1, *bottom))),
            "Rotation": scalar("float", rotation),
        },
    )


def text_constraint(minimum: int, maximum: int, name: str = "UITextSizeConstraint") -> Node:
    return Node(
        "UITextSizeConstraint",
        name,
        {
            "MinTextSize": scalar("int", minimum),
            "MaxTextSize": scalar("int", maximum),
        },
    )


def gloss(name: str, position: tuple[str, Any], size: tuple[str, Any], zindex: int) -> Node:
    node = frame(
        name,
        position=position,
        size=size,
        background=color(255, 255, 255),
        transparency=0.72,
        zindex=zindex,
    )
    node.children = [
        corner("GlossCorner", 24),
        Node(
            "UIGradient",
            "GlossGradient",
            {
                "Transparency": scalar("NumberSequence", ((0, 0.05), (0.45, 0.6), (1, 1))),
                "Rotation": scalar("float", 18),
            },
        ),
    ]
    return node


def make_model() -> Node:
    root = frame(
        "FishingMinigame",
        position=udim2(0.5, 0, 0.48, 0),
        size=udim2(0, 540, 0, 520),
        anchor=vec2(0.5, 0.5),
        background=color(10, 68, 155),
        transparency=0,
        visible=False,
        zindex=40,
    )
    root.children.extend(
        [
            corner("PanelCorner", 30),
            stroke("OuterStroke", (0, 78, 190), 7),
            stroke("HighlightStroke", (99, 210, 255), 2, 0.08),
            gradient("PanelGradient", (18, 92, 198), (7, 52, 132)),
            Node(
                "UISizeConstraint",
                "MinigameSizeConstraint",
                {"MinSize": vec2(500, 450), "MaxSize": vec2(620, 560)},
            ),
        ]
    )

    inner = frame(
        "InnerStroke",
        position=udim2(0, 14, 0, 14),
        size=udim2(1, -28, 1, -28),
        transparency=1,
        zindex=41,
    )
    inner.children = [corner("InnerCorner", 26), stroke("InnerOutline", (91, 193, 255), 2, 0.38)]
    root.children.extend([inner, gloss("PanelGloss", udim2(0, 22, 0, 18), udim2(0, 90, 0, 12), 41)])

    header = label(
        "MinigameText",
        "Wait for a bite...",
        udim2(0, 40, 0, 24),
        udim2(1, -80, 0, 44),
        36,
        color(255, 255, 255),
        44,
        font=26,
        scaled=True,
        outlined=True,
    )
    header.children = [text_constraint(16, 24)]
    root.children.append(header)

    timing_bar = frame(
        "Bar",
        position=udim2(0, 40, 0, 86),
        size=udim2(1, -80, 0, 44),
        background=color(57, 99, 150),
        transparency=0,
        visible=False,
        zindex=43,
    )
    timing_bar.children.extend(
        [
            corner("BarCorner", 24),
            stroke("BarOuterStroke", (7, 52, 121), 5),
            stroke("BarHighlightStroke", (147, 178, 212), 2, 0.22),
            gradient("BarGradient", (92, 132, 181), (48, 88, 143)),
        ]
    )
    zone = frame(
        "Zone",
        position=udim2(0.39, 0, 0, 0),
        size=udim2(0.22, 0, 1, 0),
        background=color(30, 231, 53),
        transparency=0,
        visible=False,
        zindex=44,
    )
    zone.children = [
        corner("ZoneCorner", 16),
        stroke("ZoneStroke", (3, 96, 19), 4),
        gradient("ZoneGradient", (104, 255, 81), (16, 194, 38)),
        gloss("ZoneGloss", udim2(0, 14, 0, 8), udim2(0, 66, 0, 9), 45),
    ]
    marker = frame(
        "Marker",
        position=udim2(0, 0, 0, -14),
        size=udim2(0, 16, 1, 28),
        background=color(255, 255, 255),
        transparency=0,
        visible=False,
        zindex=45,
    )
    marker.children = [corner("MarkerCorner", 9), stroke("MarkerStroke", (7, 55, 128), 3)]
    timing_bar.children.extend([zone, marker])
    root.children.append(timing_bar)

    catch_props = gui(
        position=udim2(0.5, 0, 1, -18),
        size=udim2(0.29, 0, 0, 52),
        anchor=vec2(0.5, 1),
        background=color(28, 160, 92),
        transparency=0,
        visible=False,
        zindex=44,
    )
    catch_props.update(
        {
            "Active": scalar("bool", False),
            "AutoButtonColor": scalar("bool", False),
            "Font": scalar("token", 26),
            "Text": scalar("string", ""),
            "TextColor3": color(255, 255, 255),
            "TextScaled": scalar("bool", True),
            "TextSize": scalar("float", 34),
            "TextStrokeColor3": color(255, 255, 255),
            "TextStrokeTransparency": scalar("float", 1),
            "TextTransparency": scalar("float", 0),
        }
    )
    catch_button = Node("TextButton", "CatchButton", catch_props)
    catch_button.children = [
        corner("ButtonCorner", 24),
        stroke("ButtonBaseStroke", (255, 255, 255), 1, 0.85),
        text_constraint(15, 24),
        stroke("CatchOutline", (0, 92, 18), 7),
        gradient("ButtonGradient", (104, 255, 91), (17, 196, 38)),
        gloss("ButtonGloss", udim2(0, 22, 0, 13), udim2(0, 90, 0, 12), 45),
    ]
    root.children.append(catch_button)

    game_content = frame(
        "FishingGameContent",
        position=udim2(0, 34, 0, 82),
        size=udim2(1, -68, 1, -106),
        transparency=1,
        zindex=44,
    )
    vertical_panel = frame(
        "VerticalFishingPanel",
        position=udim2(0, 18, 0, 0),
        size=udim2(0, 180, 1, -58),
        background=color(31, 95, 156),
        transparency=0,
        zindex=45,
    )
    vertical_panel.children.extend(
        [
            corner("PanelCorner", 20),
            stroke("PanelOuterStroke", (7, 48, 106), 5),
            stroke("PanelHighlightStroke", (126, 219, 255), 2, 0.18),
            gradient("PanelGradient", (55, 154, 210), (18, 71, 140)),
        ]
    )
    water = frame(
        "Water",
        position=udim2(0, 14, 0, 14),
        size=udim2(1, -28, 1, -28),
        background=color(28, 135, 204),
        transparency=0,
        zindex=46,
    )
    water.children.extend(
        [
            corner("WaterCorner", 16),
            stroke("WaterStroke", (12, 68, 128), 2, 0.2),
            gradient("WaterGradient", (70, 190, 230), (17, 98, 177)),
        ]
    )
    catch_bar = frame(
        "CatchBar",
        position=udim2(0.5, 0, 0.68, 0),
        size=udim2(1, -32, 0.24, 0),
        anchor=vec2(0.5, 0),
        background=color(43, 225, 70),
        transparency=0,
        zindex=48,
    )
    catch_bar.children = [
        corner("CatchBarCorner", 14),
        stroke("CatchBarStroke", (8, 94, 24), 3),
        gradient("CatchBarGradient", (111, 255, 94), (20, 177, 46)),
        gloss("CatchBarGloss", udim2(0, 12, 0, 7), udim2(0, 54, 0, 8), 49),
    ]
    fish_marker = frame(
        "FishMarker",
        position=udim2(0.5, 0, 0.5, 0),
        size=udim2(0, 46, 0, 46),
        anchor=vec2(0.5, 0.5),
        background=color(17, 28, 43),
        transparency=0,
        zindex=50,
    )
    fish_marker.children = [
        corner("FishMarkerCorner", 23),
        stroke("FishMarkerStroke", (255, 255, 255), 2, 0.08),
        Node(
            "ImageLabel",
            "FishImage",
            {
                **gui(position=udim2(0, 5, 0, 5), size=udim2(1, -10, 1, -10), zindex=51),
                "Image": scalar("Content", ""),
                "ScaleType": scalar("token", 1),
            },
        ),
        label(
            "FishMarkerLabel",
            "FISH",
            udim2(0, 0, 0, 0),
            udim2(1, 0, 1, 0),
            11,
            color(255, 255, 255),
            52,
            font=26,
            xalign=1,
            outlined=True,
        ),
    ]
    water.children.extend([catch_bar, fish_marker])
    vertical_panel.children.append(water)
    game_content.children.append(vertical_panel)

    progress_track = frame(
        "ProgressTrack",
        position=udim2(0, 226, 0, 0),
        size=udim2(0, 42, 1, -58),
        background=color(29, 35, 46),
        transparency=0,
        zindex=45,
    )
    progress_track.children = [corner("ProgressCorner", 16), stroke("ProgressStroke", (92, 111, 138), 2)]
    progress_fill = frame(
        "ProgressFill",
        position=udim2(0, 0, 1, 0),
        size=udim2(1, 0, 0.34, 0),
        anchor=vec2(0, 1),
        background=color(62, 190, 255),
        transparency=0,
        zindex=46,
    )
    progress_fill.children = [
        corner("ProgressFillCorner", 16),
        gradient("ProgressFillGradient", (130, 235, 255), (26, 132, 255)),
    ]
    progress_track.children.append(progress_fill)
    game_content.children.extend(
        [
            progress_track,
            label(
                "MinigameFishInfo",
                "Fish",
                udim2(0, 296, 0, 18),
                udim2(1, -306, 0, 46),
                18,
                color(255, 255, 255),
                45,
                font=26,
                wrapped=True,
                outlined=True,
            ),
            label(
                "MinigameProgressText",
                "Progress 34%",
                udim2(0, 296, 0, 76),
                udim2(1, -306, 0, 30),
                15,
                color(210, 230, 255),
                45,
                font=19,  # GothamBold
            ),
            label(
                "MinigameInstruction",
                "Hold mouse, tap, or Space to lift the green bar.",
                udim2(0, 296, 0, 116),
                udim2(1, -306, 0, 70),
                14,
                color(210, 230, 255),
                45,
                font=17,  # Gotham
                wrapped=True,
            ),
        ]
    )
    root.children.append(game_content)

    cast_content = frame(
        "CastPowerContent",
        position=udim2(0, 40, 0, 92),
        size=udim2(1, -80, 1, -126),
        transparency=1,
        visible=False,
        zindex=44,
    )
    cast_title = label(
        "CastPowerTitle",
        "Hold to charge. Release to cast.",
        udim2(0, 0, 0, 8),
        udim2(1, 0, 0, 36),
        20,
        color(255, 255, 255),
        45,
        font=26,
        xalign=1,
        scaled=True,
        outlined=True,
    )
    cast_title.children = [text_constraint(16, 22)]
    cast_content.children.append(cast_title)

    cast_track = frame(
        "CastPowerTrack",
        position=udim2(0, 14, 0, 96),
        size=udim2(1, -28, 0, 58),
        background=color(27, 73, 132),
        transparency=0,
        zindex=45,
    )
    cast_track.children.extend(
        [
            corner("CastTrackCorner", 22),
            stroke("CastTrackOuterStroke", (7, 48, 106), 5),
            stroke("CastTrackHighlightStroke", (126, 219, 255), 2, 0.18),
            gradient("CastTrackGradient", (62, 153, 213), (16, 69, 137)),
        ]
    )
    perfect_zone = frame(
        "PerfectTimingZone",
        position=udim2(0.675, 0, 0, 0),
        size=udim2(0.09, 0, 1, 0),
        background=color(61, 255, 132),
        transparency=0.12,
        zindex=46,
    )
    perfect_zone.children = [
        corner("PerfectZoneCorner", 18),
        stroke("PerfectZoneStroke", (10, 120, 42), 3, 0.1),
        gradient("PerfectZoneGradient", (117, 255, 129), (23, 190, 72)),
    ]
    power_fill = frame(
        "PowerFill",
        size=udim2(0, 0, 1, 0),
        background=color(255, 204, 65),
        transparency=0,
        zindex=47,
    )
    power_fill.children = [
        corner("PowerFillCorner", 18),
        gradient("PowerFillGradient", (255, 235, 121), (255, 126, 40)),
    ]
    bobber = frame(
        "BobberMarker",
        position=udim2(0, 0, 0.5, 0),
        size=udim2(0, 18, 1, 28),
        anchor=vec2(0.5, 0.5),
        background=color(255, 255, 255),
        transparency=0,
        zindex=49,
    )
    bobber.children = [corner("BobberCorner", 9), stroke("BobberStroke", (7, 55, 128), 3)]
    cast_track.children.extend([perfect_zone, power_fill, bobber])
    cast_content.children.extend(
        [
            cast_track,
            label(
                "CastPowerValue",
                "Power 0%",
                udim2(0, 0, 0, 168),
                udim2(1, 0, 0, 30),
                16,
                color(255, 255, 255),
                45,
                font=19,  # GothamBold
                xalign=1,
                outlined=True,
            ),
            label(
                "CastPowerStatus",
                "Release in the green zone for a Perfect cast.",
                udim2(0, 0, 0, 206),
                udim2(1, 0, 0, 46),
                15,
                color(218, 239, 255),
                45,
                font=17,  # Gotham
                xalign=1,
                wrapped=True,
            ),
            label(
                "CastPowerHint",
                "Mouse, tap, or Space",
                udim2(0, 0, 1, -64),
                udim2(1, 0, 0, 28),
                14,
                color(184, 219, 255),
                45,
                font=17,  # Gotham
                xalign=1,
            ),
        ]
    )
    root.children.append(cast_content)
    return root


def add_property(parent: ET.Element, name: str, declaration: tuple[str, Any]) -> None:
    kind, value = declaration
    element = ET.SubElement(parent, kind, {"name": name})
    if kind in {"string", "float", "int", "token", "bool"}:
        element.text = str(value).lower() if kind == "bool" else str(value)
    elif kind == "UDim":
        scale, offset = value
        ET.SubElement(element, "S").text = str(scale)
        ET.SubElement(element, "O").text = str(offset)
    elif kind == "UDim2":
        xs, xo, ys, yo = value
        ET.SubElement(element, "XS").text = str(xs)
        ET.SubElement(element, "XO").text = str(xo)
        ET.SubElement(element, "YS").text = str(ys)
        ET.SubElement(element, "YO").text = str(yo)
    elif kind == "Vector2":
        x, y = value
        ET.SubElement(element, "X").text = str(x)
        ET.SubElement(element, "Y").text = str(y)
    elif kind == "Color3":
        r, g, b = value
        ET.SubElement(element, "R").text = str(r)
        ET.SubElement(element, "G").text = str(g)
        ET.SubElement(element, "B").text = str(b)
    elif kind == "Content":
        ET.SubElement(element, "url").text = value
    elif kind == "ColorSequence":
        encoded: list[float] = []
        for time, r, g, b in value:
            encoded.extend((time, r / 255, g / 255, b / 255, 0))
        element.text = " ".join(str(part) for part in encoded)
    elif kind == "NumberSequence":
        element.text = " ".join(
            str(part)
            for time, sequence_value in value
            for part in (time, sequence_value, 0)
        )
    else:
        raise ValueError(f"Unsupported property kind: {kind}")


def add_node(parent: ET.Element, node: Node, counter: list[int]) -> None:
    counter[0] += 1
    item = ET.SubElement(parent, "Item", {"class": node.class_name, "referent": f"RBX{counter[0]:08X}"})
    properties = ET.SubElement(item, "Properties")
    ET.SubElement(properties, "string", {"name": "Name"}).text = node.name
    for property_name in sorted(node.props):
        add_property(properties, property_name, node.props[property_name])
    for child in node.children:
        add_node(item, child, counter)


def main() -> None:
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
    add_node(document, make_model(), [0])
    ET.indent(document, space="\t")
    OUTPUT.write_text(ET.tostring(document, encoding="unicode") + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

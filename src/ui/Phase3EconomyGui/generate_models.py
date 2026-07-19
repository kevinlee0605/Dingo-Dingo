"""Generate the script-free Phase3EconomyGui daily-reward surfaces.

The controller only binds these authored instances and clones the hidden card
templates.  Sea Stars and Shop are deliberately absent: FishingGui and
EconomyUIIntegration own those surfaces.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
import xml.etree.ElementTree as ET


HERE = Path(__file__).resolve().parent

FONT_GOTHAM = 17
FONT_FREDOKA_ONE = 26

SCALE_TYPE_STRETCH = 0
SCALE_TYPE_SLICE = 1
SCALE_TYPE_FIT = 3


@dataclass
class Node:
    class_name: str
    name: str
    props: dict[str, tuple[str, Any]] = field(default_factory=dict)
    children: list["Node"] = field(default_factory=list)


def prop(kind: str, value: Any) -> tuple[str, Any]:
    return kind, value


def udim(scale: float = 0, offset: int = 0) -> tuple[str, tuple[float, int]]:
    return "UDim", (scale, offset)


def udim2(xs: float, xo: int, ys: float, yo: int) -> tuple[str, tuple[float, int, float, int]]:
    return "UDim2", (xs, xo, ys, yo)


def vec2(x: float, y: float) -> tuple[str, tuple[float, float]]:
    return "Vector2", (x, y)


def color(r: int, g: int, b: int) -> tuple[str, tuple[float, float, float]]:
    return "Color3", (r / 255, g / 255, b / 255)


def color_sequence(*keypoints: tuple[float, tuple[int, int, int]]) -> tuple[str, Any]:
    return "ColorSequence", keypoints


def gui_props(
    *,
    position: tuple[str, Any] = udim2(0, 0, 0, 0),
    size: tuple[str, Any] = udim2(1, 0, 1, 0),
    anchor: tuple[str, Any] = vec2(0, 0),
    background: tuple[str, Any] = color(0, 0, 0),
    transparency: float = 1,
    visible: bool = True,
    zindex: int = 1,
    clips: bool = False,
    layout_order: int = 0,
) -> dict[str, tuple[str, Any]]:
    return {
        "AnchorPoint": anchor,
        "BackgroundColor3": background,
        "BackgroundTransparency": prop("float", transparency),
        "BorderSizePixel": prop("int", 0),
        "ClipsDescendants": prop("bool", clips),
        "LayoutOrder": prop("int", layout_order),
        "Position": position,
        "Size": size,
        "Visible": prop("bool", visible),
        "ZIndex": prop("int", zindex),
    }


def frame(name: str, **kwargs: Any) -> Node:
    return Node("Frame", name, gui_props(**kwargs))


def image(name: str, image_id: str, *, scale_type: int, **kwargs: Any) -> Node:
    """Author an ImageLabel with its verified v1615 ScaleType.

    ScaleType is deliberately required. The original runtime UI mixed Stretch
    for full-panel/virtually-cropped art with Fit for icons and decorations.
    """
    props = gui_props(**kwargs)
    props.update(
        {"Image": prop("Content", image_id), "ScaleType": prop("token", scale_type)}
    )
    return Node("ImageLabel", name, props)


def image_button(
    name: str, image_id: str = "", *, scale_type: int, **kwargs: Any
) -> Node:
    """Author an ImageButton with an explicitly verified ScaleType."""
    props = gui_props(**kwargs)
    props.update(
        {
            "Active": prop("bool", True),
            "AutoButtonColor": prop("bool", True),
            "Image": prop("Content", image_id),
            "ScaleType": prop("token", scale_type),
            "Selectable": prop("bool", True),
        }
    )
    return Node("ImageButton", name, props)


def label(
    name: str,
    text: str,
    *,
    text_size: int,
    text_color: tuple[int, int, int] = (255, 255, 255),
    align: int = 0,
    scaled: bool = False,
    font: int = FONT_GOTHAM,
    **kwargs: Any,
) -> Node:
    props = gui_props(**kwargs)
    props.update(
        {
            "Font": prop("token", font),
            "RichText": prop("bool", False),
            "Text": prop("string", text),
            "TextColor3": color(*text_color),
            "TextScaled": prop("bool", scaled),
            "TextSize": prop("float", text_size),
            "TextStrokeColor3": color(0, 0, 0),
            "TextStrokeTransparency": prop("float", 0),
            "TextTransparency": prop("float", 0),
            "TextWrapped": prop("bool", False),
            "TextXAlignment": prop("token", align),
            "TextYAlignment": prop("token", 1),
        }
    )
    return Node("TextLabel", name, props)


def corner(radius: int, name: str = "UICorner") -> Node:
    return Node("UICorner", name, {"CornerRadius": udim(0, radius)})


def stroke(r: int, g: int, b: int, thickness: float, transparency: float = 0) -> Node:
    return Node(
        "UIStroke",
        "UIStroke",
        {
            "Color": color(r, g, b),
            "Thickness": prop("float", thickness),
            "Transparency": prop("float", transparency),
        },
    )


def make_surface() -> Node:
    surface = frame("DailyRewardSurface", zindex=1000)

    overlay = frame(
        "LoginRewardOverlay",
        background=color(7, 10, 15),
        transparency=1,
        visible=False,
        zindex=1100,
    )
    panel = frame(
        "LoginPanel",
        position=udim2(0.5, 0, 0.5, 0),
        size=udim2(0, 1400, 0, 1050),
        anchor=vec2(0.5, 0.5),
        zindex=1101,
    )
    panel.children.append(Node("UIScale", "LoginScale", {"Scale": prop("float", 0.53)}))
    panel.children.append(
        image(
            "LoginBackground",
            "rbxassetid://117777143534466",
            scale_type=SCALE_TYPE_STRETCH,
            zindex=1101,
        )
    )
    panel.children.append(
        image(
            "LoginTopDecoration",
            "rbxassetid://113416899840266",
            scale_type=SCALE_TYPE_FIT,
            position=udim2(0, 36, 0, 34),
            size=udim2(0, 150, 0, 150),
            zindex=1102,
        )
    )
    panel.children.append(
        label(
            "LoginTitle",
            "Daily Login Rewards",
            text_size=60,
            font=FONT_FREDOKA_ONE,
            position=udim2(0, 0, 0, 48),
            size=udim2(1, 0, 0, 76),
            align=2,
            zindex=1103,
        )
    )
    login_close = image_button(
            "LoginClose",
            "rbxassetid://119322438066977",
            scale_type=SCALE_TYPE_FIT,
            position=udim2(0, 1180, 0, 8),
            size=udim2(0, 200, 0, 200),
            zindex=1104,
        )
    login_close.children.append(Node("UIScale", "PressScale", {"Scale": prop("float", 1)}))
    panel.children.append(login_close)
    panel.children.append(
        label(
            "LoginInfo",
            "Missing dates never resets or skips your progress.",
            text_size=22,
            text_color=(210, 225, 245),
            position=udim2(0, 246, 0, 126),
            size=udim2(0, 900, 0, 30),
            zindex=1103,
        )
    )
    panel.children.append(
        label(
            "LoginTimer",
            "Daily rewards reset at 24:00 (Server's UTC Time)",
            text_size=22,
            text_color=(0, 237, 255),
            position=udim2(0, 246, 0, 154),
            size=udim2(0, 900, 0, 30),
            zindex=1103,
        )
    )

    grid_props = gui_props(
        position=udim2(0, 76, 0, 218),
        size=udim2(0, 1220, 0, 700),
        clips=True,
        zindex=1103,
    )
    grid_props.update(
        {
            "Active": prop("bool", True),
            "AutomaticCanvasSize": prop("token", 0),
            "CanvasSize": udim2(0, 0, 0, 0),
            "ScrollBarImageTransparency": prop("float", 1),
            "ScrollBarThickness": prop("int", 0),
            "ScrollingDirection": prop("token", 2),
            "ScrollingEnabled": prop("bool", True),
        }
    )
    grid = Node("ScrollingFrame", "LoginGrid", grid_props)
    grid.children.append(
        Node(
            "UIGridLayout",
            "DailyRewardGridLayout",
            {
                "CellPadding": udim2(0, 12, 0, 12),
                "CellSize": udim2(0, 296, 0, 168),
                "FillDirection": prop("token", 0),
                "FillDirectionMaxCells": prop("int", 4),
                "SortOrder": prop("token", 2),
            },
        )
    )
    panel.children.append(grid)

    scrollbar = frame(
        "DailyRewardCustomScrollbar",
        position=udim2(0, 1303, 0, 226),
        size=udim2(0, 42, 0, 670),
        clips=True,
        zindex=1120,
    )
    scrollbar_art = image(
            "DailyRewardScrollbarArt",
            "rbxassetid://73367138577137",
            scale_type=SCALE_TYPE_STRETCH,
            position=udim2(-683 / 65, 0, -29 / 1021, 0),
            size=udim2(1448 / 65, 0, 1086 / 1021, 0),
            zindex=1120,
        )
    scrollbar.children.append(scrollbar_art)
    lane = frame(
        "DailyRewardScrollLane",
        position=udim2(0.5, 0, 0, 0),
        size=udim2(0, 22, 1, -6),
        anchor=vec2(0.5, 0),
        background=color(5, 27, 73),
        transparency=0,
        clips=True,
        zindex=1121,
    )
    lane.props["Active"] = prop("bool", True)
    lane.children.append(corner(11))
    lane.children.append(
        Node(
            "UIGradient",
            "LaneGradient",
            {
                "Color": color_sequence(
                    (0, (10, 48, 111)),
                    (0.5, (3, 20, 61)),
                    (1, (10, 48, 111)),
                ),
                "Rotation": prop("float", 0),
            },
        )
    )
    thumb = image_button(
        "DailyRewardMovingThumb",
        scale_type=SCALE_TYPE_STRETCH,
        position=udim2(0.5, 0, 0, 0),
        size=udim2(0, 22, 0, 96),
        anchor=vec2(0.5, 0),
        background=color(0, 125, 255),
        transparency=0,
        zindex=1122,
    )
    thumb.children.extend(
        [
            corner(11),
            stroke(82, 246, 255, 2),
            Node(
                "UIGradient",
                "ThumbGradient",
                {
                    "Color": color_sequence(
                        (0, (67, 246, 255)),
                        (0.38, (0, 170, 255)),
                        (1, (25, 70, 235)),
                    ),
                    "Rotation": prop("float", 90),
                },
            ),
        ]
    )
    highlight = frame(
        "ThumbHighlight",
        position=udim2(0, 3, 0, 5),
        size=udim2(0, 3, 1, -10),
        background=color(218, 255, 255),
        transparency=0.56,
        zindex=1123,
    )
    highlight.children.append(corner(3))
    thumb.children.append(highlight)
    lane.children.append(thumb)
    scrollbar.children.append(lane)
    panel.children.append(scrollbar)

    panel.children.append(
        image(
            "LoginBottomDecoration",
            "rbxassetid://93536836630458",
            scale_type=SCALE_TYPE_FIT,
            position=udim2(0, 34, 0, 914),
            size=udim2(0, 132, 0, 116),
            zindex=1102,
        )
    )
    panel.children.append(
        label(
            "LoginStatus",
            "",
            text_size=1,
            position=udim2(0, 0, 0, 0),
            size=udim2(0, 0, 0, 0),
            visible=False,
            zindex=1103,
        )
    )
    claim = image_button(
        "ClaimButton",
        scale_type=SCALE_TYPE_STRETCH,
        position=udim2(0, 1038, 0, 912),
        size=udim2(0, 288, 0, 68),
        clips=True,
        zindex=1104,
    )
    claim.children.extend(
        [
            image(
                "ClaimButtonArt",
                "rbxassetid://139579773560573",
                scale_type=SCALE_TYPE_STRETCH,
                position=udim2(-68 / 1543, 0, -272 / 431, 0),
                size=udim2(1672 / 1543, 0, 941 / 431, 0),
                zindex=1104,
            ),
            label(
                "ClaimButtonLabel",
                "Claim Day 1",
                text_size=30,
                font=FONT_FREDOKA_ONE,
                position=udim2(0.5, 0, 0.5, 0),
                size=udim2(0.78, 0, 0.74, 0),
                anchor=vec2(0.5, 0.5),
                align=2,
                zindex=1105,
            ),
        ]
    )
    panel.children.append(claim)
    overlay.children.append(panel)
    surface.children.append(overlay)
    return surface


def make_templates() -> Node:
    templates = Node("Folder", "DailyRewardTemplates")
    card = frame(
        "DayCardTemplate",
        size=udim2(0, 293, 0, 168),
        visible=False,
        clips=True,
        zindex=1104,
    )
    card.children.extend(
        [
            image(
                "CardArt",
                "rbxassetid://86912435019607",
                scale_type=SCALE_TYPE_STRETCH,
                zindex=1104,
            ),
            label(
                "DayLabel",
                "Day 1",
                text_size=25,
                font=FONT_FREDOKA_ONE,
                position=udim2(0, 20, 0, 10),
                size=udim2(1, -40, 0, 32),
                zindex=1106,
            ),
            image(
                "MilestoneIcon",
                "rbxassetid://70463548759658",
                scale_type=SCALE_TYPE_FIT,
                position=udim2(0, 18, 0, 66),
                size=udim2(0, 82, 0, 82),
                visible=False,
                zindex=1106,
            ),
        ]
    )
    templates.children.append(card)

    reward_line = frame(
        "RewardLineTemplate",
        size=udim2(0, 250, 0, 40),
        visible=False,
        zindex=1106,
    )
    reward_line.children.extend(
        [
            image(
                "RewardIcon",
                "",
                scale_type=SCALE_TYPE_FIT,
                position=udim2(0, 0, 0, 0),
                size=udim2(0, 40, 0, 40),
                zindex=1106,
            ),
            label(
                "RewardText",
                "Reward",
                text_size=20,
                position=udim2(0, 58, 0, 4),
                size=udim2(1, -58, 0, 28),
                zindex=1107,
            ),
        ]
    )
    templates.children.append(reward_line)

    milestone_line = frame(
        "MilestoneRewardLineTemplate",
        size=udim2(0, 177, 0, 21),
        visible=False,
        zindex=1106,
    )
    milestone_line.children.append(
        label(
            "RewardText",
            "Reward",
            text_size=16,
            position=udim2(0, 0, 0, 0),
            size=udim2(1, 0, 1, 0),
            zindex=1107,
        )
    )
    templates.children.append(milestone_line)
    templates.children.append(
        image(
            "ClaimedIconTemplate",
            "rbxassetid://94167472129143",
            scale_type=SCALE_TYPE_FIT,
            position=udim2(0.5, 0, 0.53, 0),
            size=udim2(0, 126, 0, 126),
            anchor=vec2(0.5, 0.5),
            visible=False,
            zindex=1110,
        )
    )
    return templates


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
    elif kind == "ColorSequence":
        serialized = []
        for time, rgb in value:
            r, g, b = rgb
            serialized.extend((str(time), str(r / 255), str(g / 255), str(b / 255), "0"))
        element.text = " ".join(serialized)
    elif kind == "Content":
        ET.SubElement(element, "url").text = value
    else:
        raise ValueError(f"Unsupported property kind: {kind}")


def add_node(parent: ET.Element, node: Node, counter: list[int]) -> None:
    counter[0] += 1
    item = ET.SubElement(parent, "Item", {"class": node.class_name, "referent": f"RBX{counter[0]:08X}"})
    properties = ET.SubElement(item, "Properties")
    ET.SubElement(properties, "string", {"name": "Name"}).text = node.name
    for name in sorted(node.props):
        add_property(properties, name, node.props[name])
    for child in node.children:
        add_node(item, child, counter)


def write_model(name: str, node: Node) -> None:
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
    add_node(document, node, [0])
    ET.indent(document, space="\t")
    (HERE / f"{name}.rbxmx").write_text(ET.tostring(document, encoding="unicode") + "\n", encoding="utf-8")


def main() -> None:
    write_model("DailyRewardSurface", make_surface())
    write_model("DailyRewardTemplates", make_templates())


if __name__ == "__main__":
    main()

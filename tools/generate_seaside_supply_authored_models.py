"""Generate the exact authored v1615 Seaside and Supply Shop hierarchies.

The two recovered clients used to construct their complete visual trees at
runtime.  These models persist that same fixed chrome in StarterGui.  The
clients now bind these nodes and clone only the hidden, data-driven row/card
templates declared here.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "src/ui/FishingGui"


@dataclass
class Node:
    class_name: str
    name: str
    props: dict[str, tuple[str, Any]] = field(default_factory=dict)
    children: list["Node"] = field(default_factory=list)


def scalar(kind: str, value: Any) -> tuple[str, Any]:
    return (kind, value)


def udim(scale: float, offset: float) -> tuple[str, tuple[float, float]]:
    return ("UDim", (scale, offset))


def udim2(xs: float, xo: float, ys: float, yo: float) -> tuple[str, tuple[float, float, float, float]]:
    return ("UDim2", (xs, xo, ys, yo))


def vec2(x: float, y: float) -> tuple[str, tuple[float, float]]:
    return ("Vector2", (x, y))


def color(r: int, g: int, b: int) -> tuple[str, tuple[float, float, float]]:
    return ("Color3", (r / 255, g / 255, b / 255))


def content(value: str) -> tuple[str, str]:
    return ("Content", value)


def gui(
    *,
    position: tuple[str, Any] = udim2(0, 0, 0, 0),
    size: tuple[str, Any] = udim2(1, 0, 1, 0),
    anchor: tuple[str, Any] = vec2(0, 0),
    background: tuple[str, Any] = color(255, 255, 255),
    transparency: float = 1,
    visible: bool = True,
    zindex: int = 1,
    clips: bool = False,
) -> dict[str, tuple[str, Any]]:
    return {
        "AnchorPoint": anchor,
        "BackgroundColor3": background,
        "BackgroundTransparency": scalar("float", transparency),
        "BorderSizePixel": scalar("int", 0),
        "ClipsDescendants": scalar("bool", clips),
        "Position": position,
        "Size": size,
        "Visible": scalar("bool", visible),
        "ZIndex": scalar("int", zindex),
    }


def frame(name: str, **kwargs: Any) -> Node:
    return Node("Frame", name, gui(**kwargs))


def text_label(
    name: str,
    text: str,
    position: tuple[str, Any],
    size: tuple[str, Any],
    text_size: int,
    text_color: tuple[str, Any],
    zindex: int,
    *,
    font: int = 26,  # FredokaOne
    xalign: int = 0,
    stroke_transparency: float = 0.05,
    visible: bool = True,
    rich: bool = False,
) -> Node:
    props = gui(position=position, size=size, visible=visible, zindex=zindex)
    props.update(
        {
            "Font": scalar("token", font),
            "RichText": scalar("bool", rich),
            "Text": scalar("string", text),
            "TextColor3": text_color,
            "TextScaled": scalar("bool", False),
            "TextSize": scalar("float", text_size),
            "TextStrokeColor3": color(0, 0, 0),
            "TextStrokeTransparency": scalar("float", stroke_transparency),
            "TextTransparency": scalar("float", 0),
            "TextXAlignment": scalar("token", xalign),
            "TextYAlignment": scalar("token", 1),
        }
    )
    return Node("TextLabel", name, props)


def image_label(
    name: str,
    image: str,
    position: tuple[str, Any],
    size: tuple[str, Any],
    zindex: int,
    *,
    anchor: tuple[str, Any] = vec2(0, 0),
    visible: bool = True,
    scale_type: int = 0,
    image_transparency: float = 0,
) -> Node:
    props = gui(position=position, size=size, anchor=anchor, visible=visible, zindex=zindex)
    props.update(
        {
            "Image": content(image),
            "ImageColor3": color(255, 255, 255),
            "ImageTransparency": scalar("float", image_transparency),
            "ScaleType": scalar("token", scale_type),
        }
    )
    return Node("ImageLabel", name, props)


def image_button(
    name: str,
    position: tuple[str, Any],
    size: tuple[str, Any],
    zindex: int,
    *,
    visible: bool = True,
    clips: bool = False,
    active: bool = True,
) -> Node:
    props = gui(position=position, size=size, visible=visible, zindex=zindex, clips=clips)
    props.update(
        {
            "Active": scalar("bool", active),
            "AutoButtonColor": scalar("bool", False),
            "Image": content(""),
            "ImageColor3": color(255, 255, 255),
            "ImageTransparency": scalar("float", 1),
            "ScaleType": scalar("token", 0),
            "Selectable": scalar("bool", active),
        }
    )
    return Node("ImageButton", name, props)


def mapped_geometry(
    target_width: float,
    target_height: float,
    source: tuple[float, float],
    rect: tuple[float, float, float, float],
) -> tuple[tuple[str, Any], tuple[str, Any]]:
    min_x, min_y, max_x, max_y = rect
    rect_width = max_x - min_x
    rect_height = max_y - min_y
    # v1636 used Luau's integer pixel truncation for the virtual crop. Keeping
    # that behavior avoids the one-pixel expansion/shift visible in Editor.
    full_width = int(target_width * source[0] / rect_width)
    full_height = int(target_height * source[1] / rect_height)
    x = int(-(min_x / source[0]) * full_width)
    y = int(-(min_y / source[1]) * full_height)
    return udim2(0, x, 0, y), udim2(0, full_width, 0, full_height)


def mapped_holder(
    class_name: str,
    name: str,
    image: str,
    position: tuple[str, Any],
    size: tuple[str, Any],
    target_size: tuple[int, int],
    source: tuple[int, int],
    rect: tuple[int, int, int, int],
    zindex: int,
    *,
    visible: bool = True,
    children: list[Node] | None = None,
) -> Node:
    if class_name == "ImageButton":
        holder = image_button(name, position, size, zindex, visible=visible, clips=True)
    else:
        holder = frame(name, position=position, size=size, visible=visible, zindex=zindex, clips=True)
    art_position, art_size = mapped_geometry(target_size[0], target_size[1], source, rect)
    holder.children = [image_label("MappedImage", image, art_position, art_size, zindex)]
    holder.children.extend(children or [])
    return holder


def cropped_holder(
    class_name: str,
    name: str,
    image: str,
    position: tuple[str, Any],
    size: tuple[str, Any],
    source: tuple[int, int],
    offset: tuple[int, int],
    crop_size: tuple[int, int],
    zindex: int,
    *,
    visible: bool = True,
    children: list[Node] | None = None,
) -> Node:
    if class_name == "ImageButton":
        holder = image_button(name, position, size, zindex, visible=visible, clips=True)
    else:
        holder = frame(name, position=position, size=size, visible=visible, zindex=zindex, clips=True)
    artwork = image_label(
        "Artwork",
        image,
        udim2(-offset[0] / crop_size[0], 0, -offset[1] / crop_size[1], 0),
        udim2(source[0] / crop_size[0], 0, source[1] / crop_size[1], 0),
        zindex,
    )
    holder.children = [artwork]
    holder.children.extend(children or [])
    return holder


def corner(name: str, scale: float, offset: int) -> Node:
    return Node("UICorner", name, {"CornerRadius": udim(scale, offset)})


def stroke(name: str, rgb: tuple[int, int, int], thickness: float, transparency: float, *, border: bool = False) -> Node:
    props = {
        "Color": color(*rgb),
        "Thickness": scalar("float", thickness),
        "Transparency": scalar("float", transparency),
    }
    if border:
        props["ApplyStrokeMode"] = scalar("token", 1)
    return Node("UIStroke", name, props)


SEASIDE_ASSETS = {
    "MainBackbone": "rbxassetid://77079984837491",
    "Decoration": "rbxassetid://126541809567975",
    "SelectedTab": "rbxassetid://135116059419917",
    "UnselectedTab": "rbxassetid://104189399468619",
    "SellAllButton": "rbxassetid://82571731099591",
    "SellButton": "rbxassetid://87923116280754",
    "SubMainBackbone": "rbxassetid://120182750042631",
    "Common": "rbxassetid://99716714580964",
    "ScrollThumb": "rbxassetid://73367138577137",
    "CloseButton": "rbxassetid://119322438066977",
}

SEASIDE_CROP = {
    "MainBackbone": ((1448, 1086), (25, 16, 1423, 1051)),
    "Decoration": ((632, 432), (117, 97, 467, 355)),
    "SelectedTab": ((632, 432), (50, 155, 548, 278)),
    "UnselectedTab": ((1536, 1024), (205, 363, 1330, 656)),
    "SellAllButton": ((632, 432), (63, 128, 559, 304)),
    "SellButton": ((632, 432), (57, 145, 545, 294)),
    "SubMainBackbone": ((1448, 1086), (43, 176, 1405, 939)),
    "Common": ((632, 432), (9, 188, 626, 272)),
    "CloseButton": ((1187, 1326), (376, 422, 801, 859)),
}


def seaside_mapped(
    class_name: str,
    name: str,
    asset_key: str,
    x: int,
    y: int,
    width: int,
    height: int,
    zindex: int,
    *,
    visible: bool = True,
    children: list[Node] | None = None,
) -> Node:
    source, rect = SEASIDE_CROP[asset_key]
    holder = mapped_holder(
        class_name,
        name,
        SEASIDE_ASSETS[asset_key],
        udim2(0, x, 0, y),
        udim2(0, width, 0, height),
        (width, height),
        source,
        rect,
        zindex,
        visible=visible,
        children=children,
    )
    if asset_key == "CloseButton":
        # The v1636 close crop used these saved integer offsets with its
        # truncated 312x339 virtual canvas.
        holder.children[0].props["Position"] = udim2(0, -99, 0, -108)
    return holder


def make_seaside_row_template() -> Node:
    sell_button = seaside_mapped(
        "ImageButton",
        "SellButton",
        "SellButton",
        938,
        43,
        244,
        92,
        620,
        children=[
            text_label(
                "Label",
                "Sell",
                udim2(0, 0, 0, 0),
                udim2(1, 0, 1, 0),
                43,
                color(255, 255, 255),
                621,
                xalign=2,
            ),
            Node("UIScale", "PressScale", {"Scale": scalar("float", 1)}),
        ],
    )
    return seaside_mapped(
        "Frame",
        "FishRowTemplate",
        "Common",
        0,
        0,
        1228,
        178,
        614,
        visible=False,
        children=[
            image_label(
                "FishIcon",
                "",
                udim2(0, 34, 0, 18),
                udim2(0, 155, 0, 140),
                617,
                visible=False,
                scale_type=3,
            ),
            text_label(
                "MissingFishIcon",
                "FISH",
                udim2(0, 34, 0, 18),
                udim2(0, 155, 0, 140),
                29,
                color(210, 230, 255),
                617,
                font=19,  # GothamBold
                xalign=2,
                visible=False,
            ),
            text_label(
                "FishName",
                "Fish [Common]",
                udim2(0, 245, 0, 25),
                udim2(0, 650, 0, 58),
                42,
                color(236, 242, 255),
                618,
                font=20,  # GothamBlack
            ),
            text_label(
                "FishValue",
                "Sell value: 0 coins",
                udim2(0, 245, 0, 88),
                udim2(0, 650, 0, 48),
                31,
                color(167, 198, 255),
                618,
                font=18,  # GothamMedium
                stroke_transparency=0.65,
            ),
            sell_button,
        ],
    )


def make_seaside_tab(name: str, label_text: str, x: int, selected: bool) -> Node:
    key = "SelectedTab" if selected else "UnselectedTab"
    return seaside_mapped(
        "ImageButton",
        name,
        key,
        x,
        0,
        370,
        94,
        615,
        children=[
            text_label(
                "Label",
                label_text,
                udim2(0, 0, 0, 0),
                udim2(1, 0, 1, 0),
                36 if selected else 39,
                color(255, 255, 255),
                617,
                xalign=2,
            ),
            Node("UIScale", "PressScale", {"Scale": scalar("float", 1)}),
        ],
    )


def make_seaside() -> Node:
    sell_all = seaside_mapped(
        "ImageButton",
        "SellAllButton",
        "SellAllButton",
        995,
        42,
        270,
        104,
        620,
        children=[
            text_label(
                "Label",
                "Sell All",
                udim2(0, 0, 0, 0),
                udim2(1, 0, 1, 0),
                41,
                color(255, 255, 255),
                621,
                xalign=2,
            ),
            Node("UIScale", "PressScale", {"Scale": scalar("float", 1)}),
        ],
    )
    close = seaside_mapped(
        "ImageButton",
        "CloseButton",
        "CloseButton",
        1280,
        38,
        112,
        112,
        625,
        children=[Node("UIScale", "PressScale", {"Scale": scalar("float", 1)})],
    )

    list_props = gui(
        position=udim2(0, 10, 0, 11),
        size=udim2(0, 1238, 0, 742),
        zindex=612,
        clips=True,
    )
    list_props.update(
        {
            "Active": scalar("bool", True),
            "AutomaticCanvasSize": scalar("token", 0),
            "CanvasPosition": vec2(0, 0),
            "CanvasSize": udim2(0, 0, 0, 0),
            "ElasticBehavior": scalar("token", 1),
            "ScrollBarImageColor3": color(0, 0, 0),
            "ScrollBarImageTransparency": scalar("float", 1),
            "ScrollBarThickness": scalar("int", 0),
            "ScrollingDirection": scalar("token", 2),
            "ScrollingEnabled": scalar("bool", True),
        }
    )
    fish_list = Node(
        "ScrollingFrame",
        "FishList",
        list_props,
        [
            Node(
                "UIListLayout",
                "ListLayout",
                {
                    "FillDirection": scalar("token", 1),
                    "HorizontalAlignment": scalar("token", 1),
                    "Padding": udim(0, 10),
                    "SortOrder": scalar("token", 2),
                },
            ),
            make_seaside_row_template(),
            text_label(
                "StatusLabel",
                "Loading fish...",
                udim2(0, 0, 0, 0),
                udim2(0, 1228, 0, 140),
                42,
                color(255, 255, 255),
                616,
                font=20,  # GothamBlack
                xalign=2,
                visible=False,
            ),
        ],
    )

    thumb_props = gui(
        position=udim2(0, 2, 0, 0),
        size=udim2(0, 24, 0, 742),
        background=color(0, 92, 255),
        transparency=0,
        zindex=618,
    )
    thumb_props.update(
        {
            "Active": scalar("bool", True),
            "AutoButtonColor": scalar("bool", False),
            "Selectable": scalar("bool", False),
            "Text": scalar("string", ""),
            "TextTransparency": scalar("float", 1),
        }
    )
    scroll_thumb = Node(
        "TextButton",
        "ScrollThumb",
        thumb_props,
        [
            corner("ThumbCorner", 1, 0),
            Node(
                "UIGradient",
                "ThumbGradient",
                {
                    "Color": (
                        "ColorSequence",
                        [
                            (0, 0, 213, 255),
                            (0.32, 0, 130, 255),
                            (1, 0, 48, 210),
                        ],
                    ),
                    "Rotation": scalar("float", 90),
                },
            ),
            stroke("ThumbStroke", (0, 220, 255), 2, 0.05, border=True),
            Node(
                "ImageLabel",
                "Texture",
                {
                    **gui(position=udim2(0, 0, 0, 0), size=udim2(1, 0, 1, 0), zindex=619),
                    "Image": content(SEASIDE_ASSETS["ScrollThumb"]),
                    "ImageColor3": color(255, 255, 255),
                    "ImageTransparency": scalar("float", 0),
                    "ScaleType": scalar("token", 1),
                    "SliceCenter": ("Rect2D", (8, 90, 28, 717)),
                    "SliceScale": scalar("float", 1),
                },
            ),
        ],
    )
    scroll_thumb.props["Visible"] = scalar("bool", False)
    scroll_track = frame(
        "ScrollTrack",
        position=udim2(0, 1263, 0, 17),
        size=udim2(0, 28, 0, 742),
        background=color(1, 17, 50),
        transparency=0.04,
        zindex=616,
    )
    scroll_track.props["Visible"] = scalar("bool", False)
    scroll_track.props["Active"] = scalar("bool", True)
    scroll_track.children = [
        corner("TrackCorner", 0, 28),
        stroke("TrackStroke", (0, 102, 255), 2, 0.02),
        scroll_thumb,
    ]

    clip = frame(
        "SubContentClip",
        position=udim2(0, 62, 0, 243),
        size=udim2(0, 1324, 0, 794),
        zindex=611,
        clips=True,
    )
    clip.children = [fish_list, scroll_track]

    root = frame(
        "ModernSeasideShop",
        position=udim2(0.5, 0, 0.4, 0),
        size=udim2(0, 1448, 0, 1086),
        anchor=vec2(0.5, 0.5),
        visible=False,
        zindex=600,
    )
    root.children = [
        Node("UIScale", "ResponsiveScale", {"Scale": scalar("float", 1)}),
        seaside_mapped("Frame", "MainBackbone", "MainBackbone", 0, 0, 1448, 1086, 600),
        seaside_mapped("Frame", "Decoration", "Decoration", 48, 24, 190, 145, 605),
        text_label(
            "Title",
            "SEASIDE SHOP",
            udim2(0, 245, 0, 30),
            udim2(0, 720, 0, 115),
            72,
            color(255, 255, 255),
            606,
            font=20,  # GothamBlack
        ),
        sell_all,
        close,
        frame(
            "SortTabs",
            position=udim2(0, 72, 0, 158),
            size=udim2(0, 754, 0, 94),
            zindex=610,
        ),
        seaside_mapped("Frame", "SubMainBackbone", "SubMainBackbone", 54, 235, 1340, 810, 608),
        clip,
    ]
    tabs = root.children[6]
    tabs.children = [
        make_seaside_tab("RarityTab", "Rarity: High", 0, True),
        make_seaside_tab("ValueTab", "Value", 384, False),
    ]
    return root


SUPPLY_ASSETS = {
    "MainBackbone": "rbxassetid://77079984837491",
    "SubMainBackbone": "rbxassetid://120182750042631",
    "IndividualUITab": "rbxassetid://127925036253260",
    "SectionTab": "rbxassetid://131015417525927",
    "SectionTabSelected": "rbxassetid://83228267224190",
    "ShopIcon": "rbxassetid://96250612796056",
    "FishingRodIcon": "rbxassetid://100331440979418",
    "BaitIcon": "rbxassetid://88745847129808",
    "BlueButton": "rbxassetid://125521996931477",
    "GreenButton": "rbxassetid://137614054152455",
    "RedButton": "rbxassetid://79554836514436",
    "ScrollBar": "rbxassetid://73367138577137",
    "CloseButton": "rbxassetid://119322438066977",
}

SUPPLY_CROP = {
    "MainBackbone": ((1448, 1086), (33, 24), (1382, 1019)),
    "SubMainBackbone": ((1448, 1086), (43, 176), (1362, 763)),
    "IndividualUITab": ((1448, 1086), (10, 355), (1428, 277)),
    "SectionTab": ((1254, 1254), (70, 460), (1115, 353)),
    "SectionTabSelected": ((1254, 1254), (49, 468), (1156, 328)),
    "ShopIcon": ((1254, 1254), (119, 216), (1009, 751)),
    "FishingRodIcon": ((1254, 1254), (371, 354), (469, 532)),
    "BaitIcon": ((1254, 1254), (402, 317), (415, 609)),
    "BlueButton": ((1254, 1254), (117, 480), (1015, 372)),
    "GreenButton": ((1254, 1254), (117, 480), (1015, 372)),
    "RedButton": ((1254, 1254), (119, 479), (1011, 375)),
    "ScrollBar": ((1448, 1086), (683, 29), (65, 1021)),
    "CloseButton": ((1187, 1326), (375, 422), (427, 439)),
}


def supply_holder(
    class_name: str,
    name: str,
    asset_key: str,
    x: int,
    y: int,
    width: int,
    height: int,
    zindex: int,
    *,
    visible: bool = True,
    children: list[Node] | None = None,
) -> Node:
    source, offset, crop_size = SUPPLY_CROP[asset_key]
    return cropped_holder(
        class_name,
        name,
        SUPPLY_ASSETS[asset_key],
        udim2(0, x, 0, y),
        udim2(0, width, 0, height),
        source,
        offset,
        crop_size,
        zindex,
        visible=visible,
        children=children,
    )


def supply_item_icon() -> Node:
    holder = frame(
        "ItemIconHolder",
        position=udim2(0, 28, 0, 14),
        size=udim2(0, 160, 0, 136),
        zindex=513,
        clips=True,
    )
    holder.children = [
        image_label(
            "ItemIcon",
            "",
            udim2(0.5, 0, 0.5, 0),
            udim2(0.84, 0, 0.84, 0),
            514,
            anchor=vec2(0.5, 0.5),
            scale_type=3,
        )
    ]
    return holder


def supply_status_button(label_text: str = "Not Enough") -> Node:
    return supply_holder(
        "ImageButton",
        "StatusButton",
        "RedButton",
        930,
        38,
        252,
        88,
        516,
        children=[
            text_label(
                "Label",
                label_text,
                udim2(0, 0, 0, 0),
                udim2(1, 0, 1, 0),
                29 if label_text == "Not Enough" else 36,
                color(255, 255, 255),
                518,
                xalign=2,
            )
        ],
    )


def supply_card(name: str, *, rod: bool) -> Node:
    children = [supply_item_icon()]
    if rod:
        children.extend(
            [
                text_label("ItemName", "Wooden Rod", udim2(0, 240, 0, 10), udim2(0, 650, 0, 46), 39, color(255, 255, 255), 513),
                text_label("Info", "Level 1 (<font color='#62FF53'>Met</font>)   |   <font color='#FFD51E'>0 Coins</font> (<font color='#62FF53'>Met</font>)", udim2(0, 240, 0, 55), udim2(0, 675, 0, 28), 23, color(160, 194, 255), 513, font=18, stroke_transparency=0.65, rich=True),
                text_label("Requirements", "Previous: None (Met)   |   Resources: None (Met)", udim2(0, 240, 0, 86), udim2(0, 680, 0, 28), 21, color(98, 255, 83), 513, font=18, stroke_transparency=0.7),
                text_label("Status", "Currently equipped.", udim2(0, 240, 0, 119), udim2(0, 680, 0, 28), 21, color(98, 255, 83), 513, font=18, stroke_transparency=0.7),
            ]
        )
    else:
        children.extend(
            [
                text_label("ItemName", "Fresh Bait", udim2(0, 240, 0, 18), udim2(0, 650, 0, 50), 43, color(255, 255, 255), 513),
                text_label("Description", "Slightly faster bites.", udim2(0, 240, 0, 68), udim2(0, 675, 0, 34), 25, color(154, 190, 255), 513, font=18, stroke_transparency=0.72),
                text_label("Detail", "0 left   |   <font color='#FFD51E'>80 coins / 10</font>   |   Lv 1", udim2(0, 240, 0, 106), udim2(0, 675, 0, 36), 25, color(160, 194, 255), 513, font=18, stroke_transparency=0.72, rich=True),
            ]
        )
    children.append(supply_status_button("Equipped" if rod else "Not Enough"))
    return supply_holder(
        "Frame",
        name,
        "IndividualUITab",
        0,
        0,
        1238,
        164,
        508,
        visible=False,
        children=children,
    )


def supply_tab(name: str, label_text: str, x: int, icon_key: str, selected: bool) -> Node:
    icon_crop = SUPPLY_CROP[icon_key]
    crop_size = icon_crop[2]
    icon_width = round(66 * crop_size[0] / crop_size[1])
    icon_width = max(1, min(84, icon_width))
    icon_x = 42 + (84 - icon_width) // 2
    icon = supply_holder(
        "Frame",
        "Icon",
        icon_key,
        icon_x,
        7,
        icon_width,
        66,
        513,
    )
    return supply_holder(
        "ImageButton",
        name,
        "SectionTabSelected" if selected else "SectionTab",
        x,
        0,
        355,
        80,
        510,
        children=[
            icon,
            text_label("Label", label_text, udim2(0, 130, 0, 8), udim2(0, 185, 0, 66), 40, color(255, 255, 255), 514, xalign=2),
        ],
    )


def make_supply() -> Node:
    list_props = gui(
        position=udim2(0, 70, 0, 248),
        size=udim2(0, 1252, 0, 780),
        zindex=506,
        clips=True,
    )
    list_props.update(
        {
            "Active": scalar("bool", True),
            "AutomaticCanvasSize": scalar("token", 0),
            "CanvasPosition": vec2(0, 0),
            "CanvasSize": udim2(0, 0, 0, 0),
            "ElasticBehavior": scalar("token", 1),
            "ScrollBarThickness": scalar("int", 0),
            "ScrollingDirection": scalar("token", 2),
            "ScrollingEnabled": scalar("bool", True),
            "Selectable": scalar("bool", True),
        }
    )
    supply_list = Node(
        "ScrollingFrame",
        "SupplyShopList",
        list_props,
        [
            Node(
                "UIListLayout",
                "ListLayout",
                {
                    "FillDirection": scalar("token", 1),
                    "HorizontalAlignment": scalar("token", 1),
                    "Padding": udim(0, 8),
                    "SortOrder": scalar("token", 2),
                },
            ),
            supply_card("RodCardTemplate", rod=True),
            supply_card("BaitCardTemplate", rod=False),
            text_label(
                "LoadingLabel",
                "Loading supplies...",
                udim2(0, 0, 0, 0),
                udim2(0, 1238, 0, 100),
                36,
                color(255, 255, 255),
                505,
                xalign=2,
                visible=False,
            ),
        ],
    )

    scroll_thumb = supply_holder(
        "ImageButton",
        "ScrollThumb",
        "ScrollBar",
        1,
        0,
        25,
        220,
        511,
    )
    scroll_thumb.props["Visible"] = scalar("bool", False)
    scroll_track = frame(
        "ScrollTrack",
        position=udim2(0, 1332, 0, 246),
        size=udim2(0, 27, 0, 778),
        background=color(1, 19, 54),
        transparency=0.08,
        zindex=509,
    )
    scroll_track.props["Active"] = scalar("bool", True)
    scroll_track.children = [corner("TrackCorner", 0, 27), scroll_thumb]

    tabs = frame(
        "Tabs",
        position=udim2(0, 92, 0, 165),
        size=udim2(0, 724, 0, 80),
        zindex=507,
    )
    tabs.children = [
        supply_tab("RodsTab", "Rods", 0, "FishingRodIcon", True),
        supply_tab("BaitTab", "Bait", 369, "BaitIcon", False),
    ]

    root = frame(
        "ModernSupplyShop",
        position=udim2(0.5, 0, 0.43, 0),
        size=udim2(0, 1448, 0, 1086),
        anchor=vec2(0.5, 0.5),
        visible=False,
        zindex=500,
    )
    root.children = [
        Node("UIScale", "ResponsiveScale", {"Scale": scalar("float", 1)}),
        supply_holder("Frame", "MainBackbone", "MainBackbone", 0, 0, 1448, 1086, 500),
        supply_holder("Frame", "SubMainBackbone", "SubMainBackbone", 35, 146, 1378, 884, 501),
        supply_holder("Frame", "ShopIcon", "ShopIcon", 52, 27, 178, 123, 505),
        text_label("Title", "SUPPLY SHOP", udim2(0, 250, 0, 36), udim2(0, 760, 0, 108), 78, color(255, 255, 255), 506),
        supply_holder("ImageButton", "CloseButton", "CloseButton", 1282, 36, 104, 104, 520),
        tabs,
        supply_list,
        scroll_track,
        frame(
            "ListRightEdgeMask",
            position=udim2(0, 1317, 0, 248),
            size=udim2(0, 7, 0, 780),
            background=color(1, 18, 54),
            transparency=0,
            zindex=508,
        ),
    ]
    return root


def add_property(parent: ET.Element, name: str, declaration: tuple[str, Any]) -> None:
    kind, value = declaration
    element = ET.SubElement(parent, kind, {"name": name})
    if kind in {"string", "float", "int", "token", "bool"}:
        element.text = str(value).lower() if kind == "bool" else str(value)
    elif kind == "UDim":
        scale_value, offset = value
        ET.SubElement(element, "S").text = str(scale_value)
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
    elif kind == "Rect2D":
        min_x, min_y, max_x, max_y = value
        minimum = ET.SubElement(element, "min")
        ET.SubElement(minimum, "X").text = str(min_x)
        ET.SubElement(minimum, "Y").text = str(min_y)
        maximum = ET.SubElement(element, "max")
        ET.SubElement(maximum, "X").text = str(max_x)
        ET.SubElement(maximum, "Y").text = str(max_y)
    elif kind == "ColorSequence":
        sequence = []
        for time, r, g, b in value:
            sequence.extend((time, r / 255, g / 255, b / 255, 0))
        element.text = " ".join(str(part) for part in sequence)
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


def write_model(path: Path, node: Node) -> None:
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
    path.write_text(ET.tostring(document, encoding="unicode") + "\n", encoding="utf-8")


def main() -> None:
    write_model(OUTPUT / "ModernSeasideShop.rbxmx", make_seaside())
    write_model(OUTPUT / "ModernSupplyShop.rbxmx", make_supply())


if __name__ == "__main__":
    main()

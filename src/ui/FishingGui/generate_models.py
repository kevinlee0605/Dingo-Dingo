"""Generate the authored FishingGui surface models.

The files emitted next to this script are deliberately script-free.  They are
the persistent, responsive visual shells that the Fishing UI controllers bind
to.  Run this file after changing the declarations below. ModernFishdex is the
one exception: its exact v1615/v22 hierarchy is maintained by
``tools/generate_fishdex_v22_model.mjs``. BiomeWarpOverlay is maintained by
``tools/generate_island_warp_v1615_model.mjs``. ModernQuestUI is maintained by
``tools/generate_quest_v1615_model.mjs``. SettingsOverlay uses the targeted
``make_settings_overlay`` declaration; FishmongerSellOverlay and RodShopOverlay
use ``generate_popup_models.py``; MainPanel uses
``generate_main_shop_model.py``. These exact skins are intentionally not
overwritten by the generic shell generator loop below.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
import xml.etree.ElementTree as ET


HERE = Path(__file__).resolve().parent
TOP_HUD_HERE = HERE.parent / "TopHudGui"
SCALE_TYPE_STRETCH = 0
SCALE_TYPE_FIT = 3
# StarterGui and PlayerGui now use CoreUISafeInsets consistently. Saving a
# second, hard-coded top inset made the Editor-only preview sit 58 pixels below
# the exact v1636 runtime layout and caused the star/coin collision reported in
# Studio. Keep authored and cloned geometry identical.
EDITOR_PREVIEW_CORE_TOP_INSET = 0
MODEL_FILES = (
    "Root",
    "HUD",
    "FishingXPText",
    "CoinsHud",
    "SeaStarsHud",
    "TopButtonsFrame",
    "BottomButtonsFrame",
    "SettingsOverlay",
    "BiomeWarpOverlay",
    "FishmongerSellOverlay",
    "RodShopOverlay",
    "MainPanel",
    "ModernFishdex",
    "ModernBagRoot",
    "ModernQuestUI",
    "ModernCastPowerUI",
    "CustomFishingMinigame",
    "Templates",
)


@dataclass
class Node:
    class_name: str
    name: str
    props: dict[str, tuple[str, Any]] = field(default_factory=dict)
    children: list["Node"] = field(default_factory=list)


def udim(scale: float = 0, offset: int = 0) -> tuple[str, tuple[float, int]]:
    return ("UDim", (scale, offset))


def udim2(xs: float, xo: int, ys: float, yo: int) -> tuple[str, tuple[float, int, float, int]]:
    return ("UDim2", (xs, xo, ys, yo))


def vec2(x: float, y: float) -> tuple[str, tuple[float, float]]:
    return ("Vector2", (x, y))


def color(r: int, g: int, b: int) -> tuple[str, tuple[float, float, float]]:
    return ("Color3", (r / 255, g / 255, b / 255))


def prop(kind: str, value: Any) -> tuple[str, Any]:
    return (kind, value)


def gui_props(
    *,
    position: tuple[str, Any] = udim2(0, 0, 0, 0),
    size: tuple[str, Any] = udim2(1, 0, 1, 0),
    anchor: tuple[str, Any] = vec2(0, 0),
    background: tuple[str, Any] = color(8, 28, 61),
    transparency: float = 1,
    visible: bool = True,
    zindex: int = 1,
    layout_order: int = 0,
    clips: bool = False,
) -> dict[str, tuple[str, Any]]:
    return {
        "AnchorPoint": anchor,
        "Position": position,
        "Size": size,
        "BackgroundColor3": background,
        "BackgroundTransparency": prop("float", transparency),
        "BorderSizePixel": prop("int", 0),
        "Visible": prop("bool", visible),
        "ZIndex": prop("int", zindex),
        "LayoutOrder": prop("int", layout_order),
        "ClipsDescendants": prop("bool", clips),
    }


def frame(name: str, **kwargs: Any) -> Node:
    return Node("Frame", name, gui_props(**kwargs))


def scrolling(name: str, **kwargs: Any) -> Node:
    kwargs.setdefault("clips", True)
    props = gui_props(**kwargs)
    props.update(
        {
            "AutomaticCanvasSize": prop("token", 2),
            "CanvasSize": udim2(0, 0, 0, 0),
            "ScrollBarImageColor3": color(25, 166, 255),
            "ScrollBarThickness": prop("int", 7),
            "ScrollingDirection": prop("token", 2),
        }
    )
    return Node("ScrollingFrame", name, props)


def label(
    name: str,
    text: str,
    *,
    text_size: int = 22,
    text_color: tuple[int, int, int] = (255, 255, 255),
    align: int = 0,
    **kwargs: Any,
) -> Node:
    props = gui_props(**kwargs)
    props.update(
        {
            "Text": prop("string", text),
            "TextColor3": color(*text_color),
            "TextScaled": prop("bool", True),
            "TextSize": prop("float", text_size),
            "TextStrokeColor3": color(3, 18, 44),
            "TextStrokeTransparency": prop("float", 0.15),
            "TextTransparency": prop("float", 0),
            "TextWrapped": prop("bool", True),
            "TextXAlignment": prop("token", align),
            "TextYAlignment": prop("token", 1),
            "RichText": prop("bool", False),
        }
    )
    node = Node("TextLabel", name, props)
    node.children.append(text_constraint(11, text_size))
    return node


def button(name: str, text: str, *, layout_order: int = 0, **kwargs: Any) -> Node:
    props = gui_props(layout_order=layout_order, **kwargs)
    props.update(
        {
            "Text": prop("string", text),
            "TextColor3": color(255, 255, 255),
            "TextScaled": prop("bool", True),
            "TextSize": prop("float", 20),
            "TextStrokeColor3": color(3, 18, 44),
            "TextStrokeTransparency": prop("float", 0.25),
            "TextWrapped": prop("bool", True),
            "AutoButtonColor": prop("bool", True),
        }
    )
    node = Node("TextButton", name, props)
    node.children.extend([corner(0, 12), stroke(27, 139, 255, 2, 0.15), text_constraint(11, 22)])
    return node


def image(
    name: str,
    *,
    image_id: str = "",
    scale_type: int,
    **kwargs: Any,
) -> Node:
    props = gui_props(**kwargs)
    props.update(
        {
            "Image": prop("Content", image_id),
            "ScaleType": prop("token", scale_type),
        }
    )
    return Node("ImageLabel", name, props)


def corner(scale: float = 0, offset: int = 10, name: str = "UICorner") -> Node:
    return Node("UICorner", name, {"CornerRadius": udim(scale, offset)})


def stroke(r: int, g: int, b: int, thickness: float, transparency: float, name: str = "UIStroke") -> Node:
    return Node(
        "UIStroke",
        name,
        {
            "Color": color(r, g, b),
            "Thickness": prop("float", thickness),
            "Transparency": prop("float", transparency),
        },
    )


def scale(name: str = "ResponsiveScale", value: float = 1) -> Node:
    return Node("UIScale", name, {"Scale": prop("float", value)})


def size_constraint(min_x: int, min_y: int, max_x: int, max_y: int, name: str = "UISizeConstraint") -> Node:
    return Node("UISizeConstraint", name, {"MinSize": vec2(min_x, min_y), "MaxSize": vec2(max_x, max_y)})


def text_constraint(minimum: int, maximum: int) -> Node:
    return Node(
        "UITextSizeConstraint",
        "UITextSizeConstraint",
        {"MinTextSize": prop("int", minimum), "MaxTextSize": prop("int", maximum)},
    )


def hidden_compatibility_label(name: str) -> Node:
    """Author a zero-size reference required by legacy controller contracts."""
    return Node(
        "TextLabel",
        name,
        {
            "BackgroundTransparency": prop("float", 1),
            "BorderSizePixel": prop("int", 0),
            "Position": udim2(0, 0, 0, 0),
            "Size": udim2(0, 0, 0, 0),
            "Text": prop("string", ""),
            "TextTransparency": prop("float", 1),
            "Visible": prop("bool", False),
        },
    )


def hidden_compatibility_frame(name: str) -> Node:
    """Author a zero-size frame required by legacy controller contracts."""
    return Node(
        "Frame",
        name,
        {
            "BackgroundTransparency": prop("float", 1),
            "BorderSizePixel": prop("int", 0),
            "Position": udim2(0, 0, 0, 0),
            "Size": udim2(0, 0, 0, 0),
            "Visible": prop("bool", False),
        },
    )


def padding(left: int, right: int, top: int, bottom: int, name: str = "UIPadding") -> Node:
    return Node(
        "UIPadding",
        name,
        {
            "PaddingLeft": udim(0, left),
            "PaddingRight": udim(0, right),
            "PaddingTop": udim(0, top),
            "PaddingBottom": udim(0, bottom),
        },
    )


def list_layout(
    *,
    horizontal: bool,
    gap: int,
    horizontal_alignment: int = 1,
    vertical_alignment: int = 1,
    name: str = "UIListLayout",
) -> Node:
    return Node(
        "UIListLayout",
        name,
        {
            "FillDirection": prop("token", 0 if horizontal else 1),
            "HorizontalAlignment": prop("token", horizontal_alignment),
            "VerticalAlignment": prop("token", vertical_alignment),
            "Padding": udim(0, gap),
            "SortOrder": prop("token", 2),
        },
    )


def panel_chrome(panel: Node, *, radius: int = 18) -> Node:
    panel.children.extend([corner(0, radius), stroke(20, 128, 255, 3, 0.08)])
    return panel


def make_icon_button(name: str, image_id: str, order: int) -> Node:
    """Author the exact icon-only button shell used by TopButtonsHud.

    The pre-migration controller built these instances at runtime.  Keeping the
    same descendants in StarterGui preserves the original art, circular shadow,
    and press-scale targets while letting the controller bind behavior only.
    """
    node = Node(
        "TextButton",
        name,
        {
            **gui_props(
                size=udim2(0, 80, 0, 80),
                background=color(255, 255, 255),
                transparency=1,
                zindex=10001,
                layout_order=order,
            ),
            "AutoButtonColor": prop("bool", True),
            "Text": prop("string", ""),
            "TextTransparency": prop("float", 1),
        },
    )
    shadow = frame(
        "IconShadow",
        position=udim2(0.5, 0, 0.5, 0),
        size=udim2(0.82, 0, 0.82, 0),
        anchor=vec2(0.5, 0.5),
        background=color(0, 0, 0),
        transparency=0.55,
        zindex=10002,
    )
    shadow.children.append(corner(1, 0))
    node.children.extend(
        [
            scale("PressScale"),
            shadow,
            image(
                "Icon",
                image_id=image_id,
                scale_type=SCALE_TYPE_FIT,
                position=udim2(0.5, 0, 0.5, 0),
                size=udim2(0.82, 0, 0.82, 0),
                anchor=vec2(0.5, 0.5),
                background=color(163, 162, 165),
                transparency=1,
                zindex=10002,
            ),
        ]
    )
    return node


def outlined_label(
    name: str,
    text: str,
    *,
    position: tuple[str, Any],
    size: tuple[str, Any],
    text_color: tuple[int, int, int],
    stroke_color: tuple[int, int, int],
    minimum: int,
    maximum: int,
    zindex: int,
) -> Node:
    node = label(
        name,
        text,
        text_size=maximum,
        text_color=text_color,
        position=position,
        size=size,
        anchor=vec2(0.5, 0.5),
        transparency=1,
        zindex=zindex,
        align=2,
    )
    node.props["Font"] = prop("token", 26)  # Enum.Font.FredokaOne
    node.props["TextStrokeTransparency"] = prop("float", 1)
    node.children = [
        text_constraint(minimum, maximum),
        Node(
            "UIStroke",
            "TextOutline",
            {
                "ApplyStrokeMode": prop("token", 0),
                "Color": color(*stroke_color),
                "LineJoinMode": prop("token", 0),
                "Thickness": prop("float", 2.4),
                "Transparency": prop("float", 0),
            },
        ),
    ]
    return node


def make_bottom_image_button(name: str, *, auto_fish: bool) -> Node:
    # These are the persisted v1636 wrapper bounds. The auto-fish control is a
    # fixed circular hit target while Tap keeps the wider responsive wrapper.
    position = udim2(0.15, 530, 0.5, -125) if auto_fish else udim2(0.65, 0, 0.5, 0)
    button_size = udim2(0, 104, 0, 104) if auto_fish else udim2(0.17, 0, 0, 145)
    node = Node(
        "TextButton",
        name,
        {
            **gui_props(
                position=position,
                size=button_size,
                anchor=vec2(0.5, 0.5),
                background=color(53, 130, 246) if auto_fish else color(255, 255, 255),
                transparency=1,
                zindex=102,
            ),
            "AutoButtonColor": prop("bool", False),
            "Text": prop("string", "AutoFish OFF" if auto_fish else "Tap"),
            "TextTransparency": prop("float", 1),
        },
    )
    button_art = image(
        "ButtonImage",
        image_id="rbxassetid://97792879182918",
        scale_type=SCALE_TYPE_FIT,
        position=udim2(0.5, 0, 0.5, 0),
        size=udim2(1447 / 1267, 0, 1087 / 661, 0),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        zindex=103,
    )
    if not auto_fish:
        button_art.props["ImageTransparency"] = prop("float", 0.2)
    button_art.props["Visible"] = prop("bool", False)

    node.children.extend(
        [
            scale("PressScale"),
            button_art,
            size_constraint(
                220,
                115,
                300,
                157,
                "AutoFishSizeConstraint" if auto_fish else "TapSizeConstraint",
            ),
            Node(
                "UIAspectRatioConstraint",
                "ButtonAspectRatio",
                {
                    "AspectRatio": prop("float", 1267 / 661),
                    "DominantAxis": prop("token", 0),
                },
            ),
        ]
    )

    if auto_fish:
        legacy_title = outlined_label(
            "AutoFishTitleText",
            "AutoFish",
            position=udim2(0.5, 0, 0.35, 0),
            size=udim2(0.84, 0, 0.27, 0),
            text_color=(255, 255, 255),
            stroke_color=(6, 39, 111),
            minimum=18,
            maximum=42,
            zindex=104,
        )
        legacy_title.props["Visible"] = prop("bool", False)
        legacy_title.props["TextSize"] = prop("float", 8)
        legacy_state = outlined_label(
            "AutoFishStateText",
            "OFF",
            position=udim2(0.5, 0, 0.64, 0),
            size=udim2(0.58, 0, 0.32, 0),
            text_color=(255, 70, 70),
            stroke_color=(115, 0, 0),
            minimum=28,
            maximum=58,
            zindex=104,
        )
        legacy_state.props["Visible"] = prop("bool", False)
        legacy_state.props["TextSize"] = prop("float", 8)
        node.children.extend(
            [
                legacy_title,
                legacy_state,
                Node("UIGradient", "StateGradient"),
            ]
        )
    else:
        legacy_tap = outlined_label(
            "TapText",
            "Tap",
            position=udim2(0.5, 0, 0.47, 0),
            size=udim2(0.78, 0, 0.54, 0),
            text_color=(255, 255, 255),
            stroke_color=(6, 39, 111),
            minimum=42,
            maximum=88,
            zindex=104,
        )
        legacy_tap.props["Visible"] = prop("bool", False)
        legacy_tap.props["TextSize"] = prop("float", 8)
        node.children.append(legacy_tap)

    # Version 1615 replaced the original blue image-backed buttons at runtime
    # with these two compact circular visuals.  Author the replacement tree in
    # StarterGui so Studio, Team Create, and every client all see the same UI
    # without depending on a late LocalScript patch.
    if auto_fish:
        modern_visual = frame(
            "ModernAutoFishVisual",
            position=udim2(0.5, 0, 0.5, 0),
            size=udim2(0, 104, 0, 104),
            anchor=vec2(0.5, 0.5),
            transparency=1,
            zindex=152,
        )
        modern_visual.children.extend(
            [
                Node(
                    "UIAspectRatioConstraint",
                    "UIAspectRatioConstraint",
                    {"AspectRatio": prop("float", 1)},
                ),
                scale("PressScale"),
            ]
        )
        circle = frame(
            "Circle",
            position=udim2(0.5, 0, 0.5, 0),
            size=udim2(0.94, 0, 0.94, 0),
            anchor=vec2(0.5, 0.5),
            background=color(226, 65, 72),
            transparency=0.28,
            zindex=152,
        )
        circle.children.extend(
            [
                corner(1, 0),
                Node(
                    "UIStroke",
                    "OuterStroke",
                    {
                        "ApplyStrokeMode": prop("token", 1),
                        "Color": color(255, 104, 108),
                        "LineJoinMode": prop("token", 0),
                        "Thickness": prop("float", 6),
                        "Transparency": prop("float", 0.05),
                    },
                ),
            ]
        )
        inner_ring = frame(
            "InnerRing",
            position=udim2(0.5, 0, 0.5, 0),
            size=udim2(0.84, 0, 0.84, 0),
            anchor=vec2(0.5, 0.5),
            transparency=1,
            zindex=153,
        )
        inner_ring.children.extend(
            [
                corner(1, 0),
                Node(
                    "UIStroke",
                    "InnerStroke",
                    {
                        "ApplyStrokeMode": prop("token", 1),
                        "Color": color(135, 17, 25),
                        "LineJoinMode": prop("token", 0),
                        "Thickness": prop("float", 3),
                        "Transparency": prop("float", 0.05),
                    },
                ),
            ]
        )
        auto_text = label(
            "AutoText",
            "AUTO",
            text_size=8,
            position=udim2(0.5, 0, 0.5, 0),
            size=udim2(0.82, 0, 0.38, 0),
            anchor=vec2(0.5, 0.5),
            transparency=1,
            zindex=155,
            align=2,
        )
        auto_text.props["Font"] = prop("token", 20)  # Enum.Font.GothamBlack
        auto_text.props["TextScaled"] = prop("bool", True)
        auto_text.props["TextStrokeColor3"] = color(20, 20, 20)
        auto_text.props["TextStrokeTransparency"] = prop("float", 0)
        # label() supplies a default constraint. Replace it with the exact
        # v1636 constraint so Studio does not keep two competing limits.
        auto_text.children = [text_constraint(18, 24)]
        circle.children.extend([inner_ring, auto_text])
        modern_visual.children.append(circle)
        node.children.append(modern_visual)
    else:
        code_circle = frame(
            "CodeCircleVisual",
            position=udim2(0.5, 0, 0.5, 0),
            size=udim2(0, 118, 0, 118),
            anchor=vec2(0.5, 0.5),
            background=color(22, 24, 28),
            transparency=0.22,
            zindex=122,
        )
        code_circle.children.extend(
            [
                corner(1, 0),
                Node(
                    "UIStroke",
                    "OuterStroke",
                    {
                        "ApplyStrokeMode": prop("token", 1),
                        "Color": color(178, 188, 202),
                        "Thickness": prop("float", 2.5),
                        "Transparency": prop("float", 0.18),
                    },
                ),
                Node(
                    "UIAspectRatioConstraint",
                    "UIAspectRatioConstraint",
                    {"AspectRatio": prop("float", 1)},
                ),
                scale("PressScale"),
            ]
        )
        translucent_center = frame(
            "TranslucentCenter",
            position=udim2(0, 7, 0, 7),
            size=udim2(1, -14, 1, -14),
            background=color(42, 45, 50),
            transparency=0.80,
            zindex=123,
        )
        translucent_center.children.extend(
            [
                corner(1, 0),
                Node(
                    "UIStroke",
                    "InnerStroke",
                    {
                        "ApplyStrokeMode": prop("token", 1),
                        "Color": color(140, 150, 166),
                        "Thickness": prop("float", 1.5),
                        "Transparency": prop("float", 0.42),
                    },
                ),
            ]
        )
        tap_code_text = label(
            "TapText",
            "TAP",
            text_size=26,
            size=udim2(1, 0, 1, 0),
            transparency=1,
            zindex=124,
            align=2,
        )
        tap_code_text.props["Font"] = prop("token", 18)  # Enum.Font.GothamBold
        tap_code_text.props["TextScaled"] = prop("bool", False)
        tap_code_text.props["TextWrapped"] = prop("bool", False)
        tap_code_text.props["TextStrokeColor3"] = color(0, 0, 0)
        tap_code_text.props["TextStrokeTransparency"] = prop("float", 0.45)
        translucent_center.children.append(tap_code_text)
        code_circle.children.append(translucent_center)
        node.children.append(code_circle)

    return node


def make_rage_overlay_nodes() -> list[Node]:
    """Exact full-screen Rage Mode visuals used by the modern minigame."""
    warning = image(
        "RageModeWarning",
        image_id="rbxassetid://92582541870517",
        scale_type=SCALE_TYPE_FIT,
        position=udim2(0.5, 0, 0.14, 0),
        size=udim2(1, 0, 0.3, 0),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        visible=False,
        zindex=520,
    )
    warning.props["ImageTransparency"] = prop("float", 1)
    warning.children.append(Node("UIScale", "WarningPulseScale", {"Scale": prop("float", 1)}))

    horizontal = frame(
        "RageHorizontalFill",
        position=udim2(0, 0, 0, 0),
        size=udim2(0, 0, 0, 1),
        anchor=vec2(0, 0.5),
        transparency=1,
        visible=False,
        zindex=490,
        clips=False,
    )
    piece_specs = (
        ("LeftCap", (0, 778), (604, 248)),
        ("Middle", (0, 232), (604, 562)),
        ("RightCap", (0, 0), (604, 248)),
    )
    for piece_name, rect_offset, rect_size in piece_specs:
        holder = frame(
            piece_name + "Holder",
            transparency=1,
            visible=False,
            zindex=490,
            clips=True,
        )
        piece = image(
            piece_name,
            image_id="rbxassetid://138976342109765",
            scale_type=SCALE_TYPE_STRETCH,
            position=udim2(0.5, 0, 0.5, 0),
            anchor=vec2(0.5, 0.5),
            transparency=1,
            zindex=491,
        )
        piece.props["ImageRectOffset"] = vec2(*rect_offset)
        piece.props["ImageRectSize"] = vec2(*rect_size)
        piece.props["Rotation"] = prop("float", 90)
        holder.children.append(piece)
        horizontal.children.append(holder)

    return [warning, horizontal]


def make_root() -> Node:
    root = frame(
        "Root",
        position=udim2(0.5, 0, 0.5, 0),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        zindex=1,
    )
    root.children.extend([scale(), size_constraint(320, 240, 3840, 2160, "ViewportConstraint")])
    root.children.extend(make_rage_overlay_nodes())

    hud = frame("HUD", transparency=1, zindex=100)
    root.children.append(hud)

    left = frame(
        "LeftStats",
        position=udim2(0.012, 0, 0.095, 0),
        size=udim2(0.22, 0, 0, 178),
        transparency=1,
        zindex=100,
    )
    left.children.extend(
        [
            size_constraint(190, 132, 320, 214, "StatsSizeConstraint"),
            padding(0, 0, 0, 0),
            list_layout(horizontal=False, gap=5, horizontal_alignment=0, vertical_alignment=0),
        ]
    )
    hud.children.append(left)

    xp = frame(
        "FishingXPText",
        size=udim2(0, 380, 0, 54),
        transparency=1,
        zindex=1000,
        layout_order=1,
    )
    xp_text = label(
        "XPCombinedText",
        "Level: 30 [MAX]",
        text_size=8,
        position=udim2(0, 0, 0, 0),
        size=udim2(1, 0, 1, 0),
        transparency=1,
        zindex=1001,
        align=2,
    )
    # The UTC clock deliberately uses this exact font/color/outline treatment.
    xp_text.props["Font"] = prop("token", 20)  # Enum.Font.GothamBlack
    xp_text.props["TextScaled"] = prop("bool", True)
    xp_text.props["TextStrokeColor3"] = color(0, 0, 0)
    xp_text.props["TextStrokeTransparency"] = prop("float", 0)
    # label() supplies a default constraint. Replace it with the exact v1636
    # constraint; leaving both constraints makes the editor clamp the level
    # indicator to the default eight-pixel text size.
    xp_text.children = [
        stroke(0, 10, 21, 1.6, 0, "XPTextOutline"),
        text_constraint(18, 30),
    ]
    xp.children.append(xp_text)
    xp.children.extend(
        [
            hidden_compatibility_label("LegacyXPProgressText"),
            hidden_compatibility_frame("LegacyXPFill"),
        ]
    )
    left.children.append(xp)

    coins = frame(
        "CoinsHud",
        size=udim2(0, 430, 0, 96),
        transparency=1,
        zindex=1000,
        layout_order=2,
    )
    coins.children.append(
        image(
            "CoinIcon",
            image_id="rbxassetid://99615681502772",
            scale_type=SCALE_TYPE_FIT,
            position=udim2(0, 0, 0, 4),
            size=udim2(0, 75, 0, 75),
            transparency=1,
            zindex=1001,
        )
    )
    number_area = frame(
        "NumberArea",
        position=udim2(0, 80, 0, 10),
        size=udim2(0, 320, 0, 76),
        transparency=1,
        zindex=1001,
    )
    digits_holder = frame(
        "DigitsHolder",
        position=udim2(0, 0, 0.5, 0),
        size=udim2(0, 129, 0, 72),
        anchor=vec2(0, 0.5),
        transparency=1,
        zindex=1002,
    )
    digits_holder.props["Visible"] = prop("bool", True)
    digits_holder.children.append(scale("DigitsScale"))
    preview_slot = frame(
        "PreviewDigitSlot",
        size=udim2(0, 24, 0, 72),
        transparency=1,
        zindex=1003,
        clips=True,
    )
    preview_slot.props["Visible"] = prop("bool", False)
    preview_character = label(
        "PreviewCharacter",
        "0",
        text_size=8,
        size=udim2(1, 0, 1, 0),
        transparency=1,
        zindex=1004,
        align=2,
    )
    preview_character.props["Font"] = prop("token", 20)  # Enum.Font.GothamBlack
    preview_character.props["TextScaled"] = prop("bool", False)
    preview_character.props["TextWrapped"] = prop("bool", False)
    preview_character.props["TextStrokeTransparency"] = prop("float", 1)
    preview_character.children = [
        text_constraint(28, 68),
        Node(
            "UIStroke",
            "NumberOutline",
            {
                "ApplyStrokeMode": prop("token", 0),
                "Color": color(0, 10, 21),
                "LineJoinMode": prop("token", 0),
                "Thickness": prop("float", 3.3),
                "Transparency": prop("float", 0),
            },
        ),
    ]
    preview_slot.children.append(preview_character)
    digits_holder.children.append(preview_slot)

    # A saved preview makes the Explorer/Studio view match Play. The controller
    # hides these named preview slots and replaces them with the same authored
    # slot template when the live balance arrives.
    preview_value = "100,750"
    preview_x = 0
    for index, character in enumerate(preview_value, start=1):
        character_width = 12 if character == "," else 24
        editor_slot = frame(
            f"EditorPreviewDigit{index}",
            position=udim2(0, preview_x, 0, 0),
            size=udim2(0, character_width, 0, 72),
            transparency=1,
            zindex=1003,
            clips=True,
        )
        editor_character = label(
            "Character",
            character,
            text_size=8,
            size=udim2(1, 0, 1, 0),
            transparency=1,
            zindex=1004,
            align=2,
        )
        editor_character.props["Font"] = prop("token", 20)
        editor_character.props["TextScaled"] = prop("bool", False)
        editor_character.props["TextStrokeTransparency"] = prop("float", 1)
        editor_character.children = [
            text_constraint(28, 68),
            Node(
                "UIStroke",
                "NumberOutline",
                {
                    "ApplyStrokeMode": prop("token", 0),
                    "Color": color(0, 10, 21),
                    "LineJoinMode": prop("token", 0),
                    "Thickness": prop("float", 3.3),
                    "Transparency": prop("float", 0),
                },
            ),
        ]
        editor_slot.children.append(editor_character)
        digits_holder.children.append(editor_slot)
        preview_x += character_width

    number_area.children.append(digits_holder)
    coins.children.append(number_area)

    # Retained only for older scripts that still look up CoinsText. The visible
    # number is the v1636 rolling-slot hierarchy above.
    coins_text = label(
        "CoinsText",
        "100,750",
        text_size=30,
        position=udim2(0, 80, 0, 10),
        size=udim2(0, 320, 0, 76),
        transparency=1,
        visible=False,
        zindex=1001,
        align=0,
    )
    coins_text.props["Font"] = prop("token", 20)  # Enum.Font.GothamBlack
    coins_text.props["TextStrokeColor3"] = color(0, 10, 21)
    coins_text.props["TextScaled"] = prop("bool", False)
    coins_text.props["TextTransparency"] = prop("float", 1)
    coins_text.props["TextStrokeTransparency"] = prop("float", 1)
    coins_text.props["TextWrapped"] = prop("bool", False)
    coins_text.children = [
        text_constraint(14, 30),
        Node(
            "UIStroke",
            "NumberOutline",
            {
                "ApplyStrokeMode": prop("token", 0),
                "Color": color(0, 10, 21),
                "LineJoinMode": prop("token", 0),
                "Thickness": prop("float", 3.3),
                "Transparency": prop("float", 0),
            },
        ),
    ]
    coins.children.append(coins_text)
    coins.children.extend(
        [
            hidden_compatibility_label("LegacyStatsText"),
            hidden_compatibility_label("LegacyStatusText"),
        ]
    )
    left.children.append(coins)

    stars = frame(
        "SeaStarsHud",
        size=udim2(0, 330, 0, 96),
        transparency=1,
        zindex=5000,
        layout_order=3,
    )
    compatibility_star_icon = label(
        "SeaStarIcon",
        "★",
        text_size=48,
        text_color=(255, 219, 62),
        position=udim2(0, 8, 0, -2),
        size=udim2(0, 70, 1, 4),
        transparency=1,
        zindex=1001,
        align=2,
    )
    compatibility_star_icon.props["Font"] = prop("token", 18)
    compatibility_star_icon.props["TextScaled"] = prop("bool", False)
    compatibility_star_icon.props["TextStrokeColor3"] = color(4, 35, 74)
    compatibility_star_icon.props["TextTransparency"] = prop("float", 1)
    compatibility_star_icon.props["TextStrokeTransparency"] = prop("float", 1)
    compatibility_star_icon.props["TextWrapped"] = prop("bool", False)
    compatibility_star_icon.children = []
    stars.children.append(compatibility_star_icon)

    sea_stars_text = label(
        "SeaStarsText",
        "0",
        text_size=30,
        position=udim2(0, 76, 0, 1),
        size=udim2(1, -78, 0.62, 0),
        transparency=1,
        zindex=1001,
        align=0,
    )
    sea_stars_text.props["Font"] = prop("token", 20)  # Enum.Font.GothamBlack
    sea_stars_text.props["TextScaled"] = prop("bool", True)
    sea_stars_text.props["TextStrokeColor3"] = color(3, 22, 53)
    sea_stars_text.props["TextTransparency"] = prop("float", 1)
    sea_stars_text.props["TextStrokeTransparency"] = prop("float", 1)
    sea_stars_text.props["TextWrapped"] = prop("bool", True)
    sea_stars_text.children = [text_constraint(14, 30)]
    stars.children.append(sea_stars_text)

    coin_style = frame(
        "SeaStarCoinStyleVisual",
        size=udim2(1, 0, 1, 0),
        transparency=1,
        zindex=5001,
    )
    coin_style.children.append(
        image(
            "SeaStarIcon",
            image_id="rbxassetid://102284604663190",
            scale_type=SCALE_TYPE_FIT,
            position=udim2(0, 0, 0, 4),
            size=udim2(0, 75, 0, 75),
            transparency=1,
            zindex=5002,
        )
    )
    star_number_area = frame(
        "NumberArea",
        position=udim2(0, 80, 0, 10),
        size=udim2(0, 240, 0, 76),
        transparency=1,
        zindex=5002,
    )
    star_digits_holder = frame(
        "DigitsHolder",
        position=udim2(0, 0, 0.5, 0),
        size=udim2(0, 24, 0, 72),
        anchor=vec2(0, 0.5),
        transparency=1,
        zindex=5003,
    )
    star_digits_holder.children.append(scale("DigitsScale"))
    star_preview_slot = frame(
        "PreviewDigitSlot",
        size=udim2(0, 24, 0, 72),
        transparency=1,
        zindex=5003,
        clips=True,
    )
    star_preview_slot.props["Visible"] = prop("bool", False)
    star_preview_character = label(
        "PreviewCharacter",
        "0",
        text_size=8,
        size=udim2(1, 0, 1, 0),
        transparency=1,
        zindex=5004,
        align=2,
    )
    star_preview_character.props["Font"] = prop("token", 20)
    star_preview_character.props["TextScaled"] = prop("bool", False)
    star_preview_character.props["TextWrapped"] = prop("bool", False)
    star_preview_character.props["TextStrokeTransparency"] = prop("float", 1)
    star_preview_character.children = [
        text_constraint(28, 68),
        Node(
            "UIStroke",
            "NumberOutline",
            {
                "ApplyStrokeMode": prop("token", 0),
                "Color": color(0, 10, 21),
                "LineJoinMode": prop("token", 0),
                "Thickness": prop("float", 3.3),
                "Transparency": prop("float", 0),
            },
        ),
    ]
    star_preview_slot.children.append(star_preview_character)
    star_digits_holder.children.append(star_preview_slot)

    star_editor_slot = frame(
        "EditorPreviewDigit1",
        size=udim2(0, 20, 0, 72),
        transparency=1,
        zindex=5003,
        clips=True,
    )
    star_editor_character = label(
        "Character",
        "0",
        text_size=8,
        size=udim2(1, 0, 1, 0),
        transparency=1,
        zindex=5004,
        align=2,
    )
    star_editor_character.props["Font"] = prop("token", 20)
    star_editor_character.props["TextScaled"] = prop("bool", False)
    star_editor_character.props["TextWrapped"] = prop("bool", False)
    star_editor_character.props["TextStrokeTransparency"] = prop("float", 1)
    star_editor_character.children = [
        text_constraint(28, 68),
        Node(
            "UIStroke",
            "NumberOutline",
            {
                "ApplyStrokeMode": prop("token", 0),
                "Color": color(0, 10, 21),
                "LineJoinMode": prop("token", 0),
                "Thickness": prop("float", 3.3),
                "Transparency": prop("float", 0),
            },
        ),
    ]
    star_editor_slot.children.append(star_editor_character)
    star_digits_holder.children.append(star_editor_slot)
    star_number_area.children.append(star_digits_holder)
    coin_style.children.append(star_number_area)
    stars.children.append(coin_style)
    left.children.append(stars)

    top = frame(
        "TopButtonsFrame",
        position=udim2(0.5, 0, 0, 0),
        size=udim2(0, 298, 0, 64),
        anchor=vec2(0.5, 0),
        background=color(163, 162, 165),
        transparency=1,
        zindex=10000,
    )
    top.children.extend(
        [
            scale("TopHudScale", 0.86),
            size_constraint(298, 64, 298, 64, "TopButtonsSizeConstraint"),
            list_layout(horizontal=True, gap=14, horizontal_alignment=0),
            make_icon_button("SettingsButton", "rbxassetid://124685242228377", 1),
            make_icon_button("QuestsButton", "rbxassetid://102051949478203", 2),
            make_icon_button("ShopButton", "rbxassetid://140502313228532", 3),
            make_icon_button("TopLoginRewardButton", "rbxassetid://78408484505332", 4),
        ]
    )
    hud.children.append(top)

    bottom = frame(
        "BottomButtonsFrame",
        position=udim2(0.6, 0, 0.68, 0),
        size=udim2(1, 0, 0.28, 0),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        visible=False,
        zindex=100,
    )
    bottom.children.extend(
        [
            scale("BottomHudScale", 0.86),
            make_bottom_image_button("AutoFishButton", auto_fish=True),
            make_bottom_image_button("TapButton", auto_fish=False),
            label(
                "CenterTitle",
                "Lilyshore Island",
                text_size=16,
                position=udim2(0.55, 0, 0.1, 0),
                size=udim2(0.28, 0, 0, 22),
                anchor=vec2(0.5, 0.5),
                transparency=1,
                visible=False,
                zindex=101,
                align=2,
            ),
            label(
                "CenterBaitText",
                "Bait: Basic Bait (Unlimited)",
                text_size=13,
                position=udim2(0.55, 0, 0.1, 0),
                size=udim2(0.34, 0, 0, 20),
                anchor=vec2(0.5, 0.5),
                transparency=1,
                visible=False,
                zindex=101,
                align=2,
            ),
        ]
    )
    hud.children.append(bottom)
    return root


def make_modal(name: str, title: str, *, panel_size: tuple[float, int, float, int] = (0.66, 0, 0.72, 0)) -> Node:
    overlay = frame(
        name,
        background=color(0, 6, 18),
        transparency=0.32,
        visible=False,
        zindex=200,
    )
    dialog = panel_chrome(
        frame(
            "Panel",
            position=udim2(0.5, 0, 0.5, 0),
            size=udim2(*panel_size),
            anchor=vec2(0.5, 0.5),
            background=color(5, 35, 77),
            transparency=0.03,
            zindex=201,
            clips=True,
        )
    )
    dialog.children.extend(
        [
            scale("PanelScale"),
            size_constraint(300, 220, 1240, 900, "PanelSizeConstraint"),
            frame(
                "Header",
                size=udim2(1, 0, 0.13, 0),
                background=color(7, 67, 129),
                transparency=0.02,
                zindex=202,
            ),
            scrolling(
                "Content",
                position=udim2(0.035, 0, 0.16, 0),
                size=udim2(0.93, 0, 0.79, 0),
                background=color(3, 25, 58),
                transparency=0.24,
                zindex=202,
                clips=True,
            ),
        ]
    )
    header = next(child for child in dialog.children if child.name == "Header")
    header.children.extend(
        [
            label(
                "Title",
                title,
                text_size=34,
                position=udim2(0.04, 0, 0, 0),
                size=udim2(0.78, 0, 1, 0),
                transparency=1,
                zindex=203,
                align=0,
            ),
            button(
                "CloseButton",
                "X",
                position=udim2(0.97, 0, 0.5, 0),
                size=udim2(0, 46, 0, 46),
                anchor=vec2(1, 0.5),
                background=color(239, 151, 17),
                transparency=0,
                zindex=204,
            ),
        ]
    )
    content = next(child for child in dialog.children if child.name == "Content")
    content.children.extend(
        [
            padding(12, 12, 12, 12),
            list_layout(horizontal=False, gap=10, horizontal_alignment=1, vertical_alignment=0),
            label(
                "EmptyState",
                "",
                text_size=20,
                size=udim2(1, 0, 0, 44),
                transparency=1,
                visible=False,
                zindex=203,
                align=2,
            ),
        ]
    )
    overlay.children.append(dialog)
    return overlay


def make_special_modal(name: str, title: str) -> Node:
    root = make_modal(name, title)
    panel = root.children[0]
    content = next(child for child in panel.children if child.name == "Content")
    if name == "SettingsOverlay":
        content.children.extend(
            [
                frame("AudioSettings", size=udim2(1, 0, 0, 72), transparency=1, layout_order=1, zindex=203),
                frame("ControlSettings", size=udim2(1, 0, 0, 72), transparency=1, layout_order=2, zindex=203),
            ]
        )
    elif name == "FishmongerSellOverlay":
        content.children.append(
            button(
                "SellAllButton",
                "Sell All Fish",
                layout_order=100,
                size=udim2(0.72, 0, 0, 58),
                background=color(16, 151, 104),
                transparency=0,
                zindex=204,
            )
        )
    elif name == "RodShopOverlay":
        content.children.append(scrolling("RodList", size=udim2(1, 0, 1, 0), transparency=1, zindex=203))
    elif name == "BiomeWarpOverlay":
        content.children.append(scrolling("BiomeList", size=udim2(1, 0, 1, 0), transparency=1, zindex=203))
    return root


def make_settings_overlay() -> Node:
    """Author the exact asset-skinned Settings window used by SettingsPanelHud.

    The legacy controller painted this entire 1448x1086 hierarchy at runtime.
    Keeping every fixed clip, row, label, button, toggle, and slider piece in
    StarterGui preserves that appearance while the controller only binds state
    and input behavior.
    """

    assets = {
        "Backbone": "rbxassetid://81766141914014",
        "CloseButton": "rbxassetid://74437026548245",
        "SettingsIcon": "rbxassetid://94678436497650",
        "RowBackground": "rbxassetid://130386889052542",
        "MusicIcon": "rbxassetid://70574718515061",
        "SfxIcon": "rbxassetid://92653426073517",
        "FishBowl": "rbxassetid://81878984079270",
        "TeleportButton": "rbxassetid://107462888144853",
        "ToggleOff": "rbxassetid://131550730293382",
        "ToggleOn": "rbxassetid://110978225407848",
        "SliderTrack": "rbxassetid://79604035889224",
        "SliderFill": "rbxassetid://107077598572207",
        "SliderKnob": "rbxassetid://75219052415065",
    }

    def settings_image(
        name: str,
        asset: str,
        position: tuple[str, Any],
        size: tuple[str, Any],
        zindex: int,
        *,
        button_node: bool = False,
        stretch: bool = False,
        image_transparency: float = 0,
    ) -> Node:
        props = {
            **gui_props(
                position=position,
                size=size,
                transparency=1,
                zindex=zindex,
            ),
            "Image": prop("Content", asset),
            "ImageColor3": color(255, 255, 255),
            "ImageTransparency": prop("float", image_transparency),
            "ScaleType": prop("token", 0 if stretch else 3),
        }
        if button_node:
            props["AutoButtonColor"] = prop("bool", False)
        return Node("ImageButton" if button_node else "ImageLabel", name, props)

    def settings_label(
        name: str,
        text: str,
        position: tuple[str, Any],
        size: tuple[str, Any],
        text_size: int,
        text_color: tuple[int, int, int],
        align: int,
        zindex: int,
    ) -> Node:
        return Node(
            "TextLabel",
            name,
            {
                **gui_props(
                    position=position,
                    size=size,
                    transparency=1,
                    zindex=zindex,
                ),
                "Font": prop("token", 26),  # Enum.Font.FredokaOne
                "Text": prop("string", text),
                "TextColor3": color(*text_color),
                "TextScaled": prop("bool", False),
                "TextSize": prop("float", text_size),
                "TextStrokeColor3": color(0, 0, 0),
                "TextStrokeTransparency": prop("float", 0.25),
                "TextTransparency": prop("float", 0),
                "TextTruncate": prop("token", 0),
                "TextWrapped": prop("bool", False),
                "TextXAlignment": prop("token", align),
                "TextYAlignment": prop("token", 1),
            },
        )

    def mapped_piece(
        name: str,
        asset: str,
        clip_position: tuple[str, Any],
        clip_size: tuple[str, Any],
        source_size: tuple[float, float],
        region: tuple[float, float, float, float],
        zindex: int,
    ) -> Node:
        _, (width_scale, clip_width, height_scale, clip_height) = clip_size
        if width_scale != 0 or height_scale != 0:
            raise ValueError("Settings mapped pieces must use offset sizes")
        source_width, source_height = source_size
        source_x, source_y, region_width, region_height = region
        full_width = round(clip_width * source_width / region_width)
        full_height = round(clip_height * source_height / region_height)
        image_x = round(-(source_x / source_width) * full_width)
        image_y = round(-(source_y / source_height) * full_height)
        # Preserve the exact integer crop geometry captured from v1636. These
        # four pieces sit on fractional source boundaries where round-to-even
        # otherwise moves the authored image by one pixel in Studio.
        exact_crop_geometry = {
            "TrackLeftCap": (image_x, -134, full_width, 318),
            "TrackMiddle": (-137, -134, full_width, 318),
            "TrackRightCap": (image_x, -134, full_width, 318),
        }
        image_x, image_y, full_width, full_height = exact_crop_geometry.get(
            name,
            (image_x, image_y, full_width, full_height),
        )
        clip = frame(
            name,
            position=clip_position,
            size=clip_size,
            transparency=1,
            zindex=zindex,
            clips=True,
        )
        clip.children.append(
            settings_image(
                "Image",
                asset,
                udim2(0, image_x, 0, image_y),
                udim2(0, full_width, 0, full_height),
                zindex,
                stretch=True,
            )
        )
        return clip

    overlay = frame(
        "SettingsOverlay",
        background=color(0, 0, 0),
        transparency=1,
        visible=False,
        zindex=200,
    )
    overlay.props["Active"] = prop("bool", True)

    canvas = frame(
        "SettingsCanvas",
        position=udim2(0.5, 0, 0.5, -60),
        size=udim2(0, 1448, 0, 1086),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        zindex=201,
    )
    canvas.children.append(scale("UIScale", 0.34))

    for name, target_y, target_height, source_y, source_height in (
        ("BackboneTop", 0, 160, 0, 160),
        ("BackboneMiddle", 160, 766, 160, 766),
        ("BackboneBottom", 926, 160, 926, 160),
    ):
        full_height = round(target_height * 1086 / source_height)
        image_y = round(-(source_y / 1086) * full_height)
        clip = frame(
            name,
            position=udim2(0, 0, 0, target_y),
            size=udim2(0, 1448, 0, target_height),
            transparency=1,
            zindex=201,
            clips=True,
        )
        clip.children.append(
            settings_image(
                "Image",
                assets["Backbone"],
                udim2(0, 0, 0, image_y),
                udim2(0, 1448, 0, full_height),
                201,
                stretch=True,
            )
        )
        canvas.children.append(clip)

    canvas.children.extend(
        [
            settings_image(
                "SettingsIcon",
                assets["SettingsIcon"],
                udim2(0, 72, 0, 56),
                udim2(0, 120, 0, 120),
                204,
            ),
            settings_label(
                "Title",
                "Settings",
                udim2(0, 205, 0, 48),
                udim2(0, 510, 0, 120),
                72,
                (255, 255, 255),
                0,
                205,
            ),
            settings_image(
                "CloseButton",
                assets["CloseButton"],
                udim2(0, 1270, 0, 60),
                udim2(0, 100, 0, 100),
                210,
                button_node=True,
            ),
        ]
    )

    def audio_row(name: str, y: int, icon_asset: str, prefix: str) -> Node:
        row = settings_image(
            f"{name}Row",
            assets["RowBackground"],
            udim2(0, 86, 0, y),
            udim2(0, 1278, 0, 226),
            203,
            stretch=True,
        )
        toggle = Node(
            "TextButton",
            f"{name}Toggle",
            {
                **gui_props(
                    position=udim2(0, 955, 0, 64),
                    size=udim2(0, 230, 0, 96),
                    transparency=1,
                    zindex=207,
                    clips=True,
                ),
                "AutoButtonColor": prop("bool", False),
                "Text": prop("string", ""),
            },
        )
        knob = frame(
            f"{name}Knob",
            position=udim2(1, -78, 0.5, -39),
            size=udim2(0, 78, 0, 78),
            transparency=1,
            zindex=210,
            clips=True,
        )
        knob.children.append(
            settings_image(
                "Image",
                assets["SliderKnob"],
                udim2(0, -44, 0, -41),
                udim2(0, 165, 0, 164),
                211,
                stretch=True,
            )
        )
        toggle.children.extend(
            [
                scale("PressScale"),
                settings_image(
                    "OnBackground",
                    assets["ToggleOn"],
                    udim2(0, -83, 0, -82),
                    udim2(0, 396, 0, 264),
                    207,
                    stretch=True,
                ),
                settings_image(
                    "OffBackground",
                    assets["ToggleOff"],
                    udim2(0, -39, 0, -55),
                    udim2(0, 307, 0, 213),
                    207,
                    stretch=True,
                    image_transparency=1,
                ),
                settings_label(
                    f"{name}ToggleText",
                    "ON",
                    udim2(0, 22, 0, 0),
                    udim2(0, 108, 0, 96),
                    38,
                    (255, 255, 255),
                    0,
                    209,
                ),
                knob,
            ]
        )
        row.children.extend(
            [
                settings_image(
                    f"{name}Icon",
                    icon_asset,
                    udim2(0, 60, 0, 30),
                    udim2(0, 160, 0, 160),
                    205,
                ),
                settings_label(
                    f"{name}Prefix",
                    f"{prefix}:",
                    udim2(0, 460, 0, 55),
                    udim2(0, 230, 0, 110),
                    52,
                    (255, 255, 255),
                    1,
                    206,
                ),
                settings_label(
                    f"{name}Status",
                    "ON",
                    udim2(0, 700, 0, 55),
                    udim2(0, 180, 0, 110),
                    52,
                    (65, 215, 255),
                    0,
                    206,
                ),
                toggle,
            ]
        )
        return row

    canvas.children.extend(
        [
            audio_row("Music", 160, assets["MusicIcon"], "Music"),
            audio_row("Sfx", 360, assets["SfxIcon"], "SFX"),
        ]
    )

    speed_row = settings_image(
        "MoveSpeedRow",
        assets["RowBackground"],
        udim2(0, 86, 0, 560),
        udim2(0, 1278, 0, 226),
        203,
        stretch=True,
    )
    speed_row.children.extend(
        [
            settings_label(
                "MoveSpeedPrefix",
                "Move Speed:",
                udim2(0, 400, 0, 35),
                udim2(0, 360, 0, 80),
                46,
                (255, 255, 255),
                1,
                206,
            ),
            settings_label(
                "MoveSpeedValue",
                "16",
                udim2(0, 770, 0, 35),
                udim2(0, 120, 0, 80),
                46,
                (65, 215, 255),
                0,
                206,
            ),
        ]
    )

    slider = frame(
        "SliderArea",
        position=udim2(0, 95, 0, 108),
        size=udim2(0, 1088, 0, 82),
        transparency=1,
        zindex=205,
    )
    slider.props["Active"] = prop("bool", True)
    slider.children.extend(
        [
            mapped_piece(
                "TrackLeftCap",
                assets["SliderTrack"],
                udim2(0, 0, 0, 22),
                udim2(0, 19, 0, 38),
                (1536, 1024),
                (103, 432, 61, 122),
                206,
            ),
            mapped_piece(
                "TrackMiddle",
                assets["SliderTrack"],
                udim2(0, 19, 0, 22),
                udim2(0, 1050, 0, 38),
                (1536, 1024),
                (164, 432, 1252, 122),
                206,
            ),
            mapped_piece(
                "TrackRightCap",
                assets["SliderTrack"],
                udim2(0, 1069, 0, 22),
                udim2(0, 19, 0, 38),
                (1536, 1024),
                (1416, 432, 61, 122),
                206,
            ),
            mapped_piece(
                "FillLeftCap",
                assets["SliderFill"],
                udim2(0, 4, 0, 26),
                udim2(0, 15, 0, 30),
                (1274, 155),
                (10, 10, 68, 135),
                207,
            ),
        ]
    )

    fill_middle_width = 525
    fill_full_width = round(fill_middle_width * 1274 / 1118)
    fill_full_height = round(30 * 155 / 135)
    fill_middle = frame(
        "FillMiddle",
        position=udim2(0, 19, 0, 26),
        size=udim2(0, fill_middle_width, 0, 30),
        transparency=1,
        zindex=207,
        clips=True,
    )
    fill_middle.children.append(
        settings_image(
            "Image",
            assets["SliderFill"],
            udim2(
                0,
                -36,
                0,
                round(-(10 / 155) * fill_full_height),
            ),
            udim2(0, fill_full_width, 0, fill_full_height),
            207,
            stretch=True,
        )
    )

    slider_knob = Node(
        "TextButton",
        "SliderKnob",
        {
            **gui_props(
                position=udim2(0, 506, 0, 3),
                size=udim2(0, 76, 0, 76),
                transparency=1,
                zindex=209,
                clips=True,
            ),
            "AutoButtonColor": prop("bool", False),
            "Text": prop("string", ""),
        },
    )
    slider_knob.children.append(
        settings_image(
            "Image",
            assets["SliderKnob"],
            udim2(0, -42, 0, -40),
            udim2(0, 160, 0, 160),
            210,
            stretch=True,
        )
    )
    slider.children.extend([fill_middle, slider_knob])
    speed_row.children.append(slider)
    canvas.children.append(speed_row)

    aquarium_row = settings_image(
        "AquariumTeleportRow",
        assets["RowBackground"],
        udim2(0, 86, 0, 760),
        udim2(0, 1278, 0, 226),
        203,
        stretch=True,
    )
    teleport_button = settings_image(
        "TeleportButton",
        assets["TeleportButton"],
        udim2(0, 930, 0, 64),
        udim2(0, 270, 0, 96),
        208,
        button_node=True,
    )
    teleport_button.children.append(scale("PressScale"))
    aquarium_row.children.extend(
        [
            settings_image(
                "FishBowlIcon",
                assets["FishBowl"],
                udim2(0, 60, 0, 30),
                udim2(0, 160, 0, 160),
                205,
            ),
            settings_label(
                "AquariumTitle",
                "Aquarium",
                udim2(0, 220, 0, 55),
                udim2(0, 830, 0, 110),
                46,
                (255, 255, 255),
                2,
                206,
            ),
            teleport_button,
        ]
    )
    canvas.children.append(aquarium_row)
    overlay.children.append(canvas)
    return overlay


def make_main_panel() -> Node:
    root = panel_chrome(
        frame(
            "MainPanel",
            position=udim2(0.5, 0, 0.52, 0),
            size=udim2(0.72, 0, 0.76, 0),
            anchor=vec2(0.5, 0.5),
            background=color(5, 35, 77),
            transparency=0.03,
            visible=False,
            zindex=200,
            clips=True,
        )
    )
    root.children.extend(
        [
            scale("PanelScale"),
            size_constraint(330, 360, 1240, 900, "PanelSizeConstraint"),
            frame("AuthoredHeaderScaffold", size=udim2(1, 0, 0.13, 0), background=color(7, 67, 129), transparency=0.02, zindex=201),
            frame("AuthoredContentScaffold", position=udim2(0.035, 0, 0.16, 0), size=udim2(0.93, 0, 0.79, 0), background=color(3, 25, 58), transparency=0.24, zindex=201, clips=True),
        ]
    )
    header = next(child for child in root.children if child.name == "AuthoredHeaderScaffold")
    header.children.extend(
        [
            label("Title", "Shop", text_size=34, position=udim2(0.04, 0, 0, 0), size=udim2(0.78, 0, 1, 0), transparency=1, zindex=202, align=0),
            button("CloseButton", "X", position=udim2(0.97, 0, 0.5, 0), size=udim2(0, 46, 0, 46), anchor=vec2(1, 0.5), background=color(239, 151, 17), transparency=0, zindex=203),
        ]
    )
    content = next(child for child in root.children if child.name == "AuthoredContentScaffold")
    content.children.extend([padding(10, 10, 10, 10)])
    tabs = frame(
        "Tabs",
        size=udim2(1, 0, 0, 58),
        transparency=1,
        zindex=203,
    )
    tabs.children.extend(
        [
            list_layout(horizontal=True, gap=8),
            button("ItemsTab", "Items", layout_order=1, size=udim2(0.3, 0, 1, 0), background=color(7, 78, 144), transparency=0.04, zindex=204),
            button("RodsTab", "Rods", layout_order=2, size=udim2(0.3, 0, 1, 0), background=color(7, 78, 144), transparency=0.04, zindex=204),
            button("SeaStarsTab", "Sea Stars", layout_order=3, size=udim2(0.3, 0, 1, 0), background=color(7, 78, 144), transparency=0.04, zindex=204),
        ]
    )
    content.children.extend(
        [
            tabs,
            scrolling("ItemList", position=udim2(0, 0, 0, 68), size=udim2(1, 0, 1, -68), transparency=1, zindex=203),
        ]
    )
    return root


def make_collection_modal(name: str, title: str, list_name: str) -> Node:
    root = make_modal(name, title, panel_size=(0.78, 0, 0.82, 0))
    panel = root.children[0]
    content = next(child for child in panel.children if child.name == "Content")
    content.children.append(scrolling(list_name, size=udim2(1, 0, 1, 0), transparency=1, zindex=203))
    return root


def make_bag() -> Node:
    """Author the exact four-tab Bag shell and every dynamic clone template.

    BagModernUI used to paint this 1448x1086 asset-skinned surface at runtime.
    The controller now binds these static instances and clones only the
    declared row/card/header/error templates below.
    """

    assets = {
        "Backbone": "rbxassetid://108283623894606",
        "TabNormal": "rbxassetid://105953757083088",
        "TabSelected": "rbxassetid://99455447655780",
        "CloseButton": "rbxassetid://74437026548245",
        "SelectedOutline": "rbxassetid://78993001328940",
        "ItemRowBackground": "rbxassetid://78930126580653",
        "FishStorageHeader": "rbxassetid://94190047330110",
        "LeftDecoration": "rbxassetid://94493748436318",
        "WoodenRodFrame": "rbxassetid://115934227658772",
        "CommonFishFrame": "rbxassetid://82476012961179",
    }

    def exact_image(
        name: str,
        image_id: str,
        *,
        position: tuple[str, Any] = udim2(0, 0, 0, 0),
        size: tuple[str, Any] = udim2(1, 0, 1, 0),
        visible: bool = True,
        zindex: int = 302,
        fit: bool = False,
        button_image: bool = False,
    ) -> Node:
        node = Node(
            "ImageButton" if button_image else "ImageLabel",
            name,
            {
                **gui_props(
                    position=position,
                    size=size,
                    transparency=1,
                    visible=visible,
                    zindex=zindex,
                ),
                "Image": prop("Content", image_id),
                "ScaleType": prop("token", 3 if fit else 0),
            },
        )
        if button_image:
            node.props["AutoButtonColor"] = prop("bool", False)
        return node

    def exact_label(
        name: str,
        text: str,
        *,
        position: tuple[str, Any],
        size: tuple[str, Any],
        text_size: int,
        color_value: tuple[int, int, int] = (255, 255, 255),
        align: int = 0,
        visible: bool = True,
        zindex: int = 309,
        scaled: bool = False,
    ) -> Node:
        node = label(
            name,
            text,
            text_size=text_size,
            text_color=color_value,
            position=position,
            size=size,
            transparency=1,
            visible=visible,
            zindex=zindex,
            align=align,
        )
        node.props["Font"] = prop("token", 26)  # Enum.Font.FredokaOne
        node.props["TextScaled"] = prop("bool", scaled)
        node.props["TextWrapped"] = prop("bool", False)
        node.props["TextStrokeColor3"] = color(0, 0, 0)
        node.props["TextStrokeTransparency"] = prop("float", 0.35)
        node.children = [text_constraint(14, 22)] if scaled else []
        return node

    def action_button() -> Node:
        node = Node(
            "TextButton",
            "ActionButton",
            {
                **gui_props(
                    position=udim2(1, -34, 0.5, 0),
                    size=udim2(0, 206, 0, 64),
                    anchor=vec2(1, 0.5),
                    background=color(4, 35, 78),
                    transparency=0,
                    visible=False,
                    zindex=310,
                ),
                "Active": prop("bool", True),
                "AutoButtonColor": prop("bool", True),
                "Font": prop("token", 26),  # Enum.Font.FredokaOne
                "Selectable": prop("bool", True),
                "Text": prop("string", "Equip"),
                "TextColor3": color(255, 255, 255),
                "TextScaled": prop("bool", False),
                "TextSize": prop("float", 28),
                "TextStrokeColor3": color(0, 0, 0),
                "TextStrokeTransparency": prop("float", 0.35),
                "TextWrapped": prop("bool", False),
            },
        )
        node.children.extend([corner(0, 14), stroke(0, 112, 255, 2, 0.08)])
        return node

    root = frame(
        "ModernBagRoot",
        size=udim2(1, 0, 1, 0),
        transparency=1,
        visible=False,
        zindex=300,
    )
    root.props["Active"] = prop("bool", True)

    canvas = frame(
        "Canvas",
        position=udim2(0.5, 0, 0.5, -70),
        size=udim2(0, 1448, 0, 1086),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        zindex=301,
        clips=False,
    )
    canvas.children.extend(
        [
            scale("ResponsiveScale", 0.36),
            exact_image("Backbone", assets["Backbone"], size=udim2(0, 1448, 0, 1086), zindex=301),
            exact_image(
                "BagDecoration",
                assets["LeftDecoration"],
                position=udim2(0, 52, 0, 2),
                size=udim2(0, 235, 0, 198),
                zindex=305,
                fit=True,
            ),
            exact_label(
                "Title",
                "Bag",
                position=udim2(0, 300, 0, 24),
                size=udim2(0, 390, 0, 130),
                text_size=86,
                zindex=306,
            ),
            exact_image(
                "CloseButton",
                assets["CloseButton"],
                position=udim2(0, 1278, 0, 42),
                size=udim2(0, 92, 0, 92),
                zindex=310,
                fit=True,
                button_image=True,
            ),
        ]
    )
    title_node = next(child for child in canvas.children if child.name == "Title")
    title_node.props["TextStrokeColor3"] = color(14, 20, 30)
    title_node.props["TextStrokeTransparency"] = prop("float", 0)

    # UDim offsets persist as integers; these are the engine-coerced pixels
    # produced by the legacy TOP_TAB_WIDTH/TOP_TAB_GAP calculations.
    tab_width = 353
    tab_positions = (40, 378, 717, 1055)
    for index, (tab_id, tab_text) in enumerate(
        (("Rods", "Fishing Rods"), ("Bait", "Bait"), ("Fish", "Fish"), ("Materials", "Materials"))
    ):
        tab = exact_image(
            f"{tab_id}Tab",
            assets["TabSelected"] if index == 0 else assets["TabNormal"],
            position=udim2(0, tab_positions[index], 0, 133),
            size=udim2(0, tab_width, 0, 190),
            zindex=306,
            button_image=True,
        )
        tab.children.append(
            exact_label(
                "Label",
                tab_text,
                position=udim2(0, 0, 0, 0),
                size=udim2(1, 0, 1, 0),
                text_size=40,
                align=2,
                zindex=309,
                scaled=True,
            )
        )
        canvas.children.append(tab)

    item_list = scrolling(
        "ItemList",
        position=udim2(0, 62, 0, 286),
        size=udim2(0, 1316, 0, 712),
        transparency=1,
        zindex=304,
    )
    item_list.props.update(
        {
            "ScrollBarImageColor3": color(0, 112, 255),
            "ScrollBarImageTransparency": prop("float", 0),
            "ScrollBarThickness": prop("int", 7),
            "VerticalScrollBarInset": prop("token", 1),
        }
    )
    item_list.children.extend(
        [
            padding(2, 30, 2, 18),
            list_layout(horizontal=False, gap=-15, horizontal_alignment=0),
        ]
    )
    canvas.children.append(item_list)
    root.children.append(canvas)

    templates = Node("Folder", "Templates")

    row = frame(
        "InventoryRowTemplate",
        size=udim2(1, -4, 0, 150),
        transparency=1,
        visible=False,
        zindex=304,
    )
    background = exact_image(
        "Background",
        assets["ItemRowBackground"],
        size=udim2(1, 0, 1, 0),
        visible=True,
        zindex=305,
    )
    background.children.append(
        exact_image(
            "SelectedOutline",
            assets["SelectedOutline"],
            size=udim2(1, 0, 1, 0),
            visible=False,
            zindex=320,
        )
    )
    row.children.append(background)

    rod_frame = exact_image(
        "RodFrame",
        assets["WoodenRodFrame"],
        position=udim2(0, 28, 0, 19),
        size=udim2(0, 112, 0, 112),
        visible=False,
        zindex=307,
        fit=True,
    )
    rod_frame.children.append(
        exact_image(
            "RodIcon",
            "",
            position=udim2(0.10, 0, 0.10, 0),
            size=udim2(0.80, 0, 0.80, 0),
            zindex=308,
            fit=True,
        )
    )
    row.children.append(rod_frame)

    bait_frame = frame(
        "BaitFrame",
        position=udim2(0, 28, 0, 25),
        size=udim2(0, 94, 0, 94),
        background=color(3, 18, 49),
        transparency=0,
        visible=False,
        zindex=307,
        clips=True,
    )
    bait_frame.children.extend(
        [
            corner(0, 10),
            stroke(0, 103, 255, 2, 0.05),
            exact_image(
                "ModernBaitIcon",
                "",
                position=udim2(0, 4, 0, 0),
                size=udim2(0, 90, 0, 90),
                zindex=309,
                fit=True,
            ),
        ]
    )
    row.children.append(bait_frame)

    fish_frame = exact_image(
        "FishFrame",
        assets["CommonFishFrame"],
        position=udim2(0, 28, 0, 19),
        size=udim2(0, 112, 0, 112),
        visible=False,
        zindex=307,
        fit=True,
    )
    fish_frame.children.append(
        exact_image(
            "FishIcon",
            "",
            position=udim2(0.12, 0, 0.12, 0),
            size=udim2(0.76, 0, 0.76, 0),
            zindex=308,
            fit=True,
        )
    )
    row.children.append(fish_frame)

    row_label_specs = (
        ("RodName", "", (174, 23, 650, 46), 32, (255, 255, 255), 0),
        ("Speed", "", (174, 80, 260, 38), 25, (0, 230, 255), 0),
        ("Luck", "", (430, 80, 270, 38), 25, (180, 255, 0), 0),
        ("BaitName", "", (174, 23, 650, 46), 32, (255, 255, 255), 0),
        ("Quantity", "", (174, 80, 320, 38), 25, (190, 204, 220), 0),
        ("Description", "", (470, 80, 410, 38), 21, (150, 175, 205), 0),
        ("FishName", "", (174, 23, 650, 46), 32, (255, 255, 255), 0),
        ("Rarity", "", (174, 80, 220, 38), 25, (255, 255, 255), 0),
        ("Value", "", (410, 80, 280, 38), 25, (255, 220, 80), 0),
    )
    for name, text, rect, text_size, text_color, align in row_label_specs:
        x, y, width, height = rect
        row.children.append(
            exact_label(
                name,
                text,
                position=udim2(0, x, 0, y),
                size=udim2(0, width, 0, height),
                text_size=text_size,
                color_value=text_color,
                align=align,
                visible=False,
            )
        )
    empty = exact_label(
        "Empty",
        "",
        position=udim2(0, 0, 0, 0),
        size=udim2(1, 0, 1, 0),
        text_size=30,
        color_value=(190, 204, 220),
        align=2,
        visible=False,
        scaled=True,
    )
    empty.children = [text_constraint(18, 30)]
    row.children.extend([empty, action_button()])
    templates.children.append(row)

    fish_header = frame(
        "FishStorageHeaderTemplate",
        size=udim2(1, -4, 0, 104),
        transparency=1,
        visible=False,
        zindex=304,
    )
    fish_header_background = exact_image(
        "Background",
        assets["FishStorageHeader"],
        size=udim2(1, 0, 1, 0),
        zindex=305,
    )
    fish_header_background.children.extend(
        [
            exact_label(
                "Storage",
                "Fish Storage: 0 / 0",
                position=udim2(0, 34, 0, 10),
                size=udim2(0, 600, 0, 84),
                text_size=31,
                zindex=307,
            ),
            exact_label(
                "Value",
                "Bag Value: 0 Coins",
                position=udim2(1, -600, 0, 10),
                size=udim2(0, 550, 0, 84),
                text_size=29,
                color_value=(255, 220, 80),
                align=1,
                zindex=307,
            ),
        ]
    )
    fish_header.children.append(fish_header_background)
    templates.children.append(fish_header)

    resource_section = frame(
        "ResourceSectionTemplate",
        size=udim2(1, -4, 0, 166),
        background=color(8, 28, 58),
        transparency=0.04,
        visible=False,
        zindex=304,
    )
    resource_section.children.extend(
        [
            corner(0, 16),
            stroke(48, 132, 218, 2, 0.15),
            exact_label(
                "Title",
                "Resources",
                position=udim2(0, 22, 0, 6),
                size=udim2(0, 360, 0, 42),
                text_size=28,
                color_value=(235, 247, 255),
                zindex=306,
            ),
        ]
    )
    templates.children.append(resource_section)

    resource_card = frame(
        "ResourceCardTemplate",
        size=udim2(0, 292, 0, 94),
        background=color(39, 68, 98),
        transparency=0.04,
        visible=False,
        zindex=306,
    )
    fallback_icon = frame(
        "FallbackIcon",
        position=udim2(0, 10, 0, 13),
        size=udim2(0, 66, 0, 66),
        background=color(103, 147, 190),
        transparency=0,
        visible=False,
        zindex=308,
    )
    fallback_icon.children.extend(
        [
            corner(0, 12),
            exact_label(
                "Initials",
                "",
                position=udim2(0, 0, 0, 0),
                size=udim2(1, 0, 1, 0),
                text_size=26,
                align=2,
                zindex=309,
            ),
        ]
    )
    resource_card.children.extend(
        [
            corner(0, 12),
            stroke(118, 172, 224, 2, 0.12),
            exact_image(
                "Icon",
                "",
                position=udim2(0, 10, 0, 13),
                size=udim2(0, 66, 0, 66),
                visible=False,
                zindex=308,
                fit=True,
            ),
            fallback_icon,
            exact_label(
                "Name",
                "",
                position=udim2(0, 86, 0, 8),
                size=udim2(0, 196, 0, 34),
                text_size=21,
            ),
            exact_label(
                "Count",
                "x0",
                position=udim2(0, 86, 0, 38),
                size=udim2(0, 100, 0, 42),
                text_size=28,
                color_value=(255, 225, 106),
            ),
            exact_label(
                "Category",
                "",
                position=udim2(0, 176, 0, 43),
                size=udim2(0, 104, 0, 30),
                text_size=17,
                color_value=(190, 214, 232),
                align=1,
            ),
        ]
    )
    templates.children.append(resource_card)

    error_row = frame(
        "ErrorRowTemplate",
        size=udim2(1, -4, 0, 130),
        background=color(35, 15, 24),
        transparency=0.08,
        visible=False,
        zindex=304,
    )
    error_text = exact_label(
        "ErrorText",
        "Modern Bag could not render. Check Output for [BagModernUI].",
        position=udim2(0, 24, 0, 18),
        size=udim2(1, -48, 1, -36),
        text_size=24,
        color_value=(255, 210, 220),
        align=2,
    )
    error_text.props["TextWrapped"] = prop("bool", True)
    error_row.children.extend([corner(0, 16), stroke(255, 80, 100, 2, 0.08), error_text])
    templates.children.append(error_row)

    root.children.append(templates)
    return root


def make_cast_power() -> Node:
    """Author the exact CastPowerModernUI tree that used to be painted.

    The three source images include transparent padding, so the old controller
    displayed them through clipped, oversized ImageLabels.  Persisting that
    same holder/image geometry keeps the output pixel-equivalent while leaving
    the controller responsible only for visibility, responsive scale, and the
    two moving X positions.
    """

    def mapped_image(
        name: str,
        image_id: str,
        position: tuple[str, Any],
        size: tuple[str, Any],
        zindex: int,
        source: tuple[float, float],
        rect: tuple[float, float, float, float],
    ) -> Node:
        holder = frame(
            name,
            position=position,
            size=size,
            transparency=1,
            zindex=zindex,
            clips=True,
        )
        _, (_, target_width, _, target_height) = size
        left, top, right, bottom = rect
        crop_width = right - left
        crop_height = bottom - top
        full_width = target_width * source[0] / crop_width
        full_height = target_height * source[1] / crop_height
        # UDim offsets serialize as signed integers. Roblox applies the same
        # integer coercion when the legacy Lua passes these calculated values
        # to UDim2.fromOffset.
        mapped = image(
            "Image",
            image_id=image_id,
            scale_type=SCALE_TYPE_STRETCH,
            position=udim2(
                0,
                round(-left / source[0] * full_width),
                0,
                round(-top / source[1] * full_height),
            ),
            size=udim2(0, round(full_width), 0, round(full_height)),
            transparency=1,
            zindex=zindex,
        )
        holder.children.append(mapped)
        return holder

    root = frame("ModernCastPowerUI", transparency=1, visible=False, zindex=140)
    content = frame(
        "CastPowerContent",
        position=udim2(0.5, 0, 0.64, 0),
        size=udim2(0, 1280, 0, 340),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        visible=False,
        zindex=140,
        clips=False,
    )
    content.children.append(scale("CastPowerScale"))

    title = label(
        "ChargeInstruction",
        'Hold to charge. <font color="#043FD0">Release to cast.</font>',
        text_size=30,
        position=udim2(0, 0, 0, -640),
        size=udim2(0, 1280, 0, 78),
        transparency=1,
        zindex=145,
        align=2,
    )
    title.props["Font"] = prop("token", 26)  # Enum.Font.FredokaOne
    title.props["RichText"] = prop("bool", True)
    title.props["TextStrokeColor3"] = color(0, 0, 0)
    title.props["TextStrokeTransparency"] = prop("float", 0)
    title.children = [text_constraint(24, 30)]
    content.children.append(title)

    track = frame(
        "CastPowerTrack",
        position=udim2(0, 90, 0, 130),
        size=udim2(0, 1100, 0, 142),
        transparency=1,
        zindex=142,
        clips=False,
    )
    track.children.append(
        mapped_image(
            "HoldingBar",
            "rbxassetid://94855129831884",
            udim2(0, 0, 0, 0),
            udim2(0, 1100, 0, 142),
            142,
            (1024, 256),
            (73, 73, 955, 187),
        )
    )
    motion = frame(
        "MotionArea",
        position=udim2(0, 38, 0, 4),
        size=udim2(0, 1024, 0, 134),
        transparency=1,
        zindex=143,
        clips=False,
    )
    target = mapped_image(
        "TargetIcon",
        "rbxassetid://117292116385823",
        udim2(0.72, 0, 0.5, 0),
        udim2(0, 106, 0, 166),
        146,
        (1024, 1024),
        (235, 202, 789, 787),
    )
    target.props["AnchorPoint"] = vec2(0.5, 0.5)
    knob = mapped_image(
        "MovingKnob",
        "rbxassetid://126560428939799",
        udim2(0.012, 0, 0.5, 0),
        udim2(0, 38, 0, 142),
        148,
        (410, 1024),
        (131, 189, 279, 797),
    )
    knob.props["AnchorPoint"] = vec2(0.5, 0.5)
    motion.children.extend([target, knob])
    track.children.append(motion)
    content.children.append(track)

    # Keep perfect-cast feedback on its own authored layer. The charge
    # content can be hidden immediately after release while short-lived
    # clones of this declared template remain visible for their original
    # 0.54-0.70 second lifetimes.
    sparkle_layer = frame(
        "SparkleLayer",
        position=udim2(0.5, 0, 0.64, 0),
        size=udim2(0, 1280, 0, 340),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        visible=False,
        zindex=159,
        clips=False,
    )
    sparkle_layer.children.append(scale("SparkleScale"))
    sparkle_template = frame(
        "PerfectCastSparkleTemplate",
        position=udim2(0.4, 0, 0.54, 0),
        size=udim2(0, 10, 0, 10),
        anchor=vec2(0.5, 0.5),
        background=color(255, 255, 255),
        transparency=0,
        visible=False,
        zindex=160,
        clips=False,
    )
    sparkle_template.children.append(corner(0, 10, "SparkleCorner"))
    sparkle_layer.children.append(sparkle_template)

    root.children.extend([content, sparkle_layer])
    return root


def make_minigame() -> Node:
    """Persist the exact v19 fishing-minigame visual tree."""
    panel = frame(
        "CustomFishingMinigame",
        position=udim2(0.3, 0, 0.4, 0),
        size=udim2(0, 547, 0, 719),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        visible=False,
        zindex=120,
        clips=False,
    )

    header = label(
        "HeaderText",
        "Waiting for a bite...",
        text_size=30,
        position=udim2(0.5, 0, 0.055, 0),
        size=udim2(0.98, 0, 0.065, 0),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        visible=False,
        zindex=150,
        align=2,
    )
    header.props["Font"] = prop("token", 20)  # Enum.Font.GothamBlack
    header.props["TextStrokeColor3"] = color(16, 72, 190)
    header.props["TextStrokeTransparency"] = prop("float", 0.45)
    header.props["TextWrapped"] = prop("bool", False)
    header.children = [text_constraint(9, 30)]
    panel.children.append(header)

    water_panel = image(
        "WaterPanel",
        image_id="rbxassetid://134199963481930",
        scale_type=SCALE_TYPE_FIT,
        position=udim2(0.405, 0, 0.56, 0),
        size=udim2(0.61, 0, 0.82, 0),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        zindex=130,
        clips=True,
    )
    water_panel.children.append(
        Node(
            "UIAspectRatioConstraint",
            "WaterPanelAspect",
            {
                "AspectRatio": prop("float", 850 / 1514),
                "DominantAxis": prop("token", 1),  # Height
            },
        )
    )
    water_inner = frame(
        "WaterInnerMovementArea",
        position=udim2(0.5, 0, 0.505, 0),
        size=udim2(0.88, 0, 0.84, 0),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        zindex=132,
        clips=True,
    )
    catch_bar = image(
        "CatchBar",
        image_id="rbxassetid://84261877127360",
        scale_type=SCALE_TYPE_STRETCH,
        position=udim2(0.5, 0, 0.70, 0),
        size=udim2(0.94, 0, 0.232, 0),
        anchor=vec2(0.5, 0),
        transparency=1,
        zindex=138,
    )
    water_inner.children.append(catch_bar)

    fish_marker = image(
        "FishMarkerCircle",
        image_id="rbxassetid://74137560034505",
        scale_type=SCALE_TYPE_STRETCH,
        position=udim2(0.5, 0, 0.34, 0),
        size=udim2(0.31, 0, 0.19, 0),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        zindex=142,
        clips=True,
    )
    fish_marker.children.extend(
        [
            corner(1, 0),
            Node(
                "UIAspectRatioConstraint",
                "FishMarkerAspect",
                {"AspectRatio": prop("float", 1), "DominantAxis": prop("token", 1)},
            ),
        ]
    )
    fish_image = image(
        "FishImage",
        scale_type=SCALE_TYPE_FIT,
        position=udim2(0.5, 0, 0.5, 0),
        size=udim2(0.80, 0, 0.80, 0),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        zindex=145,
    )
    fish_marker.children.append(fish_image)
    water_inner.children.append(fish_marker)
    water_panel.children.append(water_inner)
    panel.children.append(water_panel)

    progress_track = image(
        "ProgressTrack",
        image_id="rbxassetid://85876175896136",
        scale_type=SCALE_TYPE_FIT,
        position=udim2(0.805, 0, 0.56, 0),
        size=udim2(0.15, 0, 0.82, 0),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        zindex=130,
        clips=True,
    )
    progress_track.children.extend(
        [
            Node(
                "UIAspectRatioConstraint",
                "ProgressTrackAspect",
                {"AspectRatio": prop("float", 287 / 2048), "DominantAxis": prop("token", 1)},
            ),
            Node("UIScale", "RageGaugeFocusScale", {"Scale": prop("float", 1)}),
        ]
    )
    progress_inner = frame(
        "ProgressInner",
        position=udim2(0.5, 0, 0.5, 0),
        size=udim2(0.72, 0, 0.94, 0),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        zindex=134,
        clips=True,
    )
    progress_fill = frame(
        "ProgressFill",
        position=udim2(0.5, 0, 1, 0),
        size=udim2(0.92, 0, 0.12, 0),
        anchor=vec2(0.5, 1),
        transparency=1,
        zindex=136,
        clips=True,
    )
    gauge_specs = (
        ("TopCap", (0, 0), (604, 248)),
        ("Middle", (0, 232), (604, 562)),
        ("BottomCap", (0, 778), (604, 248)),
    )
    for piece_name, rect_offset, rect_size in gauge_specs:
        piece = image(
            piece_name,
            image_id="rbxassetid://138976342109765",
            scale_type=SCALE_TYPE_STRETCH,
            transparency=1,
            zindex=136,
        )
        piece.props["AnchorPoint"] = vec2(0, 0)
        piece.props["ImageRectOffset"] = vec2(*rect_offset)
        piece.props["ImageRectSize"] = vec2(*rect_size)
        progress_fill.children.append(piece)
    progress_inner.children.append(progress_fill)
    progress_track.children.append(progress_inner)
    panel.children.append(progress_track)

    # Compatibility labels are intentionally hidden, but persisted because
    # gameplay code keeps references to them.
    for compatibility_name in (
        "StatusText",
        "ProgressText",
        "BaitText",
        "CastText",
        "InstructionText",
    ):
        panel.children.append(
            label(
                compatibility_name,
                "",
                text_size=14,
                transparency=1,
                visible=False,
                zindex=1,
            )
        )
    return panel


def make_template(name: str, order: int, *, row: bool = False) -> Node:
    template = panel_chrome(
        frame(
            name,
            size=udim2(1, 0, 0, 78 if row else 138),
            background=color(5, 47, 91),
            transparency=0.04,
            visible=False,
            zindex=1,
            layout_order=order,
        ),
        radius=12,
    )
    template.children.extend(
        [
            image(
                "Icon",
                scale_type=SCALE_TYPE_FIT,
                position=udim2(0.025, 0, 0.5, 0),
                size=udim2(0, 58 if row else 86, 0, 58 if row else 86),
                anchor=vec2(0, 0.5),
                transparency=1,
                zindex=2,
            ),
            label("Title", "Template", text_size=22, position=udim2(0.22 if row else 0.18, 0, 0.10, 0), size=udim2(0.48, 0, 0.28, 0), transparency=1, zindex=2, align=0),
            label("Description", "", text_size=16, position=udim2(0.22 if row else 0.18, 0, 0.42, 0), size=udim2(0.48, 0, 0.24, 0), transparency=1, zindex=2, align=0),
            label("Value", "", text_size=18, position=udim2(0.68, 0, 0.12, 0), size=udim2(0.16, 0, 0.28, 0), transparency=1, zindex=2, align=1),
            button("ActionButton", "Select", position=udim2(0.97, 0, 0.72, 0), size=udim2(0.22, 0, 0, 38), anchor=vec2(1, 0.5), background=color(17, 136, 209), transparency=0.02, zindex=3),
        ]
    )
    return template


def make_templates() -> Node:
    root = Node("Folder", "Templates")
    root.children.extend(
        [
            make_template("ItemCardTemplate", 1),
            make_template("ShopItemCardTemplate", 2),
            make_template("ProductCardTemplate", 3),
            make_template("QuestCardTemplate", 4),
            make_template("FishCardTemplate", 5),
            make_template("InventoryRowTemplate", 6, row=True),
            make_template("StatRowTemplate", 7, row=True),
            button("TabButtonTemplate", "Tab", size=udim2(0, 180, 0, 52), background=color(7, 67, 129), transparency=0.02, visible=False, zindex=1),
        ]
    )
    return root


def split_root_surfaces() -> dict[str, Node]:
    """Keep compatibility-sensitive HUD hosts direct under FishingGui.

    Several existing controllers use FishingGui:FindFirstChild(name), so the
    authored hosts cannot live only below Root/HUD/LeftStats.  HUD/LeftStats is
    retained as a semantic layout guide while the live hosts are direct peers.
    """
    root = make_root()
    hud = next(child for child in root.children if child.name == "HUD")
    root.children.remove(hud)

    left = next(child for child in hud.children if child.name == "LeftStats")
    xp = next(child for child in left.children if child.name == "FishingXPText")
    coins = next(child for child in left.children if child.name == "CoinsHud")
    stars = next(child for child in left.children if child.name == "SeaStarsHud")
    left.children.remove(xp)
    left.children.remove(coins)
    left.children.remove(stars)

    top = next(child for child in hud.children if child.name == "TopButtonsFrame")
    bottom = next(child for child in hud.children if child.name == "BottomButtonsFrame")
    hud.children.remove(top)
    hud.children.remove(bottom)

    # Exact v1636 desktop geometry. Responsive scaling is owned by
    # AuthoredUiController and is intentionally independent from TopHudGui.
    xp.props["AnchorPoint"] = vec2(1, 0)
    xp.props["Position"] = udim2(0.99, 0, 0.10, -44 + EDITOR_PREVIEW_CORE_TOP_INSET)
    xp.props["Size"] = udim2(0, 330, 0, 54)
    xp.children.insert(0, scale("LeftStatsScale", 0.86))
    xp.children.insert(1, size_constraint(330, 54, 330, 54, "XPSizeConstraint"))
    # The level label is visually aligned to the same left edge as both icons.
    xp.children[2].props["TextXAlignment"] = prop("token", 0)

    coins.props["AnchorPoint"] = vec2(1, 0)
    coins.props["Position"] = udim2(0.99, 6, 0.10, EDITOR_PREVIEW_CORE_TOP_INSET)
    coins.props["Size"] = udim2(0, 330, 0, 96)
    coins.children.insert(0, scale("LeftStatsScale", 0.86))
    coins.children.insert(1, size_constraint(330, 96, 330, 96, "CoinsSizeConstraint"))

    stars.props["AnchorPoint"] = vec2(1, 0)
    stars.props["Position"] = udim2(0.99, 8, 0.10, 49 + EDITOR_PREVIEW_CORE_TOP_INSET)
    stars.props["Size"] = udim2(0, 330, 0, 96)
    stars.children.insert(0, scale("LeftStatsScale", 0.86))
    stars.children.insert(1, size_constraint(330, 96, 330, 96, "SeaStarsSizeConstraint"))

    # The guide documents the intended grouping without creating duplicate live
    # objects that name-based scripts could bind to by accident.
    left.props["Visible"] = prop("bool", False)

    return {
        "Root": root,
        "HUD": hud,
        "FishingXPText": xp,
        "CoinsHud": coins,
        "SeaStarsHud": stars,
        "TopButtonsFrame": top,
        "BottomButtonsFrame": bottom,
    }


def models() -> dict[str, Node]:
    declared = split_root_surfaces()
    declared.update({
        "SettingsOverlay": make_settings_overlay(),
        "BiomeWarpOverlay": make_special_modal("BiomeWarpOverlay", "Island Warp"),
        "FishmongerSellOverlay": make_special_modal("FishmongerSellOverlay", "Fishmonger"),
        "RodShopOverlay": make_special_modal("RodShopOverlay", "Rod Shop"),
        "MainPanel": make_main_panel(),
        "ModernFishdex": make_collection_modal("ModernFishdex", "Fishdex", "FishList"),
        "ModernBagRoot": make_bag(),
        "ModernQuestUI": make_collection_modal("ModernQuestUI", "Quests", "QuestList"),
        "ModernCastPowerUI": make_cast_power(),
        "CustomFishingMinigame": make_minigame(),
        "Templates": make_templates(),
    })
    return declared


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
    else:
        raise ValueError(f"Unsupported property kind: {kind}")


def add_node(parent: ET.Element, node: Node, counter: list[int]) -> None:
    counter[0] += 1
    item = ET.SubElement(parent, "Item", {"class": node.class_name, "referent": f"RBX{counter[0]:08X}"})
    properties = ET.SubElement(item, "Properties")
    name_node = ET.SubElement(properties, "string", {"name": "Name"})
    name_node.text = node.name
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
    declared = models()
    if tuple(declared) != MODEL_FILES:
        raise RuntimeError("MODEL_FILES and models() are out of sync")
    for file_stem, node in declared.items():
        if file_stem == "TopButtonsFrame":
            write_model(TOP_HUD_HERE / "TopButtonsFrame.rbxmx", node)
            continue
        if file_stem in {
            "SettingsOverlay",
            "BiomeWarpOverlay",
            "FishmongerSellOverlay",
            "RodShopOverlay",
            "MainPanel",
            "ModernFishdex",
            "ModernBagRoot",
            "ModernQuestUI",
        }:
            continue
        write_model(HERE / f"{file_stem}.rbxmx", node)


if __name__ == "__main__":
    main()

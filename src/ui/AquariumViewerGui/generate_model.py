"""Generate the persistent Aquarium Viewer Explorer hierarchy.

Only repeating fish/player records are cloned at runtime. Every fixed visual,
button, tab, list host, label, and scroll treatment is authored in this model.
"""

from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(HERE.parent / "FishingGui"))

from generate_models import (  # noqa: E402
    Node,
    color,
    corner,
    frame,
    gui_props,
    prop,
    scale,
    stroke,
    udim,
    udim2,
    vec2,
    write_model,
)


ASSET = {
    "fish_tab": "rbxassetid://131466644643247",
    "fish_panel": "rbxassetid://127996372815955",
    "backbone": "rbxassetid://104759751456941",
    "capacity": "rbxassetid://125654737802805",
    "coin": "rbxassetid://102095594840013",
    "coral": "rbxassetid://109248646612122",
    "explore_shell": "rbxassetid://121676475074564",
    "left_decor": "rbxassetid://107602146669555",
    "level": "rbxassetid://105327955653365",
    "remove": "rbxassetid://109156112056544",
    "right_decor": "rbxassetid://105621557357975",
    "scroll": "rbxassetid://90625326453971",
    "selected_tab": "rbxassetid://84751657680455",
    "top_bar": "rbxassetid://92519303171140",
    "upgrade": "rbxassetid://140618424967086",
    "close": "rbxassetid://81760248223303",
}

FONT_FREDOKA = 26
WHITE = (255, 251, 238)
CYAN = (25, 238, 255)
YELLOW = (255, 224, 28)
NAVY = (4, 25, 61)


def image_node(
    name: str,
    asset: str,
    x: int,
    y: int,
    w: int,
    h: int,
    *,
    z: int = 1,
    rect: tuple[int, int, int, int] | None = None,
    button: bool = False,
    visible: bool = True,
) -> Node:
    props = gui_props(
        position=udim2(0, x, 0, y),
        size=udim2(0, w, 0, h),
        transparency=1,
        zindex=z,
        visible=visible,
    )
    props.update({
        "Image": prop("Content", asset),
        "ScaleType": prop("token", 0),
        "ImageTransparency": prop("float", 0),
    })
    if rect:
        rx, ry, rw, rh = rect
        props["ImageRectOffset"] = vec2(rx, ry)
        props["ImageRectSize"] = vec2(rw, rh)
    if button:
        props.update({
            "AutoButtonColor": prop("bool", False),
            "Modal": prop("bool", False),
        })
    return Node("ImageButton" if button else "ImageLabel", name, props)


def text_node(
    name: str,
    text: str,
    x: int,
    y: int,
    w: int,
    h: int,
    *,
    size: int = 28,
    text_color: tuple[int, int, int] = WHITE,
    align: int = 0,
    z: int = 10,
    stroke_transparency: float = 0.05,
    wrapped: bool = False,
) -> Node:
    props = gui_props(
        position=udim2(0, x, 0, y),
        size=udim2(0, w, 0, h),
        transparency=1,
        zindex=z,
    )
    props.update({
        "Font": prop("token", FONT_FREDOKA),
        "Text": prop("string", text),
        "TextColor3": color(*text_color),
        "TextScaled": prop("bool", False),
        "TextSize": prop("float", size),
        "TextStrokeColor3": color(1, 8, 22),
        "TextStrokeTransparency": prop("float", stroke_transparency),
        "TextTransparency": prop("float", 0),
        "TextWrapped": prop("bool", wrapped),
        "TextXAlignment": prop("token", align),
        "TextYAlignment": prop("token", 1),
        "RichText": prop("bool", True),
    })
    return Node("TextLabel", name, props)


def transparent_button(name: str, x: int, y: int, w: int, h: int, *, z: int = 30) -> Node:
    props = gui_props(
        position=udim2(0, x, 0, y),
        size=udim2(0, w, 0, h),
        transparency=1,
        zindex=z,
    )
    props.update({
        "AutoButtonColor": prop("bool", False),
        "Text": prop("string", ""),
        "TextTransparency": prop("float", 1),
    })
    return Node("TextButton", name, props)


def rounded_panel(name: str, x: int, y: int, w: int, h: int, *, z: int = 2, transparency: float = 0.04) -> Node:
    node = frame(
        name,
        position=udim2(0, x, 0, y),
        size=udim2(0, w, 0, h),
        background=color(3, 30, 73),
        transparency=transparency,
        zindex=z,
        clips=True,
    )
    node.children.extend([corner(0, 16), stroke(10, 137, 255, 2, 0.08)])
    return node


def list_layout(padding_px: int) -> Node:
    return Node("UIListLayout", "UIListLayout", {
        "FillDirection": prop("token", 1),
        "HorizontalAlignment": prop("token", 0),
        "Padding": udim(0, padding_px),
        "SortOrder": prop("token", 2),
        "VerticalAlignment": prop("token", 0),
    })


def make_scrolling(name: str, x: int, y: int, w: int, h: int, *, z: int = 5, dark: bool = False) -> Node:
    props = gui_props(
        position=udim2(0, x, 0, y),
        size=udim2(0, w, 0, h),
        background=color(*NAVY),
        transparency=0.10 if dark else 1,
        zindex=z,
        clips=True,
    )
    props.update({
        "AutomaticCanvasSize": prop("token", 2),
        "CanvasSize": udim2(0, 0, 0, 0),
        "ScrollBarImageTransparency": prop("float", 1),
        "ScrollBarThickness": prop("int", 0),
        "ScrollingDirection": prop("token", 2),
        "ElasticBehavior": prop("token", 1),
    })
    return Node("ScrollingFrame", name, props)


def make_my_tank_page() -> Node:
    page = frame("MyTankPage", transparency=1, zindex=1)
    page.children.append(image_node("Backbone", ASSET["backbone"], 0, 0, 1672, 941, z=1))
    page.children.append(text_node("SectionTitle", "MY TANK", 86, 147, 360, 40, size=31, text_color=CYAN, z=8))
    page.children.append(image_node("TopBar", ASSET["top_bar"], 73, 190, 1518, 122, z=4, rect=(39, 49, 3642, 351)))

    page.children.append(image_node("LevelIcon", ASSET["level"], 100, 199, 90, 99, z=8, rect=(176, 98, 827, 1192)))
    page.children.append(text_node("LevelValue", "1", 115, 219, 60, 55, size=54, align=2, z=12))
    page.children.append(text_node("LevelLabel", "Level", 202, 233, 90, 42, size=31, z=12))
    page.children.append(image_node("UpgradeArtwork", ASSET["upgrade"], 294, 222, 193, 59, z=8, rect=(59, 97, 1924, 555)))
    page.children.append(text_node("UpgradeText", "Upgrade +500", 330, 231, 142, 39, size=24, align=2, z=12))
    page.children.append(transparent_button("UpgradeButton", 294, 222, 193, 59, z=20))

    page.children.append(image_node("CapacityIcon", ASSET["capacity"], 548, 198, 84, 101, z=8, rect=(229, 90, 797, 1060)))
    page.children.append(text_node("CapacityLabel", "Capacity", 656, 211, 170, 35, size=28, z=12))
    page.children.append(text_node("CapacityValue", "0 / 40", 656, 246, 170, 47, size=38, z=12))

    page.children.append(text_node("BestFishLabel", "Best Fish", 916, 210, 220, 35, size=27, z=12))
    page.children.append(text_node("BestFishValue", "None yet", 916, 249, 270, 42, size=31, z=12))
    page.children.append(image_node("CoinIcon", ASSET["coin"], 1234, 200, 100, 100, z=8, rect=(88, 68, 850, 867)))
    page.children.append(text_node("TotalValueLabel", "Total Value", 1358, 209, 210, 34, size=28, z=12))
    page.children.append(text_node("TotalValueValue", "0 <font size=22>coins</font>", 1358, 244, 210, 48, size=38, text_color=YELLOW, z=12))

    page.children.append(text_node("FishCount", "FISH  —  0", 86, 316, 380, 40, size=31, text_color=CYAN, z=12))
    fish_list = make_scrolling("MyTankFishList", 75, 359, 1465, 500, z=6)
    fish_list.children.append(list_layout(4))
    page.children.append(fish_list)
    page.children.append(text_node("EmptyMessage", "No fish are displayed in this aquarium yet.", 290, 485, 1090, 60, size=28, align=2, z=13))
    page.children.append(image_node("CustomScrollBar", ASSET["scroll"], 1544, 331, 54, 520, z=12, rect=(683, 29, 65, 1021)))
    page.children.append(image_node("LeftDecoration", ASSET["left_decor"], 0, 714, 145, 226, z=14, rect=(17, 106, 916, 1448)))
    page.children.append(image_node("RightDecoration", ASSET["right_decor"], 1519, 711, 153, 229, z=14, rect=(6, 4, 905, 1584)))
    return page


def make_explore_page() -> Node:
    page = frame("ExplorePage", transparency=1, zindex=1, visible=False)
    page.children.append(image_node("ExploreShell", ASSET["explore_shell"], 0, 0, 1672, 941, z=1))

    search_panel = rounded_panel("SearchPanel", 55, 149, 320, 68, z=7, transparency=0.15)
    search_props = gui_props(position=udim2(0, 58, 0, 153), size=udim2(0, 310, 0, 58), transparency=1, zindex=12)
    search_props.update({
        "ClearTextOnFocus": prop("bool", False),
        "Font": prop("token", FONT_FREDOKA),
        "PlaceholderColor3": color(255, 224, 28),
        "PlaceholderText": prop("string", "Search aquariums..."),
        "Text": prop("string", ""),
        "TextColor3": color(255, 255, 255),
        "TextSize": prop("float", 23),
        "TextStrokeTransparency": prop("float", 1),
        "TextXAlignment": prop("token", 0),
    })
    search_box = Node("TextBox", "SearchBox", search_props)
    search_box.children.append(Node("UIPadding", "UIPadding", {"PaddingLeft": udim(0, 64), "PaddingRight": udim(0, 12)}))
    page.children.extend([search_panel, text_node("SearchIcon", "⌕", 70, 153, 52, 56, size=47, text_color=YELLOW, align=2, z=13), search_box])

    nav = [
        ("FeaturedButton", "★   Featured", 238, 88, True),
        ("MostLikedButton", "♡   Most Liked", 341, 88, False),
        ("FriendsButton", "♟   Friends", 442, 88, False),
        ("RandomButton", "↝   Random", 542, 88, False),
    ]
    for name, title, y, h, selected in nav:
        if not selected:
            page.children.append(rounded_panel(name + "Panel", 55, y, 320, h, z=7, transparency=0.10))
        page.children.append(text_node(name + "Label", title, 78, y + 12, 275, h - 24, size=28, z=13))
        page.children.append(transparent_button(name, 55, y, 320, h, z=20))

    page.children.append(text_node("VisitRandomLabel", "◇   Visit Random\n      Aquarium", 78, 665, 275, 80, size=27, z=13, wrapped=True))
    page.children.append(transparent_button("VisitRandomButton", 55, 654, 320, 104, z=20))
    page.children.append(text_node("ExploreHeading", "FEATURED AQUARIUMS", 442, 145, 540, 46, size=32, text_color=CYAN, z=12))

    visitor_list = make_scrolling("ExploreVisitorList", 420, 190, 1182, 724, z=6, dark=True)
    visitor_list.children.append(list_layout(8))
    page.children.append(visitor_list)
    page.children.append(text_node("ExploreEmptyMessage", "No matching aquariums are online right now.", 575, 490, 850, 55, size=28, align=2, z=14))

    scroll_track = frame("ExploreScrollTrack", position=udim2(0, 1607, 0, 193), size=udim2(0, 18, 0, 718), background=color(2, 24, 61), transparency=0.05, zindex=12)
    scroll_track.children.extend([corner(1, 0), stroke(0, 117, 255, 1, 0.2)])
    scroll_thumb = frame("ExploreScrollThumb", position=udim2(0, 2, 0, 5), size=udim2(1, -4, 0, 120), background=color(18, 127, 255), transparency=0, zindex=13)
    scroll_thumb.children.append(corner(1, 0))
    scroll_track.children.append(scroll_thumb)
    page.children.append(scroll_track)
    return page


def make_header() -> Node:
    header = frame("Header", transparency=1, zindex=40)
    header.children.append(image_node("CoralIcon", ASSET["coral"], 50, 32, 114, 92, z=42, rect=(93, 100, 1103, 955)))
    header.children.append(text_node("AquariumTitle", "Aquarium", 181, 42, 320, 78, size=55, z=43))

    my_base = rounded_panel("MyTankTabBase", 513, 41, 300, 84, z=41, transparency=0.08)
    explore_base = rounded_panel("ExploreTabBase", 837, 41, 267, 84, z=41, transparency=0.08)
    header.children.extend([my_base, explore_base])
    header.children.append(image_node("MyTankSelected", ASSET["selected_tab"], 513, 40, 300, 86, z=42, rect=(70, 331, 1302, 398)))
    header.children.append(image_node("ExploreSelected", ASSET["selected_tab"], 836, 40, 269, 86, z=42, rect=(70, 331, 1302, 398), visible=False))
    header.children.append(text_node("MyTankText", "My Tank", 548, 55, 232, 58, size=37, align=2, z=44))
    header.children.append(text_node("ExploreText", "Explore", 861, 55, 220, 58, size=37, align=2, z=44))
    header.children.append(transparent_button("MyTankButton", 513, 40, 300, 86, z=50))
    header.children.append(transparent_button("ExploreButton", 836, 40, 269, 86, z=50))
    header.children.append(image_node("CloseButton", ASSET["close"], 1514, 35, 98, 93, z=46, rect=(375, 422, 427, 439), button=True))
    return header


def make_fish_template() -> Node:
    row = frame("MyTankFishRowTemplate", size=udim2(1, -10, 0, 98), transparency=1, visible=False, zindex=7)
    row.children.append(image_node("RowArtwork", ASSET["fish_tab"], 0, 0, 1450, 98, z=7, rect=(12, 0, 1511, 1024)))
    portrait = rounded_panel("Portrait", 15, 5, 132, 88, z=9, transparency=0.16)
    portrait.children.append(image_node("PortraitArtwork", ASSET["fish_panel"], 0, 0, 132, 88, z=10, rect=(0, 0, 1534, 1024)))
    portrait.children.append(image_node("FishImage", "", 7, 5, 118, 78, z=11))
    row.children.append(portrait)
    row.children.append(text_node("FishName", "Bluegill", 186, 7, 260, 43, size=34, z=12))
    row.children.append(text_node("Rarity", "Common", 350, 15, 190, 30, size=24, text_color=CYAN, z=12))
    row.children.append(image_node("CoinIcon", ASSET["coin"], 183, 50, 29, 29, z=12, rect=(88, 68, 850, 867)))
    row.children.append(text_node("ValuePrefix", "Value:", 218, 47, 80, 34, size=23, z=12))
    row.children.append(text_node("Value", "0", 294, 47, 75, 34, size=27, text_color=YELLOW, z=12))
    row.children.append(text_node("CoinsSuffix", "coins", 366, 47, 80, 34, size=23, z=12))
    row.children.append(image_node("SpaceIcon", ASSET["capacity"], 635, 21, 60, 61, z=12, rect=(229, 90, 797, 1060)))
    row.children.append(text_node("SpaceUsed", "Space used: 0", 706, 31, 300, 43, size=25, z=12))
    row.children.append(image_node("RemoveArtwork", ASSET["remove"], 1240, 19, 190, 64, z=11, rect=(66, 64, 1793, 647)))
    row.children.append(text_node("RemoveText", "Remove", 1262, 29, 146, 44, size=29, align=2, z=13))
    row.children.append(transparent_button("RemoveButton", 1240, 19, 190, 64, z=20))
    return row


def make_visitor_template() -> Node:
    row = rounded_panel("ExploreVisitorRowTemplate", 0, 0, 1158, 148, z=7, transparency=0.04)
    row.props["Size"] = udim2(1, -12, 0, 148)
    row.props["Visible"] = prop("bool", False)

    preview = rounded_panel("Preview", 8, 8, 228, 132, z=9, transparency=0.05)
    preview.children.append(image_node("PreviewFish", "", 18, 5, 190, 122, z=11))
    row.children.append(preview)
    row.children.append(text_node("PlayerName", "Player", 260, 10, 310, 38, size=30, z=12))
    row.children.append(text_node("OnlineStatus", "● Online", 465, 14, 125, 31, size=20, text_color=(0, 255, 209), z=12))
    row.children.append(text_node("AquariumName", "Level 1 Aquarium", 260, 47, 360, 30, size=21, text_color=(0, 255, 235), z=12))
    row.children.append(text_node("TotalLabel", "Total Value", 260, 83, 145, 27, size=19, text_color=(255, 236, 148), z=12))
    row.children.append(image_node("CoinIcon", ASSET["coin"], 258, 111, 26, 26, z=12, rect=(88, 68, 850, 867)))
    row.children.append(text_node("TotalValue", "0", 288, 104, 160, 37, size=27, text_color=YELLOW, z=12))
    row.children.append(text_node("BestLabel", "Best Fish", 506, 83, 125, 27, size=19, text_color=(255, 236, 148), z=12))
    row.children.append(text_node("BestFish", "None yet", 506, 106, 190, 34, size=22, z=12))
    row.children.append(image_node("BestFishImage", "", 700, 16, 190, 119, z=11))
    row.children.append(text_node("FishCount", "♡ 0 fish", 904, 14, 220, 40, size=26, z=12))

    view_panel = rounded_panel("ViewPanel", 899, 68, 244, 66, z=10, transparency=0)
    view_panel.props["BackgroundColor3"] = color(18, 70, 225)
    row.children.append(view_panel)
    row.children.append(text_node("ViewText", "View Aquarium", 914, 80, 214, 43, size=28, align=2, z=13))
    row.children.append(transparent_button("ViewButton", 899, 68, 244, 66, z=20))
    return row


def make_model() -> Node:
    root = frame(
        "Root",
        anchor=vec2(0.5, 0.5),
        position=udim2(0.5, 0, 0.5, 0),
        size=udim2(0, 1672, 0, 941),
        transparency=1,
        visible=False,
        zindex=1,
        clips=True,
    )
    root.children.append(scale("DeviceScale"))
    root.children.extend([make_my_tank_page(), make_explore_page(), make_header()])
    templates = Node("Folder", "Templates")
    templates.children.extend([make_fish_template(), make_visitor_template()])
    root.children.append(templates)
    return root


if __name__ == "__main__":
    # Rojo uses the .rbxmx filename as the live-synced top-level instance name.
    # Keep this named Root so Team Create and clean builds expose one hierarchy.
    write_model(HERE / "Root.rbxmx", make_model())

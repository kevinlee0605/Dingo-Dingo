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
    "left_decor": "rbxassetid://107602146669555",
    "level": "rbxassetid://105327955653365",
    "remove": "rbxassetid://109156112056544",
    "right_decor": "rbxassetid://105621557357975",
    "scroll": "rbxassetid://73367138577137",
    "selected_tab": "rbxassetid://84751657680455",
    "top_bar": "rbxassetid://92519303171140",
    "upgrade": "rbxassetid://140618424967086",
    "close": "rbxassetid://81760248223303",
}

# Original PNG canvas sizes. Roblox may process an uploaded image to a smaller
# texture, so ImageRectOffset values measured from these source files are not
# stable. `image_node` uses these dimensions to crop by normalized placement
# inside a clipped wrapper instead.
ASSET_SOURCE_SIZE = {
    ASSET["fish_tab"]: (1536, 1024),
    ASSET["fish_panel"]: (1536, 1024),
    ASSET["capacity"]: (1254, 1254),
    ASSET["coin"]: (1024, 1024),
    ASSET["coral"]: (1254, 1254),
    ASSET["left_decor"]: (941, 1672),
    ASSET["level"]: (1163, 1353),
    ASSET["remove"]: (1926, 816),
    ASSET["right_decor"]: (941, 1672),
    ASSET["scroll"]: (1448, 1086),
    ASSET["selected_tab"]: (1448, 1086),
    ASSET["top_bar"]: (3728, 480),
    ASSET["upgrade"]: (2048, 768),
    ASSET["close"]: (1187, 1326),
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
    if rect and asset in ASSET_SOURCE_SIZE:
        # Never use ImageRectOffset for the supplied artwork. Roblox can resize
        # uploaded textures, which makes original-PNG pixel coordinates crop or
        # cut off the image (most visibly the close button). A clipped wrapper
        # and full-image child preserve the same normalized crop at any texture
        # resolution.
        rx, ry, rw, rh = rect
        source_w, source_h = ASSET_SOURCE_SIZE[asset]
        wrapper_props = gui_props(
            position=udim2(0, x, 0, y),
            size=udim2(0, w, 0, h),
            transparency=1,
            zindex=z,
            visible=visible,
            clips=True,
        )
        # These nodes used to render the asset directly before cropped artwork
        # was moved into a child. Explicitly clear the parent image so Rojo
        # live-sync cannot preserve the old image and stack two copies.
        wrapper_props.update({
            "Image": prop("Content", ""),
            "ImageTransparency": prop("float", 1),
        })
        if button:
            wrapper_props.update({
                "AutoButtonColor": prop("bool", False),
                "Modal": prop("bool", False),
            })

        wrapper = Node("ImageButton" if button else "ImageLabel", name, wrapper_props)
        artwork_props = gui_props(
            position=udim2(-rx / rw, 0, -ry / rh, 0),
            size=udim2(source_w / rw, 0, source_h / rh, 0),
            transparency=1,
            zindex=z + 1,
        )
        artwork_props.update({
            "Image": prop("Content", asset),
            "ScaleType": prop("token", 0),
            "ImageTransparency": prop("float", 0),
        })
        wrapper.children.append(Node("ImageLabel", "Artwork", artwork_props))
        return wrapper

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
        # VerticalAlignment.Top. Centering short lists made their records float
        # in the middle of the window instead of beginning under the heading.
        "VerticalAlignment": prop("token", 1),
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

    page.children.append(image_node("CapacityIcon", ASSET["capacity"], 572, 198, 84, 101, z=8, rect=(229, 90, 797, 1060)))
    page.children.append(text_node("CapacityLabel", "Capacity", 680, 211, 170, 35, size=28, z=12))
    page.children.append(text_node("CapacityValue", "0 / 40", 680, 246, 170, 47, size=38, z=12))

    # Begin each top-bar section 18 px after its divider in the source artwork.
    page.children.append(text_node("BestFishLabel", "Best Fish", 920, 210, 220, 35, size=27, z=12))
    page.children.append(text_node("BestFishValue", "None yet", 920, 249, 270, 42, size=31, z=12))
    page.children.append(image_node("CoinIcon", ASSET["coin"], 1247, 200, 100, 100, z=8, rect=(88, 68, 850, 867)))
    page.children.append(text_node("TotalValueLabel", "Total Value", 1371, 209, 210, 34, size=28, z=12))
    page.children.append(text_node("TotalValueValue", '0 <font size="22">coins</font>', 1371, 244, 210, 48, size=38, text_color=YELLOW, z=12))

    page.children.append(text_node("FishCount", "FISH  —  0", 86, 316, 380, 40, size=31, text_color=CYAN, z=12))
    fish_list = make_scrolling("MyTankFishList", 75, 359, 1465, 500, z=6)
    fish_list.children.append(list_layout(4))
    page.children.append(fish_list)
    page.children.append(text_node("EmptyMessage", "No fish are displayed in this aquarium yet.", 290, 485, 1090, 60, size=28, align=2, z=13))
    my_tank_scroll = image_node("CustomScrollBar", ASSET["scroll"], 1557, 331, 28, 520, z=12, rect=(683, 29, 65, 1021))
    my_tank_channel = image_node("ScrollbarChannel", ASSET["scroll"], 0, 0, 1, 1, z=12, rect=(701, 914, 30, 90))
    my_tank_channel.props["Position"] = udim2(0.28, 0, 0.05, 0)
    my_tank_channel.props["Size"] = udim2(0.44, 0, 0.82, 0)
    my_tank_scroll.children.append(my_tank_channel)
    my_tank_scroll.children.append(image_node("MyTankScrollThumb", ASSET["scroll"], 7, 0, 14, 120, z=13, rect=(701, 77, 30, 825)))
    page.children.append(my_tank_scroll)
    page.children.append(image_node("LeftDecoration", ASSET["left_decor"], 0, 714, 145, 226, z=14, rect=(17, 106, 916, 1448)))
    page.children.append(image_node("RightDecoration", ASSET["right_decor"], 1519, 711, 153, 229, z=14, rect=(6, 4, 905, 1584)))
    return page


def make_explore_page() -> Node:
    page = frame("ExplorePage", transparency=1, zindex=1, visible=False)
    page.children.append(image_node("Backbone", ASSET["backbone"], 0, 0, 1672, 941, z=1))

    # The supplied Explore picture is a composition reference, not page
    # content. These authored panels contain only live aquarium records.
    page.children.extend([
        rounded_panel("ExploreSidebar", 42, 132, 350, 790, z=5, transparency=0.12),
        rounded_panel("ExploreContentPanel", 408, 132, 1220, 790, z=5, transparency=0.12),
    ])

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
        ("FriendsButton", "●●   Friends", 442, 88, False),
        ("RandomButton", "⤨   Random", 542, 88, False),
    ]
    for name, title, y, h, selected in nav:
        page.children.append(rounded_panel(name + "Panel", 55, y, 320, h, z=7, transparency=0.10))
        page.children.append(image_node(
            name.removesuffix("Button") + "Selected",
            ASSET["selected_tab"],
            55,
            y,
            320,
            h,
            z=9,
            rect=(70, 331, 1302, 398),
            visible=selected,
        ))
        page.children.append(text_node(name + "Label", title, 78, y + 12, 275, h - 24, size=28, z=13))
        page.children.append(transparent_button(name, 55, y, 320, h, z=20))

    page.children.append(image_node(
        "VisitRandomSelected",
        ASSET["selected_tab"],
        55,
        654,
        320,
        104,
        z=9,
        rect=(70, 331, 1302, 398),
    ))
    page.children.append(text_node("VisitRandomLabel", "◇   Visit Random\n      Aquarium", 78, 665, 275, 80, size=27, z=13, wrapped=True))
    page.children.append(transparent_button("VisitRandomButton", 55, 654, 320, 104, z=20))
    page.children.append(text_node("ExploreHeading", "FEATURED AQUARIUMS", 442, 145, 540, 46, size=32, text_color=CYAN, z=12))

    visitor_list = make_scrolling("ExploreVisitorList", 420, 190, 1182, 724, z=6, dark=True)
    visitor_list.children.append(list_layout(8))
    page.children.append(visitor_list)
    page.children.append(text_node("ExploreEmptyMessage", "No matching aquariums are online right now.", 575, 490, 850, 55, size=28, align=2, z=14))

    scroll_track = image_node("ExploreScrollTrack", ASSET["scroll"], 1602, 193, 28, 718, z=12, rect=(683, 29, 65, 1021))
    explore_channel = image_node("ScrollbarChannel", ASSET["scroll"], 0, 0, 1, 1, z=12, rect=(701, 914, 30, 90))
    explore_channel.props["Position"] = udim2(0.28, 0, 0.05, 0)
    explore_channel.props["Size"] = udim2(0.44, 0, 0.82, 0)
    scroll_track.children.append(explore_channel)
    scroll_thumb = image_node("ExploreScrollThumb", ASSET["scroll"], 7, 0, 14, 120, z=13, rect=(701, 77, 30, 825))
    scroll_track.children.append(scroll_thumb)
    page.children.append(scroll_track)
    return page


def make_header() -> Node:
    header = frame("Header", transparency=1, zindex=40)
    header.children.append(image_node("CoralIcon", ASSET["coral"], 50, 32, 114, 92, z=42, rect=(93, 100, 1103, 955)))
    header.children.append(text_node("AquariumTitle", "Aquarium", 181, 42, 320, 78, size=64, z=43))

    my_base = rounded_panel("MyTankTabBase", 513, 41, 300, 84, z=41, transparency=0.08)
    explore_base = rounded_panel("ExploreTabBase", 837, 41, 267, 84, z=41, transparency=0.08)
    header.children.extend([my_base, explore_base])
    header.children.append(image_node("MyTankSelected", ASSET["selected_tab"], 513, 40, 300, 86, z=42, rect=(70, 331, 1302, 398)))
    header.children.append(image_node("ExploreSelected", ASSET["selected_tab"], 836, 40, 269, 86, z=42, rect=(70, 331, 1302, 398), visible=False))
    header.children.append(text_node("MyTankText", "My Tank", 548, 55, 232, 58, size=43, align=2, z=44))
    header.children.append(text_node("ExploreText", "Explore", 861, 55, 220, 58, size=43, align=2, z=44))
    header.children.append(transparent_button("MyTankButton", 513, 40, 300, 86, z=50))
    header.children.append(transparent_button("ExploreButton", 836, 40, 269, 86, z=50))
    header.children.append(image_node("CloseButton", ASSET["close"], 1514, 35, 98, 93, z=46, rect=(375, 422, 427, 439), button=True))
    return header


def make_fish_template() -> Node:
    row = frame("MyTankFishRowTemplate", size=udim2(1, -10, 0, 132), transparency=1, visible=False, zindex=7)
    # The source PNG has a few nearly-transparent pixels across the full canvas.
    # Crop to the actual framed card instead of that alpha noise; otherwise the
    # frame is compressed into the thin line seen in Studio.
    row.children.append(image_node("RowArtwork", ASSET["fish_tab"], 0, 0, 1450, 132, z=7, rect=(28, 380, 1480, 171)))
    # fish_panel already contains the complete portrait frame. Keep its parent
    # as a clipping container only so a second generated border is not stacked
    # beneath the artwork.
    portrait = frame(
        "Portrait",
        position=udim2(0, 15, 0, 22),
        size=udim2(0, 132, 0, 88),
        transparency=1,
        zindex=9,
        clips=True,
    )
    portrait.children.append(image_node("PortraitArtwork", ASSET["fish_panel"], 0, 0, 132, 88, z=10, rect=(0, 0, 1534, 1024)))
    fish_image = image_node("FishImage", "", 7, 5, 118, 78, z=11)
    # Runtime fish thumbnails have different source proportions. Fit keeps the
    # fish artwork from being stretched vertically or horizontally.
    fish_image.props["ScaleType"] = prop("token", 3)
    portrait.children.append(fish_image)
    row.children.append(portrait)
    row.children.append(text_node("FishName", "Bluegill", 186, 24, 340, 43, size=38, z=12))
    row.children.append(text_node("Rarity", "Common", 350, 32, 190, 30, size=24, text_color=CYAN, z=12))
    row.children.append(image_node("CoinIcon", ASSET["coin"], 183, 67, 29, 29, z=12, rect=(88, 68, 850, 867)))
    row.children.append(text_node("ValuePrefix", "Value:", 218, 64, 80, 34, size=23, z=12))
    row.children.append(text_node("Value", "0", 294, 64, 75, 34, size=27, text_color=YELLOW, z=12))
    row.children.append(text_node("CoinsSuffix", "coins", 366, 64, 80, 34, size=23, z=12))
    # The capacity artwork crop is approximately 3:4; using a square display
    # area makes the cube look vertically compressed.
    row.children.append(image_node("SpaceIcon", ASSET["capacity"], 635, 26, 60, 80, z=12, rect=(229, 90, 797, 1060)))
    row.children.append(text_node("SpaceUsed", "Space used: 0", 706, 48, 300, 43, size=25, z=12))
    row.children.append(image_node("RemoveArtwork", ASSET["remove"], 1240, 36, 190, 64, z=11, rect=(66, 64, 1793, 647)))
    row.children.append(text_node("RemoveText", "Remove", 1262, 46, 146, 44, size=29, align=2, z=13))
    row.children.append(transparent_button("RemoveButton", 1240, 36, 190, 64, z=20))
    return row


def make_visitor_template() -> Node:
    row = frame("ExploreVisitorRowTemplate", size=udim2(1, -12, 0, 148), transparency=1, visible=False, zindex=7)
    row.props["Size"] = udim2(1, -12, 0, 148)
    row.props["Visible"] = prop("bool", False)
    row.children.append(image_node("RowArtwork", ASSET["fish_tab"], 0, 0, 1158, 148, z=7, rect=(28, 380, 1480, 171)))
    # Match the result-card outline to the portrait outline instead of relying
    # on the thinner border baked into the row artwork.
    row_border = frame(
        "RowBorder",
        position=udim2(0, 2, 0, 2),
        size=udim2(0, 1154, 0, 144),
        transparency=1,
        zindex=8,
    )
    row_border.children.extend([corner(0, 16), stroke(10, 137, 255, 2, 0.08)])
    row.children.append(row_border)

    preview = rounded_panel("Preview", 8, 8, 228, 132, z=9, transparency=0.05)
    preview_fish = image_node("PreviewFish", "", 18, 5, 190, 122, z=11)
    preview_fish.props["ScaleType"] = prop("token", 3)
    preview.children.append(preview_fish)
    row.children.append(preview)
    row.children.append(text_node("PlayerName", "Player", 260, 10, 310, 38, size=30, z=12))
    row.children.append(text_node("OnlineStatus", "● Online", 465, 14, 125, 31, size=20, text_color=(0, 255, 209), z=12))
    row.children.append(text_node("AquariumName", "Level 1 Aquarium", 260, 47, 360, 30, size=21, text_color=(0, 255, 235), z=12))
    row.children.append(text_node("TotalLabel", "Total Value", 260, 75, 145, 27, size=19, text_color=(255, 236, 148), z=12))
    row.children.append(image_node("CoinIcon", ASSET["coin"], 258, 103, 26, 26, z=12, rect=(88, 68, 850, 867)))
    row.children.append(text_node("TotalValue", "0", 288, 96, 160, 37, size=27, text_color=YELLOW, z=12))
    row.children.append(text_node("BestLabel", "Best Fish", 506, 75, 125, 27, size=19, text_color=(255, 236, 148), z=12))
    row.children.append(text_node("BestFish", "None yet", 506, 98, 190, 34, size=22, z=12))
    best_fish_image = image_node("BestFishImage", "", 700, 16, 190, 119, z=11)
    best_fish_image.props["ScaleType"] = prop("token", 3)
    row.children.append(best_fish_image)
    row.children.append(text_node("FishCount", "♡ 0", 904, 14, 220, 40, size=26, z=12))
    row.children.append(transparent_button("LikeButton", 904, 14, 220, 40, z=20))

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

"""Generate the exact authored MainPanel/ShopModernUI hierarchy."""

from pathlib import Path
import runpy


HERE = Path(__file__).resolve().parent
G = runpy.run_path(str(HERE / "generate_models.py"))

Node = G["Node"]
color = G["color"]
corner = G["corner"]
frame = G["frame"]
gui_props = G["gui_props"]
prop = G["prop"]
scale = G["scale"]
size_constraint = G["size_constraint"]
stroke = G["stroke"]
udim = G["udim"]
udim2 = G["udim2"]
vec2 = G["vec2"]
write_model = G["write_model"]


ASSETS = {
    "MainBackbone": "rbxassetid://77079984837491",
    "SubMainBackbone": "rbxassetid://120182750042631",
    "IndividualUITab": "rbxassetid://127925036253260",
    "SectionTab": "rbxassetid://131015417525927",
    "SectionTabSelected": "rbxassetid://83228267224190",
    "BlueButton": "rbxassetid://125521996931477",
    "GreenButton": "rbxassetid://137614054152455",
    "RedButton": "rbxassetid://79554836514436",
    "ScrollBar": "rbxassetid://73367138577137",
    "CloseButton": "rbxassetid://119322438066977",
    "DecorationCastle": "rbxassetid://120613246130409",
    "SeaStar": "rbxassetid://139079837785295",
    "AquariumViewerButton": "rbxassetid://114227393517533",
}

CROPS = {
    "MainBackbone": ((1448, 1086), (33, 24), (1382, 1019)),
    "SubMainBackbone": ((1448, 1086), (43, 176), (1362, 763)),
    "IndividualUITab": ((1448, 1086), (10, 355), (1428, 277)),
    "SectionTab": ((1254, 1254), (70, 460), (1115, 353)),
    "SectionTabSelected": ((1254, 1254), (49, 468), (1156, 328)),
    "BlueButton": ((1254, 1254), (117, 480), (1015, 372)),
    "GreenButton": ((1254, 1254), (117, 480), (1015, 372)),
    "RedButton": ((1254, 1254), (119, 479), (1011, 375)),
    "ScrollBar": ((1448, 1086), (683, 29), (65, 1021)),
    "ScrollBarThumb": ((1448, 1086), (701, 77), (30, 825)),
    "ScrollBarChannel": ((1448, 1086), (701, 914), (30, 90)),
    "CloseButton": ((1187, 1326), (375, 422), (427, 439)),
    "DecorationCastle": ((632, 432), (173, 66), (255, 250)),
}


def text_node(
    name,
    text,
    text_size,
    text_color,
    bold,
    position,
    size,
    zindex,
    *,
    visible=True,
    align=0,
    valign=1,
    wrapped=False,
    scaled=False,
    stroke_transparency=1,
):
    return Node(
        "TextLabel",
        name,
        {
            **gui_props(
                position=position,
                size=size,
                transparency=1,
                visible=visible,
                zindex=zindex,
            ),
            "Font": prop("token", 19 if bold else 17),
            "Text": prop("string", text),
            "TextColor3": color(*text_color),
            "TextScaled": prop("bool", scaled),
            "TextSize": prop("float", text_size),
            "TextStrokeColor3": color(3, 18, 44),
            "TextStrokeTransparency": prop("float", stroke_transparency),
            "TextTransparency": prop("float", 0),
            "TextWrapped": prop("bool", wrapped),
            "TextXAlignment": prop("token", align),
            "TextYAlignment": prop("token", valign),
        },
    )


def artwork(asset_key):
    source, offset, crop_size = CROPS[asset_key]
    return Node(
        "ImageLabel",
        "Artwork",
        {
            **gui_props(
                position=udim2(
                    -offset[0] / crop_size[0],
                    0,
                    -offset[1] / crop_size[1],
                    0,
                ),
                size=udim2(
                    source[0] / crop_size[0],
                    0,
                    source[1] / crop_size[1],
                    0,
                ),
                transparency=1,
                zindex=202,
            ),
            "Image": prop("Content", ASSETS[asset_key]),
            "ImageTransparency": prop("float", 0),
            "ScaleType": prop("token", 0),
        },
    )


def image_holder(name, asset_key, position, size, zindex, *, button=False, visible=True):
    class_name = "ImageButton" if button else "Frame"
    props = gui_props(
        position=position,
        size=size,
        transparency=1,
        visible=visible,
        zindex=zindex,
        clips=True,
    )
    if button:
        props.update(
            {
                "Active": prop("bool", True),
                "AutoButtonColor": prop("bool", False),
                "Image": prop("Content", ""),
                "Selectable": prop("bool", True),
            }
        )
    node = Node(class_name, name, props)
    art = artwork(asset_key)
    art.props["ZIndex"] = prop("int", zindex)
    node.children.append(art)
    return node


def action_image_button(name="ActionButton", *, visible=True):
    node = image_holder(
        name,
        "GreenButton",
        udim2(1, -258, 0.5, -43),
        udim2(0, 235, 0, 86),
        214,
        button=True,
        visible=visible,
    )
    node.children.append(
        text_node(
            "Label",
            "Buy",
            34,
            (255, 255, 255),
            True,
            udim2(0.5, 0, 0.5, 0),
            udim2(1, -32, 1, -18),
            218,
            align=2,
        )
    )
    node.children[-1].props["AnchorPoint"] = vec2(0.5, 0.5)

    # Keep every action-state skin authored in the template model. The
    # controller swaps the primary Artwork image for the active state, while
    # these hidden variants make the complete original skin self-contained in
    # StarterGui (and allow Studio to preload all three images).
    for asset_key in ("BlueButton", "RedButton"):
        variant = artwork(asset_key)
        variant.name = asset_key + "Artwork"
        variant.props["Visible"] = prop("bool", False)
        variant.props["ZIndex"] = prop("int", 214)
        node.children.append(variant)
    return node


def tab_template():
    node = image_holder(
        "ShopTabTemplate",
        "SectionTab",
        udim2(0, 0, 0, 0),
        udim2(0, 316, 0, 78),
        210,
        button=True,
        visible=False,
    )
    node.children.append(
        text_node(
            "Label",
            "Tab",
            34,
            (255, 255, 255),
            True,
            udim2(0.5, 0, 0.5, 0),
            udim2(1, -28, 1, -20),
            215,
            align=2,
        )
    )
    node.children[-1].props["AnchorPoint"] = vec2(0.5, 0.5)
    return node


def image_row_template():
    holder = frame(
        "ShopItemCardTemplate",
        size=udim2(1, -6, 0, 176),
        transparency=1,
        visible=False,
        zindex=207,
    )
    row_art = image_holder(
        "RowArtwork",
        "IndividualUITab",
        udim2(0, 0, 0, 0),
        udim2(1, 0, 1, 0),
        207,
    )
    holder.children.extend(
        [
            row_art,
            text_node("Title", "Item", 38, (255, 255, 255), True, udim2(0, 228, 0, 24), udim2(1, -520, 0, 48), 216),
            text_node("Description", "", 23, (178, 194, 235), True, udim2(0, 228, 0, 74), udim2(1, -520, 0, 32), 216, stroke_transparency=0.35),
            text_node("Price", "", 24, (255, 216, 59), True, udim2(0, 228, 0, 110), udim2(1, -520, 0, 32), 216),
            action_image_button(),
        ]
    )
    return holder


def product_template():
    holder = frame(
        "ProductCardTemplate",
        size=udim2(1, -6, 0, 158),
        background=color(5, 47, 91),
        transparency=0.04,
        visible=False,
        zindex=207,
    )
    icon = Node(
        "ImageLabel",
        "Icon",
        {
            **gui_props(
                position=udim2(0, 34, 0.5, 0),
                size=udim2(0, 112, 0, 112),
                anchor=vec2(0, 0.5),
                transparency=1,
                zindex=212,
            ),
            "Image": prop("Content", ASSETS["SeaStar"]),
            "ScaleType": prop("token", 3),
        },
    )
    action = Node(
        "TextButton",
        "ActionButton",
        {
            **gui_props(
                position=udim2(1, -30, 0.5, 0),
                size=udim2(0, 238, 0, 68),
                anchor=vec2(1, 0.5),
                background=color(20, 176, 102),
                transparency=0.02,
                zindex=214,
            ),
            "Active": prop("bool", True),
            "AutoButtonColor": prop("bool", False),
            "Font": prop("token", 19),
            "Selectable": prop("bool", True),
            "Text": prop("string", "Buy"),
            "TextColor3": color(255, 255, 255),
            "TextScaled": prop("bool", True),
            "TextSize": prop("float", 14),
            "TextStrokeColor3": color(3, 18, 44),
            "TextStrokeTransparency": prop("float", 0.12),
        },
    )
    action.children.extend([corner(0, 15), stroke(67, 255, 173, 2, 0.12)])
    holder.children.extend(
        [
            corner(0, 17),
            stroke(20, 128, 255, 3, 0.08),
            icon,
            text_node("Title", "Product", 30, (255, 255, 255), True, udim2(0, 174, 0, 18), udim2(1, -486, 0, 42), 213, wrapped=True, stroke_transparency=0.15),
            text_node("Description", "", 21, (178, 194, 235), True, udim2(0, 174, 0, 61), udim2(1, -486, 0, 40), 213, valign=0, wrapped=True, stroke_transparency=0.35),
            text_node("Value", "", 23, (255, 216, 59), True, udim2(0, 174, 0, 108), udim2(1, -486, 0, 32), 213, wrapped=True, stroke_transparency=0.15),
            action,
        ]
    )
    return holder


def summary_template():
    holder = frame(
        "StatRowTemplate",
        size=udim2(1, -6, 0, 122),
        background=color(4, 23, 57),
        transparency=0.10,
        visible=False,
        zindex=207,
    )
    holder.children.extend(
        [
            corner(0, 17),
            stroke(0, 105, 238, 2, 0.18),
            text_node("Title", "Summary", 34, (255, 255, 255), True, udim2(0, 28, 0, 18), udim2(1, -56, 0, 44), 216),
            text_node("Detail", "", 25, (181, 197, 235), False, udim2(0, 28, 0, 67), udim2(1, -56, 0, 34), 216),
        ]
    )
    return holder


def legacy_button(name, text, position, size, visible=False):
    node = Node(
        "TextButton",
        name,
        {
            **gui_props(
                position=position,
                size=size,
                background=color(91, 104, 124),
                transparency=0,
                visible=visible,
                zindex=51,
            ),
            "AutoButtonColor": prop("bool", True),
            "Font": prop("token", 19),
            "Text": prop("string", text),
            "TextColor3": color(255, 255, 255),
            "TextSize": prop("float", 14),
        },
    )
    node.children.extend([corner(0, 7), stroke(255, 255, 255, 1, 0.85)])
    return node


def legacy_content_text(
    name,
    text,
    text_size,
    text_color,
    bold,
    position,
    size,
    *,
    align=0,
):
    """Match GuiPrimitives.makeText for authored legacy MainPanel cards."""
    return text_node(
        name,
        text,
        text_size,
        text_color,
        bold,
        position,
        size,
        1,
        align=align,
        stroke_transparency=1,
    )


def legacy_content_button(name, text, background, position, size, *, text_size=14):
    """Match GuiPrimitives.makeButton without constructing it at runtime."""
    props = gui_props(
        position=position,
        size=size,
        background=color(*background),
        transparency=0,
        visible=True,
        zindex=1,
    )
    # GuiPrimitives did not override Roblox's one-pixel GuiObject border.
    props["BorderSizePixel"] = prop("int", 1)
    props["BorderColor3"] = color(27, 42, 53)
    props.update(
        {
            "Active": prop("bool", True),
            "AutoButtonColor": prop("bool", True),
            "Font": prop("token", 19),
            "Selectable": prop("bool", True),
            "Text": prop("string", text),
            "TextColor3": color(255, 255, 255),
            "TextSize": prop("float", text_size),
            "TextStrokeTransparency": prop("float", 1),
            "TextTransparency": prop("float", 0),
            "TextXAlignment": prop("token", 1),
            "TextYAlignment": prop("token", 1),
        }
    )
    node = Node("TextButton", name, props)
    node.children.extend(
        [
            corner(0, 7, "ButtonCorner"),
            stroke(255, 255, 255, 1, 0.85, "ButtonStroke"),
        ]
    )
    return node


def legacy_card_template(name, height):
    """Return the exact CardRow/Card skeleton used by the v1615 MainPanel."""
    wrapper = frame(
        name,
        size=udim2(1, 0, 0, height),
        transparency=1,
        visible=False,
        zindex=1,
    )
    card = frame(
        "Card",
        position=udim2(0, 6, 0, 1),
        size=udim2(1, -12, 1, -2),
        background=color(27, 33, 43),
        transparency=0,
        zindex=1,
    )
    card.props["BorderSizePixel"] = prop("int", 1)
    card.props["BorderColor3"] = color(27, 42, 53)
    border = stroke(60, 72, 90, 1, 0, "Border")
    border.props["ApplyStrokeMode"] = prop("token", 1)
    card.children.extend([corner(0, 8, "CardCorner"), border])
    wrapper.children.append(card)
    return wrapper, card


def legacy_main_panel_templates():
    templates = []

    aquarium_summary, card = legacy_card_template("AquariumSummaryTemplate", 96)
    card.children.extend(
        [
            legacy_content_text("Heading", "My Aquarium", 17, (255, 255, 255), True, udim2(0, 12, 0, 8), udim2(1, -24, 0, 24)),
            legacy_content_text("Info", "Level 1 | Space 0/0", 14, (190, 204, 220), False, udim2(0, 12, 0, 36), udim2(1, -24, 0, 22)),
            legacy_content_text("Best", "Best: None yet", 13, (143, 160, 180), False, udim2(0, 12, 0, 60), udim2(1, -184, 0, 20)),
            legacy_content_button("UpgradeButton", "Upgrade", (28, 160, 92), udim2(1, -162, 0, 58), udim2(0, 150, 0, 28)),
        ]
    )
    templates.append(aquarium_summary)

    aquarium_fish, card = legacy_card_template("AquariumFishTemplate", 62)
    card.children.extend(
        [
            legacy_content_text("Name", "1. Fish [Common]", 14, (255, 255, 255), True, udim2(0, 12, 0, 6), udim2(1, -118, 0, 20)),
            legacy_content_text("Value", "Value: 0 coins | Space: 1", 12, (190, 204, 220), False, udim2(0, 12, 0, 26), udim2(1, -118, 0, 16)),
            legacy_content_button("RemoveButton", "Remove", (230, 126, 48), udim2(1, -94, 0, 15), udim2(0, 78, 0, 32), text_size=12),
        ]
    )
    templates.append(aquarium_fish)

    hub_header, card = legacy_card_template("AquariumHubHeaderTemplate", 84)
    card.children.extend(
        [
            legacy_content_text("Heading", "Aquarium Hub", 17, (255, 255, 255), True, udim2(0, 12, 0, 8), udim2(1, -24, 0, 24)),
            legacy_content_text("Info", "Choose one aquarium to load into the main hub tank.", 13, (190, 204, 220), False, udim2(0, 12, 0, 38), udim2(1, -24, 0, 22)),
        ]
    )
    templates.append(hub_header)

    directory, card = legacy_card_template("AquariumDirectoryTemplate", 204)
    card.children.extend(
        [
            legacy_content_text("DirectoryTitle", "Directory", 15, (255, 255, 255), True, udim2(0, 12, 0, 8), udim2(1, -24, 0, 20)),
            legacy_content_button("MyAquariumButton", "My Aquarium", (53, 130, 246), udim2(0, 12, 0, 36), udim2(0.5, -18, 0, 32), text_size=12),
            legacy_content_button("FriendsButton", "Friends", (38, 145, 118), udim2(0.5, 6, 0, 36), udim2(0.5, -18, 0, 32), text_size=12),
            legacy_content_button("FeaturedButton", "Featured", (86, 118, 220), udim2(0, 12, 0, 74), udim2(0.5, -18, 0, 32), text_size=12),
            legacy_content_button("MostLikedButton", "Most Liked", (225, 156, 58), udim2(0.5, 6, 0, 74), udim2(0.5, -18, 0, 32), text_size=12),
            legacy_content_button("RandomPublicButton", "Random Public", (55, 170, 190), udim2(0, 12, 0, 112), udim2(0.5, -18, 0, 32), text_size=12),
            legacy_content_button("SearchPlayerButton", "Search Player", (196, 95, 128), udim2(0.5, 6, 0, 112), udim2(0.5, -18, 0, 32), text_size=12),
            legacy_content_button("ReturnButton", "Return to Seaside Island", (38, 45, 57), udim2(0, 12, 0, 150), udim2(1, -24, 0, 32), text_size=12),
        ]
    )
    templates.append(directory)

    empty, card = legacy_card_template("AquariumEmptyTemplate", 64)
    card.children.append(
        legacy_content_text("Message", "No aquariums are ready yet.", 15, (190, 204, 220), True, udim2(0, 12, 0, 16), udim2(1, -24, 0, 24))
    )
    templates.append(empty)

    visitor, card = legacy_card_template("AquariumVisitorTemplate", 92)
    card.children.extend(
        [
            legacy_content_text("Name", "Player", 16, (255, 255, 255), True, udim2(0, 12, 0, 8), udim2(1, -122, 0, 22)),
            legacy_content_text("Detail", "Online | Level 1 | Fish 0 | Space 0/0", 13, (190, 204, 220), False, udim2(0, 12, 0, 34), udim2(1, -122, 0, 20)),
            legacy_content_text("Best", "Best: None yet", 12, (143, 160, 180), False, udim2(0, 12, 0, 56), udim2(1, -122, 0, 18)),
            legacy_content_button("VisitButton", "Visit", (53, 130, 246), udim2(1, -102, 0, 28), udim2(0, 86, 0, 36), text_size=13),
        ]
    )
    templates.append(visitor)

    loading = legacy_content_text("LoadingLabelTemplate", "Loading player data...", 16, (255, 255, 255), True, udim2(0, 0, 0, 0), udim2(1, -8, 0, 40))
    loading.props["Visible"] = prop("bool", False)
    templates.append(loading)

    return Node("Folder", "LegacyMainPanelTemplates", {}, templates)


def make_aquarium_viewer_fallback_button():
    button = legacy_content_button(
        "AquariumViewerFallbackButton",
        "",
        (53, 130, 246),
        udim2(1, -18, 0, 160),
        udim2(0, 210, 0, 53),
        text_size=14,
    )
    button.props["AnchorPoint"] = vec2(1, 0)
    button.props["AutoButtonColor"] = prop("bool", False)
    button.props["BackgroundTransparency"] = prop("float", 1)
    button.props["BorderSizePixel"] = prop("int", 0)
    button.props["Visible"] = prop("bool", False)
    button.props["ZIndex"] = prop("int", 31)
    button.children = [
        Node(
            "ImageLabel",
            "ButtonArtwork",
            {
                **gui_props(
                    position=udim2(0.5, 0, 0.5, 0),
                    size=udim2(0.94924, 0, 1.01318, 0),
                    transparency=1,
                    zindex=31,
                ),
                # The Viewer upload has wider transparent edge padding than the
                # Editor upload. Centering this visual-only correction makes the
                # two visible outer frames exactly the same size.
                "AnchorPoint": vec2(0.5, 0.5),
                "Image": prop("Content", ASSETS["AquariumViewerButton"]),
                "ImageTransparency": prop("float", 0),
                "ScaleType": prop("token", 0),
            },
        )
    ]
    return button


def make_main_panel():
    root = frame(
        "MainPanel",
        position=udim2(0.5, 0, 0.52, 0),
        size=udim2(0.42, 0, 0.64, 0),
        anchor=vec2(0.5, 0.5),
        background=color(18, 22, 29),
        transparency=0.04,
        visible=False,
        zindex=50,
    )
    root.children.extend(
        [
            corner(0, 8),
            stroke(71, 85, 105, 1, 0),
            size_constraint(330, 360, 560, 580, "PanelSizeConstraint"),
            text_node("PanelTitle", "Fishdex", 20, (255, 255, 255), True, udim2(0, 18, 0, 12), udim2(1, -86, 0, 30), 51),
            legacy_button("PanelClose", "X", udim2(1, -50, 0, 12), udim2(0, 32, 0, 30), visible=True),
            legacy_button("PanelToggle", ">", udim2(0, 0, 0, 0), udim2(0, 0, 0, 0)),
        ]
    )

    legacy_tabs = frame(
        "Tabs",
        position=udim2(0, 12, 0, 12),
        size=udim2(1, -24, 0, 0),
        transparency=1,
        visible=False,
        zindex=51,
    )
    legacy_tabs.children.append(
        Node(
            "UIGridLayout",
            "UIGridLayout",
            {
                "CellPadding": udim2(0, 7, 0, 7),
                "CellSize": udim2(0, 96, 0, 32),
                "SortOrder": prop("token", 2),
            },
        )
    )
    root.children.append(legacy_tabs)

    canvas = frame(
        "ShopCanvas",
        position=udim2(0.5, 0, 0.4, 0),
        size=udim2(0, 1448, 0, 1086),
        anchor=vec2(0.5, 0.5),
        transparency=1,
        visible=False,
        zindex=200,
    )
    canvas.children.append(scale("ModernShopScale", 0.36))

    skin = frame("ModernShopSkin", transparency=1, zindex=201)
    skin.children.extend(
        [
            image_holder("MainBackbone", "MainBackbone", udim2(0, 0, 0, 0), udim2(0, 1448, 0, 1086), 201),
            image_holder("SubMainBackbone", "SubMainBackbone", udim2(0, 34, 0, 148), udim2(0, 1380, 0, 890), 202),
            image_holder("DecorationCastle", "DecorationCastle", udim2(0, 50, 0, 18), udim2(0, 184, 0, 132), 206),
            text_node("Title", "SHOP", 72, (255, 255, 255), True, udim2(0, 252, 0, 34), udim2(0, 560, 0, 100), 207),
            image_holder("ModernShopClose", "CloseButton", udim2(0, 1285, 0, 35), udim2(0, 105, 0, 105), 212, button=True),
        ]
    )

    tabs = frame(
        "ModernShopTabs",
        position=udim2(0, 63, 0, 166),
        size=udim2(0, 1297, 0, 82),
        transparency=1,
        zindex=208,
    )
    tabs.children.append(
        Node(
            "UIListLayout",
            "UIListLayout",
            {
                "FillDirection": prop("token", 0),
                "HorizontalAlignment": prop("token", 0),
                "VerticalAlignment": prop("token", 1),
                "Padding": udim(0, 11),
                "SortOrder": prop("token", 2),
            },
        )
    )
    skin.children.append(tabs)

    scroll_track = frame(
        "ModernShopScrollTrack",
        position=udim2(0, 1333, 0, 264),
        size=udim2(0, 28, 0, 738),
        background=color(1, 19, 55),
        transparency=1,
        zindex=210,
    )
    scroll_track.props["Active"] = prop("bool", True)
    scroll_track_art = artwork("ScrollBar")
    scroll_track_art.props["ZIndex"] = prop("int", 210)
    scroll_track.children.extend(
        [
            corner(0, 28),
            stroke(0, 82, 190, 2, 1),
            scroll_track_art,
            image_holder("ScrollbarChannel", "ScrollBarChannel", udim2(0.28, 0, 0.05, 0), udim2(0.44, 0, 0.82, 0), 211),
            image_holder("ModernShopScrollThumb", "ScrollBarThumb", udim2(0, 7, 0, 0), udim2(0, 14, 0, 210), 213, button=True),
        ]
    )
    skin.children.append(scroll_track)
    canvas.children.append(skin)

    content = Node(
        "ScrollingFrame",
        "Content",
        {
            **gui_props(
                position=udim2(0, 12, 0, 54),
                size=udim2(1, -24, 1, -66),
                transparency=1,
                zindex=51,
                clips=True,
            ),
            "Active": prop("bool", True),
            "AutomaticCanvasSize": prop("token", 2),
            "CanvasSize": udim2(0, 0, 0, 0),
            "ScrollBarImageTransparency": prop("float", 0),
            # v1615 uses the blue authored scrollbar at the right edge. Keep
            # Roblox's native bar disabled in both Editor and Play.
            "ScrollBarThickness": prop("int", 0),
            "ScrollingDirection": prop("token", 2),
            "ScrollingEnabled": prop("bool", True),
            "VerticalScrollBarInset": prop("token", 0),
        },
    )
    content.children.extend(
        [
            Node(
                "UIListLayout",
                "UIListLayout",
                {
                    "FillDirection": prop("token", 1),
                    "HorizontalAlignment": prop("token", 0),
                    "Padding": udim(0, 8),
                    "SortOrder": prop("token", 2),
                },
            ),
            Node(
                "UIPadding",
                "UIPadding",
                {
                    "PaddingTop": udim(0, 0),
                    "PaddingBottom": udim(0, 0),
                    "PaddingLeft": udim(0, 0),
                    "PaddingRight": udim(0, 0),
                },
            ),
        ]
    )
    root.children.append(canvas)
    root.children.append(content)

    root.children.append(
        Node(
            "Folder",
            "ShopTemplates",
            {},
            [
                tab_template(),
                image_row_template(),
                product_template(),
                summary_template(),
            ],
        )
    )
    root.children.append(legacy_main_panel_templates())
    return root


if __name__ == "__main__":
    write_model(HERE / "MainPanel.rbxmx", make_main_panel())
    write_model(
        HERE / "AquariumViewerFallbackButton.rbxmx",
        make_aquarium_viewer_fallback_button(),
    )

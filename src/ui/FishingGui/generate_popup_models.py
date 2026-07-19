"""Generate the exact authored Fishmonger and compact Supply Shop popups."""

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
stroke = G["stroke"]
udim = G["udim"]
udim2 = G["udim2"]
vec2 = G["vec2"]
write_model = G["write_model"]


def popup_text(
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
    wrapped=False,
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
            "TextScaled": prop("bool", False),
            "TextSize": prop("float", text_size),
            "TextStrokeTransparency": prop("float", 1),
            "TextTransparency": prop("float", 0),
            "TextWrapped": prop("bool", wrapped),
            "TextXAlignment": prop("token", 0),
            "TextYAlignment": prop("token", 1),
        },
    )


def popup_button(
    name,
    text,
    background,
    position,
    size,
    zindex,
    *,
    text_size=14,
    visible=True,
):
    node = Node(
        "TextButton",
        name,
        {
            **gui_props(
                position=position,
                size=size,
                background=color(*background),
                transparency=0,
                visible=visible,
                zindex=zindex,
            ),
            "AutoButtonColor": prop("bool", True),
            "Font": prop("token", 19),
            "Text": prop("string", text),
            "TextColor3": color(255, 255, 255),
            "TextScaled": prop("bool", False),
            "TextSize": prop("float", text_size),
            "TextStrokeTransparency": prop("float", 1),
            "TextTransparency": prop("float", 0),
            "TextWrapped": prop("bool", False),
            "TextXAlignment": prop("token", 1),
            "TextYAlignment": prop("token", 1),
        },
    )
    node.children.extend([corner(0, 7), stroke(255, 255, 255, 1, 0.85)])
    return node


def vertical_list(name, position, size):
    node = Node(
        "ScrollingFrame",
        name,
        {
            **gui_props(
                position=position,
                size=size,
                transparency=1,
                zindex=97,
                clips=True,
            ),
            "Active": prop("bool", True),
            "AutomaticCanvasSize": prop("token", 2),
            "CanvasSize": udim2(0, 0, 0, 0),
            "ScrollBarThickness": prop("int", 6),
        },
    )
    node.children.append(
        Node(
            "UIListLayout",
            "UIListLayout",
            {
                "FillDirection": prop("token", 1),
                "Padding": udim(0, 10),
                "SortOrder": prop("token", 2),
            },
        )
    )
    return node


def horizontal_bar(name, position, size):
    node = frame(
        name,
        position=position,
        size=size,
        transparency=1,
        zindex=97,
    )
    node.children.append(
        Node(
            "UIListLayout",
            "UIListLayout",
            {
                "FillDirection": prop("token", 0),
                "Padding": udim(0, 7 if name == "FishmongerSortBar" else 8),
                "SortOrder": prop("token", 2),
            },
        )
    )
    return node


def popup_icon(name, position, size, zindex):
    node = frame(
        name,
        position=position,
        size=size,
        background=color(21, 28, 38),
        transparency=0,
        zindex=zindex,
    )
    node.children.extend(
        [
            corner(0, 6),
            stroke(130, 146, 166, 1, 0.2, "Border"),
            Node(
                "ImageLabel",
                "Image",
                {
                    **gui_props(transparency=1, zindex=zindex + 1),
                    "Image": prop("Content", ""),
                    "ScaleType": prop("token", 3),
                },
            ),
            popup_text(
                "Fallback",
                "FISH",
                12,
                (130, 146, 166),
                True,
                udim2(0, 0, 0, 0),
                udim2(1, 0, 1, 0),
                zindex + 1,
                visible=False,
            ),
        ]
    )
    node.children[-1].props["TextXAlignment"] = prop("token", 1)
    return node


def popup_card_template(name, height, children):
    row = frame(
        name,
        size=udim2(1, -18, 0, height),
        transparency=1,
        visible=False,
        zindex=97,
    )
    card = frame(
        "Card",
        position=udim2(0, 6, 0, 1),
        size=udim2(1, -12, 1, -2),
        background=color(24, 32, 44),
        transparency=0,
        zindex=97,
    )
    border = stroke(83, 104, 134, 1, 0.25, "Border")
    border.props["ApplyStrokeMode"] = prop("token", 1)
    card.children.extend(
        [
            corner(0, 8),
            border,
            *children,
        ]
    )
    row.children.append(card)
    return row


def templates_folder(*children):
    return Node("Folder", "Templates", {}, list(children))


def make_fishmonger():
    overlay = frame(
        "FishmongerSellOverlay",
        background=color(0, 0, 0),
        transparency=0.35,
        visible=False,
        zindex=95,
    )
    panel = frame(
        "FishmongerSellPanel",
        position=udim2(0.5, 0, 0.5, 0),
        size=udim2(0, 460, 0, 460),
        anchor=vec2(0.5, 0.5),
        background=color(17, 24, 34),
        transparency=0,
        zindex=96,
    )
    panel.children.extend(
        [
            corner(0, 8),
            stroke(108, 78, 48, 1, 0, "Border"),
            popup_text(
                "Title",
                "Sell Fish",
                20,
                (255, 255, 255),
                True,
                udim2(0, 18, 0, 12),
                udim2(1, -176, 0, 28),
                97,
            ),
            popup_button(
                "SellAllButton",
                "Sell All",
                (230, 126, 48),
                udim2(1, -146, 0, 12),
                udim2(0, 90, 0, 28),
                97,
                text_size=13,
            ),
            popup_button(
                "CloseButton",
                "X",
                (91, 104, 124),
                udim2(1, -48, 0, 12),
                udim2(0, 32, 0, 28),
                97,
            ),
            horizontal_bar(
                "FishmongerSortBar",
                udim2(0, 16, 0, 52),
                udim2(1, -32, 0, 34),
            ),
            vertical_list(
                "FishmongerSellList",
                udim2(0, 16, 0, 94),
                udim2(1, -32, 1, -110),
            ),
        ]
    )

    sell_card = popup_card_template(
        "FishSellRowTemplate",
        82,
        [
            popup_icon("Icon", udim2(0, 8, 0, 12), udim2(0, 58, 0, 58), 98),
            popup_text("Name", "Fish [Rarity]", 15, (255, 255, 255), True, udim2(0, 76, 0, 10), udim2(1, -182, 0, 24), 98),
            popup_text("Info", "Sell value: 0 coins", 13, (190, 204, 220), False, udim2(0, 76, 0, 40), udim2(1, -182, 0, 20), 98),
            popup_button("SellButton", "Sell", (230, 126, 48), udim2(1, -92, 0, 23), udim2(0, 76, 0, 34), 98, text_size=13),
        ],
    )
    sort_template = popup_button(
        "SortButtonTemplate",
        "Sort",
        (38, 45, 57),
        udim2(0, 0, 0, 0),
        udim2(0, 132, 1, 0),
        98,
        text_size=13,
        visible=False,
    )
    empty_template = popup_text(
        "EmptyStateTemplate",
        "No fish in your bag.",
        16,
        (190, 204, 220),
        True,
        udim2(0, 0, 0, 0),
        udim2(1, -8, 0, 54),
        98,
        visible=False,
    )
    panel.children.append(templates_folder(sort_template, empty_template, sell_card))
    overlay.children.append(panel)
    return overlay


def make_rod_shop():
    overlay = frame(
        "RodShopOverlay",
        background=color(0, 0, 0),
        transparency=0.35,
        visible=False,
        zindex=95,
    )
    panel = frame(
        "RodShopPanel",
        position=udim2(0.5, 0, 0.5, 0),
        size=udim2(0, 520, 0, 500),
        anchor=vec2(0.5, 0.5),
        background=color(17, 24, 34),
        transparency=0,
        zindex=96,
    )
    panel.children.extend(
        [
            corner(0, 8),
            stroke(70, 94, 134, 1, 0, "Border"),
            popup_text("Title", "Supply Shop", 20, (255, 255, 255), True, udim2(0, 18, 0, 12), udim2(1, -72, 0, 28), 97),
            popup_button("CloseButton", "X", (91, 104, 124), udim2(1, -48, 0, 12), udim2(0, 32, 0, 28), 97),
            horizontal_bar("SupplyShopTabs", udim2(0, 16, 0, 52), udim2(1, -32, 0, 34)),
            vertical_list("RodShopList", udim2(0, 16, 0, 94), udim2(1, -32, 1, -110)),
        ]
    )

    rod_card = popup_card_template(
        "RodRowTemplate",
        136,
        [
            popup_icon("Icon", udim2(0, 8, 0, 28), udim2(0, 72, 0, 72), 98),
            popup_text("Name", "Rod", 16, (255, 255, 255), True, udim2(0, 84, 0, 10), udim2(1, -208, 0, 22), 98),
            popup_text("Info", "Requirements", 13, (190, 204, 220), False, udim2(0, 84, 0, 34), udim2(1, -208, 0, 20), 98),
            popup_text("Previous", "Previous", 12, (143, 160, 180), False, udim2(0, 84, 0, 57), udim2(1, -208, 0, 18), 98),
            popup_text("Resource", "Resources", 12, (143, 160, 180), False, udim2(0, 84, 0, 78), udim2(1, -208, 0, 18), 98),
            popup_text("Status", "Status", 12, (143, 160, 180), False, udim2(0, 84, 0, 104), udim2(1, -208, 0, 18), 98),
            popup_button("ActionButton", "Buy", (53, 130, 246), udim2(1, -110, 0, 50), udim2(0, 94, 0, 36), 98),
        ],
    )
    bait_card = popup_card_template(
        "BaitRowTemplate",
        104,
        [
            popup_text("Name", "Bait", 16, (255, 255, 255), True, udim2(0, 12, 0, 8), udim2(1, -222, 0, 22), 98),
            popup_text("Effect", "Effect", 12, (190, 204, 220), False, udim2(0, 12, 0, 34), udim2(1, -222, 0, 34), 98, wrapped=True),
            popup_text("Detail", "Count", 12, (143, 160, 180), False, udim2(0, 12, 0, 72), udim2(1, -222, 0, 18), 98),
            popup_button("BuyButton", "Buy +1", (28, 160, 92), udim2(1, -194, 0, 35), udim2(0, 84, 0, 34), 98, text_size=12),
            popup_button("EquipButton", "Equip", (53, 130, 246), udim2(1, -102, 0, 35), udim2(0, 86, 0, 34), 98, text_size=12),
        ],
    )
    tab_template = popup_button(
        "TabButtonTemplate",
        "Tab",
        (38, 45, 57),
        udim2(0, 0, 0, 0),
        udim2(0, 112, 1, 0),
        98,
        visible=False,
    )
    panel.children.append(templates_folder(tab_template, rod_card, bait_card))
    overlay.children.append(panel)
    return overlay


def main():
    write_model(HERE / "FishmongerSellOverlay.rbxmx", make_fishmonger())
    write_model(HERE / "RodShopOverlay.rbxmx", make_rod_shop())


if __name__ == "__main__":
    main()

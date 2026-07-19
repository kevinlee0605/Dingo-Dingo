"""Structural checks for the authored Fishy Fish UI migration.

This intentionally does not replace a Roblox Studio playtest. It catches the
regressions that previously caused duplicate runtime ScreenGuis, stale rollback
sources, and incomplete Rojo ownership before a place is synced.
"""

from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_SCREENS = {
    "FishingGui": ROOT / "src/ui/FishingGui",
    "TopHudGui": ROOT / "src/ui/TopHudGui",
    "Phase3EconomyGui": ROOT / "src/ui/Phase3EconomyGui",
    "AquariumFreePlacementGui": ROOT / "src/ui/AquariumFreePlacementGui",
    "AquariumViewerGui": ROOT / "src/ui/AquariumViewerGui",
    "ServerUtcClockGui": ROOT / "src/ui/ServerUtcClockGui",
    "CustomHotbarGui": ROOT / "src/ui/CustomHotbarGui",
}

V1636_INSET_POLICY = {
    "FishingGui": False,
    "TopHudGui": False,
    "Phase3EconomyGui": False,
    "AquariumFreePlacementGui": True,
    "AquariumViewerGui": True,
    "ServerUtcClockGui": False,
    "CustomHotbarGui": False,
}

V1636_SAFE_AREA_POLICY = {
    "FishingGui": "FullscreenExtension",
    "TopHudGui": "FullscreenExtension",
    "Phase3EconomyGui": "FullscreenExtension",
    "AquariumFreePlacementGui": "FullscreenExtension",
    "ServerUtcClockGui": "None",
    "CustomHotbarGui": "None",
}

REQUIRED_FISHING_SURFACES = {
    "Root",
    "HUD",
    "FishingXPText",
    "CoinsHud",
    "SeaStarsHud",
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
    "FishingMinigame",
    "ModernSeasideShop",
    "ModernSupplyShop",
    "BaitIconTemplates",
    "AquariumViewerFallbackButton",
    "Templates",
    "Toast",
}

ACTIVE_CONTROLLER_ROOTS = (
    ROOT / "src/ui",
    ROOT / "src/replicatedfirst",
)

ACTIVE_STARTER_PLAYER_CONTROLLERS = (
    "AuthoredUiController.client.luau",
    "BaitIconController.client.luau",
    "EconomyUIIntegration.client.luau",
    "FishingAreaButtonsVisibility.client.luau",
    "FishingCastAnimation.client.luau",
    "Phase3EconomyUI.client.luau",
    "RetiredForceTopHudPosition.client.luau",
    "RetiredSeastarHudOverride.client.luau",
    "ServerUtcClock.client.luau",
    "CustomHotbarClient.client.luau",
)

ACTIVE_STARTER_GUI_CONTROLLERS = (
    "AquariumDesignerShopCleanup.client.luau",
    "AquariumFreePlacementEditor.client.luau",
)


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def model_root_name(path: Path) -> str | None:
    root = ET.parse(path).getroot()
    item = root.find("Item")
    if item is None:
        return None
    properties = item.find("Properties")
    if properties is None:
        return None
    for prop in properties:
        if prop.tag == "string" and prop.attrib.get("name") == "Name":
            return prop.text
    return None


def find_named_item(tree: ET.ElementTree, name: str) -> ET.Element | None:
    for item in tree.findall(".//Item"):
        name_element = item.find("./Properties/string[@name='Name']")
        if name_element is not None and name_element.text == name:
            return item
    return None


def find_named_items(tree: ET.ElementTree, name: str) -> list[ET.Element]:
    return [
        item
        for item in tree.findall(".//Item")
        if (name_element := item.find("./Properties/string[@name='Name']")) is not None
        and name_element.text == name
    ]


def number_property(item: ET.Element, tag: str, name: str) -> float | None:
    element = item.find(f"./Properties/{tag}[@name='{name}']")
    if element is None or element.text is None:
        return None
    try:
        return float(element.text)
    except ValueError:
        return None


def token_property(item: ET.Element, name: str) -> int | None:
    value = number_property(item, "token", name)
    return int(value) if value is not None else None


def content_property(item: ET.Element, name: str) -> str | None:
    element = item.find(f"./Properties/Content[@name='{name}']/url")
    return element.text if element is not None else None


def validate_named_scale_type(
    errors: list[str],
    model_path: Path,
    item_name: str,
    expected_scale_type: int,
    expected_count: int,
) -> None:
    items = [
        item
        for item in find_named_items(ET.parse(model_path), item_name)
        if item.get("class") in {"ImageLabel", "ImageButton"}
    ]
    if len(items) != expected_count:
        fail(
            errors,
            f"{model_path.name} expected {expected_count} authored {item_name} image nodes, "
            f"got {len(items)}",
        )
        return
    for item in items:
        actual_scale_type = token_property(item, "ScaleType")
        if actual_scale_type != expected_scale_type:
            fail(
                errors,
                f"{model_path.name}.{item_name} must use ScaleType token "
                f"{expected_scale_type}, got {actual_scale_type}",
            )


def vector2_property(item: ET.Element, name: str) -> tuple[float, float] | None:
    element = item.find(f"./Properties/Vector2[@name='{name}']")
    if element is None:
        return None
    try:
        return float(element.findtext("X", "nan")), float(element.findtext("Y", "nan"))
    except ValueError:
        return None


def udim_property(item: ET.Element, name: str) -> tuple[float, float] | None:
    element = item.find(f"./Properties/UDim[@name='{name}']")
    if element is None:
        return None
    try:
        return float(element.findtext("S", "nan")), float(element.findtext("O", "nan"))
    except ValueError:
        return None


def udim2_property(item: ET.Element, name: str) -> tuple[float, float, float, float] | None:
    element = item.find(f"./Properties/UDim2[@name='{name}']")
    if element is None:
        return None
    try:
        return tuple(
            float(element.findtext(component, "nan"))
            for component in ("XS", "XO", "YS", "YO")
        )
    except ValueError:
        return None


def color3_property(item: ET.Element, name: str) -> tuple[float, float, float] | None:
    element = item.find(f"./Properties/Color3[@name='{name}']")
    if element is None:
        return None
    try:
        return tuple(
            float(element.findtext(component, "nan"))
            for component in ("R", "G", "B")
        )
    except ValueError:
        return None


def iter_active_luau_files() -> list[Path]:
    files: list[Path] = []
    for root in ACTIVE_CONTROLLER_ROOTS:
        files.extend(root.rglob("*.luau"))
    starter_player = ROOT / "src/starterplayer"
    files.extend(starter_player / name for name in ACTIVE_STARTER_PLAYER_CONTROLLERS)
    starter_gui = ROOT / "src/startergui"
    files.extend(starter_gui / name for name in ACTIVE_STARTER_GUI_CONTROLLERS)
    return sorted({path.resolve() for path in files if path.is_file()})


def main() -> int:
    errors: list[str] = []

    for cache_dir in (ROOT / "src/ui").rglob("__pycache__"):
        fail(errors, f"Generated cache directory would be synced by Rojo: {cache_dir.relative_to(ROOT)}")

    for screen_name, path in REQUIRED_SCREENS.items():
        meta_path = path / "init.meta.json"
        if not meta_path.is_file():
            fail(errors, f"{screen_name}: missing {meta_path.relative_to(ROOT)}")
            continue
        meta = load_json(meta_path)
        if meta.get("className") != "ScreenGui":
            fail(errors, f"{screen_name}: init.meta.json is not a ScreenGui")
        properties = meta.get("properties", {})
        expected_inset_policy = V1636_INSET_POLICY[screen_name]
        if properties.get("IgnoreGuiInset") is not expected_inset_policy:
            fail(
                errors,
                f"{screen_name}: IgnoreGuiInset must be {expected_inset_policy} to match v1636",
            )
        expected_safe_area = V1636_SAFE_AREA_POLICY.get(screen_name)
        if expected_safe_area and properties.get("SafeAreaCompatibility") != expected_safe_area:
            fail(
                errors,
                f"{screen_name}: SafeAreaCompatibility must be {expected_safe_area} to match v1636",
            )

    fishing_models = {
        model_root_name(path)
        for path in (ROOT / "src/ui/FishingGui").glob("*.rbxmx")
    }
    missing_surfaces = sorted(REQUIRED_FISHING_SURFACES - fishing_models)
    if missing_surfaces:
        fail(errors, "FishingGui is missing authored surfaces: " + ", ".join(missing_surfaces))

    bag_model_path = ROOT / "src/ui/FishingGui/ModernBagRoot.rbxmx"
    bag_tree = ET.parse(bag_model_path)
    bag_row_template = find_named_item(bag_tree, "InventoryRowTemplate")
    required_bag_row_nodes = {
        "Background": "ImageLabel",
        "RodFrame": "ImageLabel",
        "BaitFrame": "Frame",
        "FishFrame": "ImageLabel",
        "RodName": "TextLabel",
        "BaitName": "TextLabel",
        "FishName": "TextLabel",
        "ActionButton": "TextButton",
    }
    if bag_row_template is None:
        fail(errors, "ModernBagRoot is missing InventoryRowTemplate")
    else:
        authored_bag_row_nodes = {}
        for child in bag_row_template.findall("./Item"):
            name_element = child.find("./Properties/string[@name='Name']")
            if name_element is not None and name_element.text:
                authored_bag_row_nodes[name_element.text] = child.attrib.get("class")
        for node_name, class_name in required_bag_row_nodes.items():
            actual_class = authored_bag_row_nodes.get(node_name)
            if actual_class != class_name:
                fail(
                    errors,
                    f"ModernBagRoot.InventoryRowTemplate.{node_name} must be a direct "
                    f"{class_name} child, got {actual_class or 'missing'}",
                )

    bag_controller_path = ROOT / "src/ui/FishingGui/FishingClient/BagModernUI.luau"
    bag_controller_source = bag_controller_path.read_text(encoding="utf-8-sig")
    make_row_start = bag_controller_source.find("local function makeRow")
    make_row_end = bag_controller_source.find("local function renderRods", make_row_start)
    make_row_source = bag_controller_source[make_row_start:make_row_end]
    if make_row_start < 0 or make_row_end < 0 or "return wrapper" not in make_row_source:
        fail(
            errors,
            "BagModernUI.makeRow must return InventoryRowTemplate's wrapper so authored row siblings resolve",
        )
    if '\n\tlocal explicitId = string.match(value, "[?&]id=(%d+)")' not in bag_controller_source:
        fail(errors, "BagModernUI.normalizeAssetId is missing its local explicitId declaration")

    fishing_client_path = ROOT / "src/ui/FishingGui/FishingClient/init.client.luau"
    fishing_client_source = fishing_client_path.read_text(encoding="utf-8-sig")
    if "screenGui.IgnoreGuiInset = false" not in fishing_client_source:
        fail(errors, "FishingClient must preserve the authored v1636 inset policy in Play mode")
    if 'screenGui:FindFirstChild("ModernBagRoot")' not in fishing_client_source:
        fail(errors, "FishingClient Bag visibility guard must resolve ModernBagRoot below FishingGui")

    auxiliary_ui_path = ROOT / "src/replicatedfirst/AuxiliaryUiTemplates.rbxmx"
    auxiliary_ui_source = auxiliary_ui_path.read_text(encoding="utf-8-sig")
    auxiliary_ui_names = {
        element.text
        for element in ET.parse(auxiliary_ui_path).findall(".//string[@name='Name']")
        if element.text
    }
    required_auxiliary_names = {
        "AuxiliaryUiTemplates",
        "FishyFishLoadingBackground",
        "FullBleedBackgroundCanvas",
        "HarborBackground",
        "FishyFishLoadingScreen",
        "LoadingCanvas",
        "FishyFishLogo",
        "FishyFishLogoFallback",
        "LoadingInformation",
        "StatusText",
        "LoadingDots",
    }
    missing_auxiliary_names = required_auxiliary_names - auxiliary_ui_names
    if missing_auxiliary_names:
        fail(errors, "ReplicatedFirst loading UI is missing authored nodes: " + ", ".join(sorted(missing_auxiliary_names)))
    for asset_id in ("127539948539559", "72585587327009", "137479516081769"):
        if asset_id not in auxiliary_ui_source:
            fail(errors, f"ReplicatedFirst loading UI is missing original asset {asset_id}")
    loading_controller_source = (
        ROOT / "src/replicatedfirst/LoadingScreen.client.luau"
    ).read_text(encoding="utf-8-sig")
    if "Instance.new" in loading_controller_source:
        fail(errors, "LoadingScreen still constructs fixed UI instead of cloning authored templates")

    open_panel_path = ROOT / "src/ui/FishingGui/OpenFishingPanel.rbxmx"
    open_panel_item = ET.parse(open_panel_path).getroot().find("Item")
    if open_panel_item is None or open_panel_item.attrib.get("class") != "BindableEvent":
        fail(errors, "FishingGui.OpenFishingPanel must be an authored BindableEvent")

    panels_path = ROOT / "src/ui/FishingGui/Panels.rbxmx"
    panel_marker_names = {
        element.text
        for element in ET.parse(panels_path).findall(".//string[@name='Name']")
        if element.text
    }
    missing_panel_markers = {"Panels", "BagPanel", "FishdexPanel"} - panel_marker_names
    if missing_panel_markers:
        fail(errors, "FishingGui.Panels is missing authored markers: " + ", ".join(sorted(missing_panel_markers)))

    panel_markers_controller = (
        ROOT / "src/ui/FishingGui/FishingClient/PanelMarkers.luau"
    ).read_text(encoding="utf-8-sig")
    if "Instance.new" in panel_markers_controller:
        fail(errors, "PanelMarkers still constructs fixed Explorer nodes at runtime")

    toast_source = (ROOT / "src/ui/FishingGui/Toast.rbxmx").read_text(encoding="utf-8-sig")
    for exact_property in (
        '<token name="Font">19</token>',
        '<float name="TextSize">16</float>',
        '<float name="BackgroundTransparency">0.06</float>',
    ):
        if exact_property not in toast_source:
            fail(errors, "FishingGui.Toast no longer matches the original fishing banner")

    fishdex_model_path = ROOT / "src/ui/FishingGui/ModernFishdex.rbxmx"
    fishdex_tree = ET.parse(fishdex_model_path)
    fishdex_names = {
        element.text
        for element in fishdex_tree.findall(".//string[@name='Name']")
        if element.text
    }
    required_fishdex_nodes = {
        "ModernFishdex",
        "ResponsiveScale",
        "FishdexTitle",
        "FishdexHeaderIcon",
        "CloseButton",
        "CloseButtonStaticVisual",
        "AllTab",
        "LilyshoreIslandTab",
        "RiverbendIslandTab",
        "CoralCoastIslandTab",
        "FishCardsScroll",
        "CardsHolder",
        "CollectionPanel",
        "CollectionCount",
        "FishdexCustomScrollTrack",
        "TrackGradient",
        "FishdexCustomScrollThumb",
        "ThumbGradient",
        "FishCardTemplate",
        "FishImage",
        "FishName",
        "RarityBadge",
        "RarityText",
    }
    missing_fishdex_nodes = sorted(required_fishdex_nodes - fishdex_names)
    if missing_fishdex_nodes:
        fail(errors, "ModernFishdex is missing authored v22 nodes: " + ", ".join(missing_fishdex_nodes))

    fishdex_model_source = fishdex_model_path.read_text(encoding="utf-8-sig")
    for asset_id in (
        "89231191992466",  # final backbone
        "126888363962311",  # header book
        "74193356060798",  # selected All tab
        "74423157457349",  # normal island tabs
        "101419501637204",  # collection panel
        "73430945226148",  # collection check
        "77909229815890",  # dynamic card template
        "119322438066977",  # fixed close art
    ):
        if asset_id not in fishdex_model_source:
            fail(errors, f"ModernFishdex authored v22 model is missing asset {asset_id}")

    fishdex_scroll_thumb = find_named_item(fishdex_tree, "FishdexCustomScrollThumb")
    if (
        fishdex_scroll_thumb is None
        or fishdex_scroll_thumb.attrib.get("class") != "ImageButton"
        or fishdex_scroll_thumb.findtext("./Properties/bool[@name='Active']") != "true"
    ):
        fail(errors, "ModernFishdex scrollbar thumb must keep the active v1615 ImageButton state")

    expected_fishdex_gradients = {
        "TrackGradient": (
            0, 8 / 255, 39 / 255, 101 / 255, 0,
            0.5, 2 / 255, 18 / 255, 53 / 255, 0,
            1, 8 / 255, 39 / 255, 101 / 255, 0,
        ),
        "ThumbGradient": (
            0, 0, 239 / 255, 1, 0,
            0.34, 0, 167 / 255, 1, 0,
            1, 15 / 255, 72 / 255, 235 / 255, 0,
        ),
    }
    for gradient_name, expected_sequence in expected_fishdex_gradients.items():
        gradient = find_named_item(fishdex_tree, gradient_name)
        color_element = (
            gradient.find("./Properties/ColorSequence[@name='Color']")
            if gradient is not None
            else None
        )
        try:
            actual_sequence = tuple(float(value) for value in (color_element.text or "").split())
        except (AttributeError, ValueError):
            actual_sequence = ()
        if len(actual_sequence) != len(expected_sequence) or any(
            abs(actual - expected) > 1e-9
            for actual, expected in zip(actual_sequence, expected_sequence)
        ):
            fail(errors, f"ModernFishdex {gradient_name} ColorSequence differs from v1615")

    island_model_path = ROOT / "src/ui/FishingGui/BiomeWarpOverlay.rbxmx"
    island_tree = ET.parse(island_model_path)
    island_names = {
        element.text
        for element in island_tree.findall(".//string[@name='Name']")
        if element.text
    }
    required_island_nodes = {
        "BiomeWarpOverlay",
        "ModernIslandWarp",
        "ResponsiveScale",
        "TopLeftDecoration",
        "CloseButton",
        "IslandList",
        "Cards",
        "ComingSoonCard",
        "IslandCardTemplate",
        "IslandIcon",
        "IslandTitle",
        "RequirementLabel",
        "RequirementValue",
        "CoinIcon",
        "CoinRequirement",
        "GoButton",
    }
    missing_island_nodes = sorted(required_island_nodes - island_names)
    if missing_island_nodes:
        fail(errors, "BiomeWarpOverlay is missing authored v1615 nodes: " + ", ".join(missing_island_nodes))

    island_model_source = island_model_path.read_text(encoding="utf-8-sig")
    for asset_id in (
        "139219110427433",
        "94386681729236",
        "111469265624538",
        "81989089279793",
        "79109082679955",
        "135395684428311",
        "94429518283822",
        "97504855517031",
    ):
        if asset_id not in island_model_source:
            fail(errors, f"BiomeWarpOverlay authored v1615 model is missing asset {asset_id}")

    minigame_model_path = ROOT / "src/ui/FishingGui/CustomFishingMinigame.rbxmx"
    minigame_tree = ET.parse(minigame_model_path)
    minigame_names = {
        element.text
        for element in minigame_tree.findall(".//string[@name='Name']")
        if element.text
    }
    required_minigame_nodes = {
        "CustomFishingMinigame",
        "HeaderText",
        "WaterPanel",
        "WaterPanelAspect",
        "WaterInnerMovementArea",
        "CatchBar",
        "FishMarkerCircle",
        "FishMarkerAspect",
        "FishImage",
        "ProgressTrack",
        "ProgressTrackAspect",
        "RageGaugeFocusScale",
        "ProgressInner",
        "ProgressFill",
        "TopCap",
        "Middle",
        "BottomCap",
        "StatusText",
        "ProgressText",
        "BaitText",
        "CastText",
        "InstructionText",
    }
    missing_minigame_nodes = sorted(required_minigame_nodes - minigame_names)
    if missing_minigame_nodes:
        fail(
            errors,
            "CustomFishingMinigame is missing authored v19 nodes: "
            + ", ".join(missing_minigame_nodes),
        )

    minigame_model_source = minigame_model_path.read_text(encoding="utf-8-sig")
    for asset_id in (
        "134199963481930",  # water panel
        "84261877127360",  # default catch bar
        "74137560034505",  # fish marker backing
        "85876175896136",  # slider track
        "138976342109765",  # three-piece gauge
    ):
        if asset_id not in minigame_model_source:
            fail(errors, f"CustomFishingMinigame is missing asset {asset_id}")

    legacy_minigame_model_path = ROOT / "src/ui/FishingGui/FishingMinigame.rbxmx"
    legacy_minigame_names = {
        element.text
        for element in ET.parse(legacy_minigame_model_path).findall(".//string[@name='Name']")
        if element.text
    }
    required_legacy_minigame_nodes = {
        "FishingMinigame",
        "InnerStroke",
        "MinigameText",
        "Bar",
        "Zone",
        "Marker",
        "CatchButton",
        "FishingGameContent",
        "VerticalFishingPanel",
        "Water",
        "CatchBar",
        "FishMarker",
        "FishImage",
        "ProgressTrack",
        "ProgressFill",
        "ProgressFillGradient",
        "MinigameFishInfo",
        "MinigameProgressText",
        "MinigameInstruction",
        "CastPowerContent",
        "CastPowerTitle",
        "CastPowerTrack",
        "PerfectTimingZone",
        "PowerFill",
        "BobberMarker",
        "CastPowerValue",
        "CastPowerStatus",
        "CastPowerHint",
    }
    missing_legacy_minigame_nodes = sorted(
        required_legacy_minigame_nodes - legacy_minigame_names
    )
    if missing_legacy_minigame_nodes:
        fail(
            errors,
            "FishingMinigame is missing authored compatibility nodes: "
            + ", ".join(missing_legacy_minigame_nodes),
        )

    fishing_client_source = (
        ROOT / "src/ui/FishingGui/FishingClient/init.client.luau"
    ).read_text(encoding="utf-8-sig")
    if 'requiredAuthoredNode(screenGui, "FishingMinigame", "Frame")' not in fishing_client_source:
        fail(errors, "FishingClient does not bind the authored FishingMinigame surface")

    cast_model_path = ROOT / "src/ui/FishingGui/ModernCastPowerUI.rbxmx"
    cast_names = {
        element.text
        for element in ET.parse(cast_model_path).findall(".//string[@name='Name']")
        if element.text
    }
    required_cast_nodes = {
        "ModernCastPowerUI",
        "CastPowerContent",
        "CastPowerScale",
        "SparkleLayer",
        "SparkleScale",
        "PerfectCastSparkleTemplate",
        "SparkleCorner",
    }
    missing_cast_nodes = sorted(required_cast_nodes - cast_names)
    if missing_cast_nodes:
        fail(
            errors,
            "ModernCastPowerUI is missing authored sparkle nodes: "
            + ", ".join(missing_cast_nodes),
        )

    cast_controller_source = (
        ROOT / "src/ui/FishingGui/FishingClient/CastPowerModernUI.luau"
    ).read_text(encoding="utf-8-sig")
    if "Instance.new" in cast_controller_source:
        fail(errors, "CastPowerModernUI still constructs fixed UI at runtime")
    for marker in (
        "local sparkleLayer = requireAuthoredChild(",
        '"SparkleLayer"',
        '"PerfectCastSparkleTemplate"',
        "function CastPowerModernUI.retainSparkle()",
        "function CastPowerModernUI.releaseSparkle()",
    ):
        if marker not in cast_controller_source:
            fail(errors, f"CastPowerModernUI is missing authored sparkle binding {marker}")

    for marker in (
        "local sparkle = sparkleTemplate:Clone()",
        "sparkle.Parent = sparkleParent",
        "castPowerModernUI.retainSparkle()",
        "castPowerModernUI.releaseSparkle()",
    ):
        if marker not in fishing_client_source:
            fail(errors, f"FishingClient is missing authored sparkle behavior {marker}")
    if 'local sparkle = Instance.new("Frame")' in fishing_client_source:
        fail(errors, "FishingClient still constructs perfect-cast sparkles at runtime")

    root_model_path = ROOT / "src/ui/FishingGui/Root.rbxmx"
    root_names = {
        element.text
        for element in ET.parse(root_model_path).findall(".//string[@name='Name']")
        if element.text
    }
    required_rage_nodes = {
        "RageModeWarning",
        "WarningPulseScale",
        "RageHorizontalFill",
        "LeftCapHolder",
        "LeftCap",
        "MiddleHolder",
        "Middle",
        "RightCapHolder",
        "RightCap",
    }
    missing_rage_nodes = sorted(required_rage_nodes - root_names)
    if missing_rage_nodes:
        fail(errors, "Root is missing authored Rage nodes: " + ", ".join(missing_rage_nodes))

    hotbar_model_path = ROOT / "src/ui/CustomHotbarGui/Holder.rbxmx"
    hotbar_names = [
        element.text
        for element in ET.parse(hotbar_model_path).findall(".//string[@name='Name']")
        if element.text
    ]
    for required_name in ("Holder", "DeviceScale", "Slot1", "Slot2", "Slot3"):
        if required_name not in hotbar_names:
            fail(errors, f"CustomHotbarGui is missing authored node {required_name}")
    for child_name, expected_count in (
        ("NumberBox", 3),
        ("Icon", 3),
        ("Label", 3),
    ):
        if hotbar_names.count(child_name) != expected_count:
            fail(
                errors,
                f"CustomHotbarGui expected {expected_count} authored {child_name} nodes, "
                f"got {hotbar_names.count(child_name)}",
            )

    xp_model_source = (ROOT / "src/ui/FishingGui/FishingXPText.rbxmx").read_text(
        encoding="utf-8-sig"
    )
    clock_model_source = (ROOT / "src/ui/ServerUtcClockGui/ClockFrame.rbxmx").read_text(
        encoding="utf-8-sig"
    )
    for label, source, outline_name in (
        ("XPCombinedText", xp_model_source, "XPTextOutline"),
        ("ServerUtcText", clock_model_source, "ServerUtcTextOutline"),
    ):
        if '<token name="Font">20</token>' not in source:
            fail(errors, f"{label} is not authored with GothamBlack")
        if outline_name not in source or '<float name="Thickness">3</float>' not in source:
            fail(errors, f"{label} is missing the shared 3px outline")

    coins_model_source = (ROOT / "src/ui/FishingGui/CoinsHud.rbxmx").read_text(
        encoding="utf-8-sig"
    )
    sea_stars_model_source = (ROOT / "src/ui/FishingGui/SeaStarsHud.rbxmx").read_text(
        encoding="utf-8-sig"
    )
    for label, source, asset_id in (
        ("CoinsHud", coins_model_source, "99615681502772"),
        ("SeaStarsHud", sea_stars_model_source, "102284604663190"),
    ):
        if asset_id not in source:
            fail(errors, f"{label} is missing its original currency artwork")
        if '<token name="Font">20</token>' not in source:
            fail(errors, f"{label} is not authored with GothamBlack")
        if '<float name="Thickness">3.3</float>' not in source:
            fail(errors, f"{label} is missing the original 3.3px number outline")
    validate_named_scale_type(
        errors,
        ROOT / "src/ui/FishingGui/CoinsHud.rbxmx",
        "CoinIcon",
        3,  # Enum.ScaleType.Fit
        1,
    )
    validate_named_scale_type(
        errors,
        ROOT / "src/ui/FishingGui/SeaStarsHud.rbxmx",
        "SeaStarIcon",
        3,  # Enum.ScaleType.Fit
        1,
    )
    coins_tree = ET.parse(ROOT / "src/ui/FishingGui/CoinsHud.rbxmx")
    stars_tree = ET.parse(ROOT / "src/ui/FishingGui/SeaStarsHud.rbxmx")
    coins_text_item = find_named_item(coins_tree, "CoinsText")
    star_icon_item = next(
        (
            item
            for item in find_named_items(stars_tree, "SeaStarIcon")
            if item.get("class") == "ImageLabel"
        ),
        None,
    )
    stars_text_item = find_named_item(stars_tree, "SeaStarsText")
    if coins_text_item is None or udim2_property(coins_text_item, "Position") != (0.0, 80.0, 0.0, 10.0):
        fail(errors, "CoinsText must remain on the authored currency number line")
    if star_icon_item is None or udim2_property(star_icon_item, "Position") != (0.0, 0.0, 0.0, 4.0):
        fail(errors, "SeaStarIcon must share the v1636 coin-art alignment")
    if stars_text_item is None or udim2_property(stars_text_item, "Position") != (0.0, 76.0, 0.0, 1.0):
        fail(errors, "SeaStarsText compatibility node differs from v1636")
    star_number_area = find_named_item(stars_tree, "NumberArea")
    if star_number_area is None or udim2_property(star_number_area, "Position") != (0.0, 80.0, 0.0, 10.0):
        fail(errors, "Sea Star rolling digits must align visually with coin rolling digits")
    for compatibility_name in (
        "PreviewDigitSlot",
        "PreviewCharacter",
        "LegacyStatsText",
        "LegacyStatusText",
    ):
        if compatibility_name not in coins_model_source:
            fail(errors, f"CoinsHud is missing authored compatibility node {compatibility_name}")
    for compatibility_name in ("LegacyXPProgressText", "LegacyXPFill"):
        if compatibility_name not in xp_model_source:
            fail(errors, f"FishingXPText is missing authored compatibility node {compatibility_name}")
    if '<float name="BackgroundTransparency">1</float>' not in clock_model_source:
        fail(errors, "ServerUtcClockGui no longer has a transparent clock frame")

    top_buttons_path = ROOT / "src/ui/TopHudGui/TopButtonsFrame.rbxmx"
    top_buttons_tree = ET.parse(top_buttons_path)
    top_button_names = [
        element.text
        for element in top_buttons_tree.findall(".//string[@name='Name']")
        if element.text
    ]
    for button_name in (
        "SettingsButton",
        "QuestsButton",
        "ShopButton",
        "TopLoginRewardButton",
    ):
        if button_name not in top_button_names:
            fail(errors, f"TopButtonsFrame is missing authored {button_name}")
    if top_button_names.count("PressScale") != 4:
        fail(errors, "TopButtonsFrame must author one PressScale for each of its four buttons")
    if "NotificationBadge" in top_button_names:
        fail(errors, "TopButtonsFrame must not contain a notification badge")
    validate_named_scale_type(
        errors,
        top_buttons_path,
        "Icon",
        3,  # Enum.ScaleType.Fit
        4,
    )
    validate_named_scale_type(
        errors,
        ROOT / "src/ui/FishingGui/BottomButtonsFrame.rbxmx",
        "ButtonImage",
        3,  # Enum.ScaleType.Fit
        2,
    )
    validate_named_scale_type(
        errors,
        ROOT / "src/ui/FishingGui/Templates.rbxmx",
        "Icon",
        3,  # Enum.ScaleType.Fit
        7,
    )
    top_buttons_source = top_buttons_path.read_text(encoding="utf-8-sig")
    top_buttons_frame = find_named_item(top_buttons_tree, "TopButtonsFrame")
    if top_buttons_frame is None or udim2_property(top_buttons_frame, "Position") != (0.5, 0.0, 0.0, 70.0):
        fail(errors, "TopButtonsFrame must include the 58px Studio preview compensation")
    authored_controller_source = (ROOT / "src/starterplayer/AuthoredUiController.client.luau").read_text(
        encoding="utf-8-sig"
    )
    if "topButtons.Position = UDim2.new(0.5, 0, 0, 12)" not in authored_controller_source:
        fail(errors, "TopButtonsFrame runtime position must preserve the v1636 12px offset")

    daily_surface_path = ROOT / "src/ui/Phase3EconomyGui/DailyRewardSurface.rbxmx"
    daily_templates_path = ROOT / "src/ui/Phase3EconomyGui/DailyRewardTemplates.rbxmx"
    daily_surface_source = daily_surface_path.read_text(encoding="utf-8-sig")
    daily_templates_source = daily_templates_path.read_text(encoding="utf-8-sig")
    daily_surface_tree = ET.parse(daily_surface_path)
    daily_names = {
        element.text
        for path in (daily_surface_path, daily_templates_path)
        for element in ET.parse(path).findall(".//string[@name='Name']")
        if element.text
    }
    daily_authored_text: dict[str, list[str]] = {}
    for path in (daily_surface_path, daily_templates_path):
        for item in ET.parse(path).findall(".//Item"):
            properties = item.find("Properties")
            if properties is None:
                continue
            name_element = properties.find("string[@name='Name']")
            text_element = properties.find("string[@name='Text']")
            if name_element is None or text_element is None or name_element.text is None:
                continue
            daily_authored_text.setdefault(name_element.text, []).append(text_element.text or "")
    required_daily_nodes = {
        "DailyRewardSurface",
        "LoginRewardOverlay",
        "LoginPanel",
        "LoginScale",
        "LoginBackground",
        "LoginTopDecoration",
        "LoginTitle",
        "LoginClose",
        "LoginInfo",
        "LoginTimer",
        "LoginGrid",
        "DailyRewardGridLayout",
        "DailyRewardCustomScrollbar",
        "DailyRewardScrollbarArt",
        "DailyRewardScrollLane",
        "DailyRewardMovingThumb",
        "LoginBottomDecoration",
        "ClaimButton",
        "ClaimButtonArt",
        "ClaimButtonLabel",
        "DayCardTemplate",
        "CardArt",
        "DayLabel",
        "MilestoneIcon",
        "RewardLineTemplate",
        "MilestoneRewardLineTemplate",
        "ClaimedIconTemplate",
    }
    missing_daily_nodes = sorted(required_daily_nodes - daily_names)
    if missing_daily_nodes:
        fail(errors, "Daily Rewards is missing required authored nodes: " + ", ".join(missing_daily_nodes))
    expected_v1636_daily_text = {
        "LoginTitle": ["Daily Login Rewards"],
        "LoginInfo": ["Missing dates never resets or skips your progress."],
        "LoginTimer": ["Daily rewards reset at 24:00 (Server's UTC Time)"],
        "LoginStatus": [""],
        "ClaimButtonLabel": ["Claim Day 1"],
        "DayLabel": ["Day 1"],
        "RewardText": ["Reward", "Reward"],
    }
    for name, expected_text in expected_v1636_daily_text.items():
        actual_text = daily_authored_text.get(name, [])
        if actual_text != expected_text:
            fail(
                errors,
                f"Daily Rewards {name} text differs from v1636: "
                f"expected {expected_text!r}, got {actual_text!r}",
            )
    if "LaneGradient" in daily_names or "ThumbGlow" in daily_names or "ThumbHighlight" in daily_names:
        fail(errors, "Daily Rewards scrollbar contains post-v1615 decorative nodes")

    daily_button = find_named_item(top_buttons_tree, "TopLoginRewardButton")
    if daily_button is None or daily_button.attrib.get("class") != "TextButton":
        fail(errors, "Daily Rewards top button must be authored in the shared TopHudGui row")

    # The virtually cropped daily-reward art nodes must remain Stretch.
    daily_surface_scale_types = {
        "LoginBackground": 0,  # Stretch
        "LoginTopDecoration": 3,  # Fit
        "LoginClose": 3,  # Fit
        "DailyRewardScrollbarArt": 0,  # Stretch; applyVirtualCrop target
        "DailyRewardMovingThumb": 0,  # Stretch; runtime default, blank Image
        "LoginBottomDecoration": 3,  # Fit
        "ClaimButton": 0,  # Stretch; runtime default, blank Image
        "ClaimButtonArt": 0,  # Stretch; applyVirtualCrop target
    }
    daily_template_scale_types = {
        "CardArt": 0,  # Stretch; applyVirtualCrop target
        "MilestoneIcon": 3,  # Fit
        "RewardIcon": 3,  # Fit
        "ClaimedIconTemplate": 3,  # Fit
    }
    for item_name, expected_scale_type in daily_surface_scale_types.items():
        validate_named_scale_type(
            errors,
            daily_surface_path,
            item_name,
            expected_scale_type,
            1,
        )
    for item_name, expected_scale_type in daily_template_scale_types.items():
        validate_named_scale_type(
            errors,
            daily_templates_path,
            item_name,
            expected_scale_type,
            1,
        )
    daily_image_count = sum(
        1
        for path in (daily_surface_path, daily_templates_path)
        for item in ET.parse(path).findall(".//Item")
        if item.attrib.get("class") in {"ImageLabel", "ImageButton"}
    )
    expected_daily_image_count = len(daily_surface_scale_types) + len(
        daily_template_scale_types
    )
    if daily_image_count != expected_daily_image_count:
        fail(
            errors,
            "Daily Rewards ScaleType audit does not cover every image node: "
            f"expected {expected_daily_image_count}, got {daily_image_count}",
        )

    for asset_id in (
        "78408484505332",
        "117777143534466",
        "113416899840266",
        "119322438066977",
        "73367138577137",
        "93536836630458",
        "139579773560573",
        "86912435019607",
        "70463548759658",
        "94167472129143",
    ):
        if (
            asset_id not in daily_surface_source
            and asset_id not in daily_templates_source
            and asset_id not in top_buttons_source
        ):
            fail(errors, f"Daily Rewards authored model is missing asset {asset_id}")

    for model_path in (ROOT / "src").rglob("*.rbxmx"):
        try:
            ET.parse(model_path)
        except ET.ParseError as exc:
            fail(errors, f"Invalid XML in {model_path.relative_to(ROOT)}: {exc}")

    for model_path in (ROOT / "src/ui").rglob("*.rbxmx"):
        tree = ET.parse(model_path)
        for item in tree.findall(".//Item[@class='ScrollingFrame']"):
            name_element = item.find("./Properties/string[@name='Name']")
            item_name = name_element.text if name_element is not None else "<unnamed>"
            clips = item.findtext("./Properties/bool[@name='ClipsDescendants']")
            if clips != "true":
                fail(
                    errors,
                    f"{model_path.relative_to(ROOT)}.{item_name} must clip scrolling content",
                )

    screen_constructor = re.compile(r"Instance\s*\.\s*new\s*\(\s*['\"]ScreenGui['\"]")
    for script_path in iter_active_luau_files():
        source = script_path.read_text(encoding="utf-8-sig")
        if screen_constructor.search(source):
            fail(errors, f"Runtime ScreenGui constructor in {script_path.relative_to(ROOT)}")

    for project_name in ("default.project.json", "ui-migration.project.json"):
        project = load_json(ROOT / project_name)
        if project.get("servePlaceIds") != [124368026422180]:
            fail(errors, f"{project_name}: servePlaceIds must restrict sync to 124368026422180")
        starter_gui = project.get("tree", {}).get("StarterGui", {})
        for screen_name, expected_path in REQUIRED_SCREENS.items():
            entry = starter_gui.get(screen_name, {})
            actual = entry.get("$path")
            expected = expected_path.relative_to(ROOT).as_posix()
            if actual != expected:
                fail(errors, f"{project_name}: {screen_name} must map {expected}, got {actual!r}")

        serialized = json.dumps(project)
        if "FishingClient_Rollback1568" in serialized:
            fail(errors, f"{project_name}: still maps FishingClient_Rollback1568")
        for retired_name in ("AquariumFreePlacementEditor", "AquariumDesignerShopCleanup"):
            if retired_name not in starter_gui:
                fail(errors, f"{project_name}: does not reconcile retired {retired_name}")

        fishing_remotes = project.get("tree", {}).get("ReplicatedStorage", {}).get(
            "FishingRemotes", {}
        )
        if project_name == "ui-migration.project.json" and "OpenShop" not in fishing_remotes:
            fail(errors, f"{project_name}: does not declare the OpenShop UI remote")

    loading_project_name = "loading-screen.project.json"
    loading_project = load_json(ROOT / loading_project_name)
    if loading_project.get("servePlaceIds") != [124368026422180]:
        fail(errors, f"{loading_project_name}: servePlaceIds must restrict sync to 124368026422180")
    loading_tree = loading_project.get("tree", {})
    if loading_tree.get("ReplicatedFirst", {}).get("$path") != "src/replicatedfirst":
        fail(errors, f"{loading_project_name}: must map only the authored ReplicatedFirst loading UI")
    if "StarterGui" in loading_tree:
        fail(errors, f"{loading_project_name}: must not manage StarterGui")
    loading_player_scripts = loading_tree.get("StarterPlayer", {}).get("StarterPlayerScripts", {})
    if "ServerUtcClock" in loading_player_scripts:
        fail(errors, f"{loading_project_name}: must not mount a duplicate root ServerUtcClock")

    fishing_client = (ROOT / "src/ui/FishingGui/FishingClient/init.client.luau").read_text(
        encoding="utf-8-sig"
    )
    for action in ('action = "Input"', 'action = "Complete"'):
        if action not in fishing_client:
            fail(errors, f"FishingClient is missing minigame protocol payload {action}")
    if "Remote.OpenShop.OnClientEvent:Connect(openShop)" not in fishing_client:
        fail(errors, "FishingClient is missing the Castle OpenShop listener")
    if "Authored ModernFishdex v22 base is incomplete" not in fishing_client:
        fail(errors, "FishingClient does not enforce the authored Fishdex v22 base")
    if 'FindFirstChild("FishCardTemplate")' not in fishing_client:
        fail(errors, "FishingClient does not clone the authored Fishdex card template")

    island_controller = (ROOT / "src/ui/FishingGui/IslandWarpModernClient.client.luau").read_text(
        encoding="utf-8-sig"
    )
    if "Instance.new" in island_controller:
        fail(errors, "IslandWarpModernClient still constructs fixed UI instances at runtime")
    if 'WaitForChild("IslandCardTemplate")' not in island_controller or "cardTemplate:Clone()" not in island_controller:
        fail(errors, "IslandWarpModernClient does not clone the authored destination template")

    seaside_model_path = ROOT / "src/ui/FishingGui/ModernSeasideShop.rbxmx"
    seaside_names = {
        element.text
        for element in ET.parse(seaside_model_path).findall(".//string[@name='Name']")
        if element.text
    }
    required_seaside_nodes = {
        "ModernSeasideShop",
        "ResponsiveScale",
        "MainBackbone",
        "Decoration",
        "Title",
        "SellAllButton",
        "CloseButton",
        "SortTabs",
        "RarityTab",
        "ValueTab",
        "SubMainBackbone",
        "SubContentClip",
        "FishList",
        "ListLayout",
        "FishRowTemplate",
        "FishIcon",
        "MissingFishIcon",
        "FishName",
        "FishValue",
        "SellButton",
        "StatusLabel",
        "ScrollTrack",
        "ScrollThumb",
        "Texture",
    }
    missing_seaside_nodes = sorted(required_seaside_nodes - seaside_names)
    if missing_seaside_nodes:
        fail(
            errors,
            "ModernSeasideShop is missing authored v1615 nodes: "
            + ", ".join(missing_seaside_nodes),
        )
    seaside_source = seaside_model_path.read_text(encoding="utf-8-sig")
    for asset_id in (
        "77079984837491",
        "126541809567975",
        "135116059419917",
        "104189399468619",
        "82571731099591",
        "87923116280754",
        "120182750042631",
        "99716714580964",
        "73367138577137",
        "119322438066977",
    ):
        if asset_id not in seaside_source:
            fail(errors, f"ModernSeasideShop authored model is missing asset {asset_id}")
    seaside_controller = (
        ROOT / "src/ui/FishingGui/SeasideShopModernClient.client.luau"
    ).read_text(encoding="utf-8-sig")
    if "Instance.new" in seaside_controller:
        fail(errors, "SeasideShopModernClient still constructs UI instances at runtime")
    for marker in (
        '"ModernSeasideShop"',
        '"FishRowTemplate"',
        '"RarityTab"',
        '"ValueTab"',
        "rowTemplate:Clone()",
        "applyMappedArtwork",
    ):
        if marker not in seaside_controller:
            fail(errors, f"SeasideShopModernClient is missing authored binding {marker}")

    supply_model_path = ROOT / "src/ui/FishingGui/ModernSupplyShop.rbxmx"
    supply_names = {
        element.text
        for element in ET.parse(supply_model_path).findall(".//string[@name='Name']")
        if element.text
    }
    required_supply_nodes = {
        "ModernSupplyShop",
        "ResponsiveScale",
        "MainBackbone",
        "SubMainBackbone",
        "ShopIcon",
        "Title",
        "CloseButton",
        "Tabs",
        "RodsTab",
        "BaitTab",
        "SupplyShopList",
        "ListLayout",
        "RodCardTemplate",
        "BaitCardTemplate",
        "ItemIconHolder",
        "ItemIcon",
        "ItemName",
        "Info",
        "Requirements",
        "Status",
        "Description",
        "Detail",
        "StatusButton",
        "LoadingLabel",
        "ScrollTrack",
        "ScrollThumb",
        "ListRightEdgeMask",
    }
    missing_supply_nodes = sorted(required_supply_nodes - supply_names)
    if missing_supply_nodes:
        fail(
            errors,
            "ModernSupplyShop is missing authored v1615 nodes: "
            + ", ".join(missing_supply_nodes),
        )
    supply_source = supply_model_path.read_text(encoding="utf-8-sig")
    supply_dynamic_source = (
        ROOT / "src/ui/FishingGui/SupplyModernShopClient.client.luau"
    ).read_text(encoding="utf-8-sig")
    for asset_id in (
        "77079984837491",
        "120182750042631",
        "127925036253260",
        "131015417525927",
        "83228267224190",
        "96250612796056",
        "100331440979418",
        "88745847129808",
        "125521996931477",
        "137614054152455",
        "79554836514436",
        "73367138577137",
        "119322438066977",
    ):
        if asset_id not in supply_source and asset_id not in supply_dynamic_source:
            fail(errors, f"ModernSupplyShop authored model is missing asset {asset_id}")
    supply_controller = supply_dynamic_source
    if "Instance.new" in supply_controller:
        fail(errors, "SupplyModernShopClient still constructs UI instances at runtime")
    for marker in (
        '"ModernSupplyShop"',
        '"RodCardTemplate"',
        '"BaitCardTemplate"',
        "rodCardTemplate",
        "baitCardTemplate",
        ":Clone()",
        "applyCropArtwork",
    ):
        if marker not in supply_controller:
            fail(errors, f"SupplyModernShopClient is missing authored binding {marker}")
    if "tabHolder:ClearAllChildren()" in supply_controller:
        fail(errors, "SupplyModernShopClient still deletes its authored tab hierarchy")

    minigame_controller = (
        ROOT / "src/ui/FishingGui/FishingClient/FishingMinigameModernUI.luau"
    ).read_text(encoding="utf-8-sig")
    for marker in (
        "expectAuthoredChild",
        'expectAuthoredChild(panel, "WaterPanel", "ImageLabel")',
        'expectAuthoredChild(root, "RageModeWarning", "ImageLabel")',
        'bindOrCreate(progressInner, "ProgressFill", "Frame")',
    ):
        if marker not in minigame_controller:
            fail(errors, f"Fishing minigame controller is missing authored binding {marker}")
    if 'if existing.panel == authoredPanel then' in minigame_controller:
        fail(errors, "Fishing minigame still clears the authored panel during rebinding")

    rarity_controller = (
        ROOT / "src/ui/FishingGui/FishingClient/RarityCatchController.luau"
    ).read_text(encoding="utf-8-sig")
    if "Instance.new" in rarity_controller:
        fail(errors, "RarityCatchController still constructs UI instances at runtime")
    for marker in (
        'ui.progressFill:FindFirstChild("ProgressFillGradient")',
        "setGradient(standardProgressGradient, stage.topColor, stage.bottomColor)",
        "elseif not modernUi then",
    ):
        if marker not in rarity_controller:
            fail(errors, f"RarityCatchController is missing authored gradient binding {marker}")

    hotbar_controller = (ROOT / "src/starterplayer/CustomHotbarClient.client.luau").read_text(
        encoding="utf-8-sig"
    )
    if "Instance.new" in hotbar_controller:
        fail(errors, "CustomHotbarClient still constructs UI instances at runtime")
    for marker in (
        'WaitForChild("CustomHotbarGui", 30)',
        'requireAuthoredChild(screenGui, "Holder", "Frame")',
        'requireAuthoredChild(holder, "Slot" .. index, "TextButton")',
    ):
        if marker not in hotbar_controller:
            fail(errors, f"CustomHotbarClient is missing authored binding {marker}")

    settings_model_path = ROOT / "src/ui/FishingGui/SettingsOverlay.rbxmx"
    settings_names = {
        element.text
        for element in ET.parse(settings_model_path).findall(".//string[@name='Name']")
        if element.text
    }
    required_settings_nodes = {
        "SettingsOverlay",
        "SettingsCanvas",
        "UIScale",
        "BackboneTop",
        "BackboneMiddle",
        "BackboneBottom",
        "SettingsIcon",
        "Title",
        "CloseButton",
        "MusicRow",
        "MusicToggle",
        "MusicKnob",
        "SfxRow",
        "SfxToggle",
        "SfxKnob",
        "MoveSpeedRow",
        "SliderArea",
        "TrackLeftCap",
        "TrackMiddle",
        "TrackRightCap",
        "FillLeftCap",
        "FillMiddle",
        "SliderKnob",
        "AquariumTeleportRow",
        "TeleportButton",
    }
    missing_settings_nodes = sorted(required_settings_nodes - settings_names)
    if missing_settings_nodes:
        fail(errors, "SettingsOverlay is missing exact authored nodes: " + ", ".join(missing_settings_nodes))
    settings_model_source = settings_model_path.read_text(encoding="utf-8-sig")
    for asset_id in (
        "81766141914014",
        "74437026548245",
        "94678436497650",
        "130386889052542",
        "70574718515061",
        "92653426073517",
        "81878984079270",
        "107462888144853",
        "131550730293382",
        "110978225407848",
        "79604035889224",
        "107077598572207",
        "75219052415065",
    ):
        if asset_id not in settings_model_source:
            fail(errors, f"SettingsOverlay is missing original asset {asset_id}")
    settings_controller = (
        ROOT / "src/ui/FishingGui/FishingClient/HudControlsModules/SettingsPanelHud.luau"
    ).read_text(encoding="utf-8-sig")
    if "Instance.new" in settings_controller:
        fail(errors, "SettingsPanelHud still constructs fixed UI at runtime")
    for marker in (
        'deps.findAuthoredHost("SettingsOverlay", "Frame")',
        'requiredChild(overlay, "SettingsCanvas", "Frame")',
        'requiredChild(speedRow, "SliderArea", "Frame")',
        'requiredChild(aquariumRow, "TeleportButton", "ImageButton")',
    ):
        if marker not in settings_controller:
            fail(errors, f"SettingsPanelHud is missing authored binding {marker}")

    for model_name, required_nodes in (
        (
            "FishmongerSellOverlay",
            {
                "FishmongerSellPanel",
                "SellAllButton",
                "FishmongerSortBar",
                "FishmongerSellList",
                "Templates",
                "SortButtonTemplate",
                "EmptyStateTemplate",
                "FishSellRowTemplate",
                "SellButton",
            },
        ),
        (
            "RodShopOverlay",
            {
                "RodShopPanel",
                "SupplyShopTabs",
                "RodShopList",
                "Templates",
                "TabButtonTemplate",
                "RodRowTemplate",
                "BaitRowTemplate",
                "ActionButton",
                "BuyButton",
                "EquipButton",
            },
        ),
    ):
        model_path = ROOT / f"src/ui/FishingGui/{model_name}.rbxmx"
        model_names = {
            element.text
            for element in ET.parse(model_path).findall(".//string[@name='Name']")
            if element.text
        }
        missing = sorted(required_nodes - model_names)
        if missing:
            fail(errors, f"{model_name} is missing authored nodes: " + ", ".join(missing))

    fishing_popup_source = (
        ROOT / "src/ui/FishingGui/FishingClient/init.client.luau"
    ).read_text(encoding="utf-8-sig")
    for marker in (
        'AuthoredUi.getSurface("FishmongerSellOverlay")',
        'requiredAuthoredNode(fishmongerUI.templates, "FishSellRowTemplate", "Frame")',
        "fishmongerUI.sortButtonTemplate:Clone()",
        "fishmongerUI.emptyStateTemplate:Clone()",
        'AuthoredUi.getSurface("RodShopOverlay")',
        'requiredAuthoredNode(rodShopUI.templates, "RodRowTemplate", "Frame")',
        'requiredAuthoredNode(rodShopUI.templates, "BaitRowTemplate", "Frame")',
        "rodShopUI.tabButtonTemplate:Clone()",
    ):
        if marker not in fishing_popup_source:
            fail(errors, f"FishingClient popup controller is missing authored binding {marker}")
    if "makePopupListCard" in fishing_popup_source:
        fail(errors, "FishingClient still contains the runtime popup-card constructor")

    main_panel_path = ROOT / "src/ui/FishingGui/MainPanel.rbxmx"
    main_panel_names = {
        element.text
        for element in ET.parse(main_panel_path).findall(".//string[@name='Name']")
        if element.text
    }
    required_main_panel_nodes = {
        "MainPanel",
        "PanelSizeConstraint",
        "PanelTitle",
        "PanelClose",
        "ShopCanvas",
        "ModernShopScale",
        "ModernShopSkin",
        "MainBackbone",
        "SubMainBackbone",
        "DecorationCastle",
        "ModernShopClose",
        "ModernShopTabs",
        "ModernShopScrollTrack",
        "ModernShopScrollThumb",
        "Content",
        "ShopTemplates",
        "ShopTabTemplate",
        "ShopItemCardTemplate",
        "ProductCardTemplate",
        "StatRowTemplate",
        "LegacyMainPanelTemplates",
        "AquariumSummaryTemplate",
        "AquariumFishTemplate",
        "AquariumHubHeaderTemplate",
        "AquariumDirectoryTemplate",
        "AquariumEmptyTemplate",
        "AquariumVisitorTemplate",
        "LoadingLabelTemplate",
    }
    missing_main_panel_nodes = sorted(required_main_panel_nodes - main_panel_names)
    if missing_main_panel_nodes:
        fail(errors, "MainPanel is missing exact authored Shop nodes: " + ", ".join(missing_main_panel_nodes))
    main_panel_source = main_panel_path.read_text(encoding="utf-8-sig")
    for asset_id in (
        "77079984837491",
        "120182750042631",
        "131015417525927",
        "125521996931477",
        "137614054152455",
        "73367138577137",
        "119322438066977",
        "120613246130409",
    ):
        if asset_id not in main_panel_source:
            fail(errors, f"MainPanel Shop is missing original asset {asset_id}")

    for marker in (
        '"LegacyMainPanelTemplates",',
        "mainPanelUI.legacyTemplateRefs[templateName]",
        'authoredLegacyCard("AquariumSummaryTemplate")',
        'authoredLegacyCard("AquariumFishTemplate")',
        'authoredLegacyCard("AquariumDirectoryTemplate")',
        'authoredLegacyCard("AquariumVisitorTemplate")',
        'cloneLegacyMainPanelTemplate("LoadingLabelTemplate"',
        'AuthoredUi.getSurface("AquariumViewerFallbackButton")',
    ):
        if marker not in fishing_popup_source:
            fail(errors, f"FishingClient is missing authored MainPanel binding {marker}")
    if 'guiPrimitives.makeButton(screenGui, "Open Viewer"' in fishing_popup_source:
        fail(errors, "Aquarium Open Viewer button is still constructed at runtime")

    gui_primitives_source = (
        ROOT / "src/ui/FishingGui/FishingClient/GuiPrimitives.luau"
    ).read_text(encoding="utf-8-sig")
    if 'and not child:IsA("UIPadding")' not in gui_primitives_source:
        fail(errors, "MainPanel Content clearing does not preserve authored UIPadding")

    shop_source = (ROOT / "src/ui/FishingGui/FishingClient/ShopModernUI.luau").read_text(
        encoding="utf-8-sig"
    )
    if "Instance.new" in shop_source:
        fail(errors, "ShopModernUI still constructs fixed UI at runtime")
    for marker in (
        'panel:FindFirstChild("ShopTemplates")',
        'boundChild(panel, "ShopCanvas", "Frame")',
        'boundChild(ui.canvas, "ModernShopSkin", "Frame")',
        'cloneTemplate("ShopTabTemplate")',
        'cloneTemplate("ShopItemCardTemplate")',
        'cloneTemplate("ProductCardTemplate")',
        'cloneTemplate("StatRowTemplate")',
    ):
        if marker not in shop_source:
            fail(errors, f"ShopModernUI is missing authored binding {marker}")
    economy_source = (ROOT / "src/starterplayer/EconomyUIIntegration.client.luau").read_text(
        encoding="utf-8-sig"
    )
    if "SeaStarProductOrder" not in shop_source:
        fail(errors, "ShopModernUI does not own Sea Star product rendering")
    if "renderSeaStarsInItems" in economy_source:
        fail(errors, "EconomyUIIntegration still competes for Shop Items rendering")

    if "Instance.new" in economy_source:
        fail(errors, "EconomyUIIntegration still constructs fixed UI at runtime")
    for marker in (
        'fishingGui:FindFirstChild("SeaStarsHud")',
        'authoredHud:FindFirstChild("SeaStarsText")',
        'authoredHud:FindFirstChild("SeaStarCoinStyleVisual")',
        'numberArea:FindFirstChild("DigitsHolder")',
        'button:FindFirstChild("SeaStarThemeLock")',
    ):
        if marker not in economy_source:
            fail(errors, f"EconomyUIIntegration is missing authored binding {marker}")

    bait_model_path = ROOT / "src/ui/FishingGui/BaitIconTemplates.rbxmx"
    bait_model_names = {
        element.text
        for element in ET.parse(bait_model_path).findall(".//string[@name='Name']")
        if element.text
    }
    for name in ("BaitIconTemplates", "BaitIconTemplate"):
        if name not in bait_model_names:
            fail(errors, f"BaitIconTemplates is missing authored node {name}")
    validate_named_scale_type(
        errors,
        bait_model_path,
        "BaitIconTemplate",
        3,  # Enum.ScaleType.Fit
        1,
    )
    bait_source = (ROOT / "src/starterplayer/BaitIconController.client.luau").read_text(
        encoding="utf-8-sig"
    )
    if "Instance.new" in bait_source:
        fail(errors, "BaitIconController still constructs icon UI at runtime")
    for marker in (
        'fishingGui:WaitForChild("BaitIconTemplates")',
        'baitIconTemplates:WaitForChild("BaitIconTemplate")',
        "baitIconTemplate:Clone()",
    ):
        if marker not in bait_source:
            fail(errors, f"BaitIconController is missing authored binding {marker}")

    aquarium_interface_path = ROOT / "src/ui/AquariumFreePlacementGui/Interface.rbxmx"
    aquarium_interface_tree = ET.parse(aquarium_interface_path)
    aquarium_interface_names = {
        element.text
        for element in aquarium_interface_tree.findall(".//string[@name='Name']")
        if element.text
    }
    for name in (
        "BackdropDimmer",
        "OpenButton",
        "BackButton",
        "Panel",
        "ResponsiveScale",
        "AquariumBackbone",
        "LeftDecoration",
        "MainDisplay",
        "MappedMainDisplay",
        "ThemesPanel",
        "DecorPanel",
        "AdjustmentsPanel",
        "AdjustmentsInner",
        "PreviewFrame",
        "ThemesHeader",
        "ThemeGrid",
        "DecorHeader",
        "DecorHint",
        "DecorGrid",
        "AdjustmentsHeader",
        "DepthTrack",
        "PreviewButton",
        "RemoveButton",
        "ApplyButton",
        "ThemeButtonTemplate",
        "DecorButtonTemplate",
        "MarkerTemplate",
        "SeaStarThemeLock",
    ):
        if name not in aquarium_interface_names:
            fail(errors, f"AquariumFreePlacement Interface is missing authored node {name}")
    aquarium_interface_source = aquarium_interface_path.read_text(encoding="utf-8-sig")
    for asset_id in (
        "87835784646088",
        "73798557079455",
        "91056388997818",
        "119322438066977",
        "93391070554478",
        "77785584261234",
        "122540568649709",
        "81143457443906",
        "119386888334158",
        "89729513198581",
        "100275421759931",
        "84469227464999",
        "94712658264920",
        "110797697720551",
        "97923557167562",
        "96038949706970",
    ):
        if asset_id not in aquarium_interface_source:
            fail(errors, f"AquariumFreePlacement Interface is missing original asset {asset_id}")
    sea_star_theme_lock = next(
        (
            item
            for item in aquarium_interface_tree.findall(".//Item")
            if (item.find("./Properties/string[@name='Name']") is not None)
            and item.find("./Properties/string[@name='Name']").text == "SeaStarThemeLock"
        ),
        None,
    )
    sea_star_theme_lock_font = (
        sea_star_theme_lock.find("./Properties/token[@name='Font']")
        if sea_star_theme_lock is not None
        else None
    )
    if sea_star_theme_lock_font is None or sea_star_theme_lock_font.text != "19":
        fail(errors, "Aquarium Sea Star theme lock must use the original GothamBold font")

    aquarium_controller_source = (
        ROOT / "src/ui/AquariumFreePlacementGui/AquariumFreePlacementEditor.client.luau"
    ).read_text(encoding="utf-8-sig")
    if "Instance.new" in aquarium_controller_source:
        fail(errors, "AquariumFreePlacementEditor still constructs fixed UI at runtime")
    for marker in (
        'child(interface, "BackdropDimmer", "Frame")',
        'child(panel, "ResponsiveScale", "UIScale")',
        'child(templates, "ThemeButtonTemplate", "TextButton")',
        'child(templates, "DecorButtonTemplate", "TextButton")',
        'child(templates, "MarkerTemplate", "TextButton")',
        '"rbxassetid://127696915567136"',
        '"rbxassetid://85830007659101"',
        'cloneButton(themeButtonTemplate',
        'cloneButton(decorButtonTemplate',
        'markerTemplate:Clone()',
    ):
        if marker not in aquarium_controller_source:
            fail(errors, f"AquariumFreePlacementEditor is missing authored v1615 binding {marker}")

    viewer_interface_path = ROOT / "src/ui/AquariumViewerGui/Root.rbxmx"
    viewer_interface_tree = ET.parse(viewer_interface_path)
    viewer_names = {
        element.text
        for element in viewer_interface_tree.findall(".//string[@name='Name']")
        if element.text
    }
    for name in (
        "Root",
        "DeviceScale",
        "MyTankPage",
        "ExplorePage",
        "Header",
        "MyTankButton",
        "ExploreButton",
        "CloseButton",
        "MyTankFishList",
        "ExploreVisitorList",
        "ExploreScrollTrack",
        "ExploreScrollThumb",
        "MyTankFishRowTemplate",
        "ExploreVisitorRowTemplate",
    ):
        if name not in viewer_names:
            fail(errors, f"AquariumViewer Interface is missing authored node {name}")
    viewer_interface_source = viewer_interface_path.read_text(encoding="utf-8-sig")
    for asset_id in (
        "131466644643247",
        "127996372815955",
        "104759751456941",
        "125654737802805",
        "102095594840013",
        "109248646612122",
        "121676475074564",
        "107602146669555",
        "105327955653365",
        "109156112056544",
        "105621557357975",
        "90625326453971",
        "84751657680455",
        "92519303171140",
        "140618424967086",
        "81760248223303",
    ):
        if asset_id not in viewer_interface_source:
            fail(errors, f"AquariumViewer Interface is missing uploaded asset {asset_id}")
    viewer_controller_source = (
        ROOT / "src/ui/FishingGui/FishingClient/AquariumViewerModernUI.luau"
    ).read_text(encoding="utf-8-sig")
    if "Instance.new" in viewer_controller_source:
        fail(errors, "AquariumViewerModernUI constructs fixed UI at runtime")
    for marker in (
        'playerGui:WaitForChild("AquariumViewerGui")',
        'descendant(root, "MyTankPage", "Frame")',
        'descendant(root, "ExplorePage", "Frame")',
        'fishTemplate:Clone()',
        'visitorTemplate:Clone()',
        'context.Remote.AquariumAction:FireServer("Upgrade")',
        'kind = "PlayerAquarium"',
    ):
        if marker not in viewer_controller_source:
            fail(errors, f"AquariumViewerModernUI is missing authored binding {marker}")

    daily_source = (ROOT / "src/starterplayer/Phase3EconomyUI.client.luau").read_text(
        encoding="utf-8-sig"
    )
    if "result.Success ~= true" not in daily_source:
        fail(errors, "Daily rewards do not restore Claim after a rejected request")
    if "Instance.new" in daily_source:
        fail(errors, "Phase3EconomyUI still constructs UI instances at runtime")
    for marker in (
        'topHudGui:WaitForChild("TopButtonsFrame")',
        'topButtonsFrame:WaitForChild("TopLoginRewardButton")',
        'WaitForChild("DayCardTemplate")',
        'WaitForChild("RewardLineTemplate")',
        "dayCardTemplate:Clone()",
        "rewardLineTemplate:Clone()",
        "milestoneRewardLineTemplate:Clone()",
        "claimedIconTemplate:Clone()",
        "FreshBaitIcon",
        "isFinalDay",
        "loginButton.MouseButton1Click:Connect(showLogin)",
        "image.ScaleType = Enum.ScaleType.Stretch",
        "applyVirtualCrop(claimButtonArt, TRIMMED_IMAGE_SIZES.ClaimButton, CLAIM_BUTTON_CROP)",
        "applyVirtualCrop(loginScrollbarArt, TRIMMED_IMAGE_SIZES.ScrollBar, {",
        "applyVirtualCrop(cardImage, TRIMMED_IMAGE_SIZES.DayTab, crop)",
    ):
        if marker not in daily_source:
            fail(errors, f"Phase3EconomyUI is missing authored v1615 behavior {marker}")
    for stale_marker in (
        "loginPressScale",
        "IconShadow",
        "TweenService",
    ):
        if stale_marker in daily_source:
            fail(errors, f"Phase3EconomyUI still contains post-v1615 button behavior {stale_marker}")
    for exact_visible_text in (
        'claimButtonLabel.Text = "Loading..."',
        'loginTitle.Text = "Daily Login Rewards"',
        '("Claim Day " .. tostring(login.CurrentDay)) or "Claimed"',
        'dayLabel.Text = "Day " .. tostring(day)',
        '"Daily rewards reset at 24:00 (Server\'s UTC Time)"',
        'add(DAILY_REWARD_ASSETS.SpecialDayIcon, "1 aquarium decoration")',
        'claimButtonLabel.Text = "Claiming..."',
        'result.Success and "Reward claimed." or "Reward unavailable."',
    ):
        if exact_visible_text not in daily_source:
            fail(
                errors,
                "Phase3EconomyUI visible wording differs from v1636: "
                + exact_visible_text,
            )

    quest_source = (ROOT / "src/ui/FishingGui/FishingClient/QuestModernUI.luau").read_text(
        encoding="utf-8-sig"
    )
    for asset_id in (
        "86912435019607",
        "78189475055056",
        "106120450577925",
        "101135473927300",
    ):
        if asset_id not in quest_source:
            fail(errors, f"Quest UI is missing requested asset {asset_id}")
    if "local QUEST_UI_SIZE_MULTIPLIER = 0.72" not in quest_source:
        fail(errors, "Quest UI must preserve the v1615 responsive size multiplier of 0.72")

    quest_model_path = ROOT / "src/ui/FishingGui/ModernQuestUI.rbxmx"
    quest_tree = ET.parse(quest_model_path)
    expected_tab_art = {
        "DailyTab": "rbxassetid://106120450577925",
        "WeeklyTab": "rbxassetid://101135473927300",
        "MonthlyTab": "rbxassetid://101135473927300",
    }
    for tab_name, expected_image in expected_tab_art.items():
        tab_item = find_named_item(quest_tree, tab_name)
        artwork_item = (
            find_named_item(ET.ElementTree(tab_item), "Artwork")
            if tab_item is not None
            else None
        )
        actual_image = content_property(artwork_item, "Image") if artwork_item is not None else None
        if actual_image != expected_image:
            fail(
                errors,
                f"ModernQuestUI.{tab_name}.TabVisual.Artwork must use "
                f"{expected_image}, got {actual_image}",
            )

    if errors:
        print("Authored UI validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        "Authored UI validation passed: "
        f"{len(REQUIRED_SCREENS)} ScreenGuis, "
        f"{len(REQUIRED_FISHING_SURFACES)} FishingGui surfaces, "
        f"{len(iter_active_luau_files())} active controllers/modules checked."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Build a local-import model from the already-validated Rojo place build.

The model intentionally excludes AquariumViewerGui and all map/server content.
It is used only as a Studio import fallback when the Rojo widget cannot render.
"""

from __future__ import annotations

import copy
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


STARTER_GUI_NAMES = {
    "AquariumFreePlacementEditor",
    "AquariumDesignerShopCleanup",
    "FishingGui",
    "TopHudGui",
    "ServerUtcClockGui",
    "Phase3EconomyGui",
    "AquariumFreePlacementGui",
    "CustomHotbarGui",
}

STARTER_PLAYER_SCRIPT_NAMES = {
    "FishingAreaButtonsVisibility",
    "FishingCastAnimation",
    "BaitIconController",
    "EconomyUIIntegration",
    "Phase3EconomyUI",
    "ServerUtcClock",
    "ForceTopHudPosition",
    "SeastarHudOverride",
    "ResponsiveUiAdapter",
    "CustomHotbarClient",
}


def instance_name(item: ET.Element) -> str:
    properties = item.find("Properties")
    if properties is None:
        return ""
    for prop in properties:
        if prop.get("name") == "Name":
            return prop.text or ""
    return ""


def find_service(root: ET.Element, class_name: str) -> ET.Element:
    for item in root.findall("Item"):
        if item.get("class") == class_name:
            return item
    raise RuntimeError(f"Missing service {class_name}")


def new_container(class_name: str, name: str, referent: str) -> ET.Element:
    item = ET.Element("Item", {"class": class_name, "referent": referent})
    properties = ET.SubElement(item, "Properties")
    name_prop = ET.SubElement(properties, "string", {"name": "Name"})
    name_prop.text = name
    return item


def append_named_children(
    destination: ET.Element, source: ET.Element, allowed_names: set[str]
) -> None:
    found: set[str] = set()
    for child in source.findall("Item"):
        name = instance_name(child)
        if name in allowed_names:
            destination.append(copy.deepcopy(child))
            found.add(name)
    missing = allowed_names - found
    if missing:
        raise RuntimeError(f"Missing expected instances: {sorted(missing)}")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract_ui_import_model.py INPUT.rbxlx OUTPUT.rbxm")

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    source_root = ET.parse(input_path).getroot()

    output_root = ET.Element("roblox", {"version": "4"})
    model = new_container("Model", "FishyFishUiImport", "UI_IMPORT_ROOT")
    starter_gui_folder = new_container("Folder", "StarterGui", "UI_IMPORT_STARTERGUI")
    starter_scripts_folder = new_container(
        "Folder", "StarterPlayerScripts", "UI_IMPORT_STARTERPLAYERSCRIPTS"
    )

    starter_gui = find_service(source_root, "StarterGui")
    append_named_children(starter_gui_folder, starter_gui, STARTER_GUI_NAMES)

    starter_player = find_service(source_root, "StarterPlayer")
    starter_player_scripts = next(
        child
        for child in starter_player.findall("Item")
        if instance_name(child) == "StarterPlayerScripts"
    )
    append_named_children(
        starter_scripts_folder,
        starter_player_scripts,
        STARTER_PLAYER_SCRIPT_NAMES,
    )

    model.append(starter_gui_folder)
    model.append(starter_scripts_folder)
    output_root.append(model)
    ET.indent(output_root, space="  ")
    ET.ElementTree(output_root).write(output_path, encoding="utf-8", xml_declaration=False)

    print(
        f"Wrote {output_path} with {len(STARTER_GUI_NAMES)} StarterGui instances "
        f"and {len(STARTER_PLAYER_SCRIPT_NAMES)} StarterPlayerScripts instances."
    )


if __name__ == "__main__":
    main()

from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: install_v1636_decor_controller.py REFERENCE_SOURCE TARGET_SOURCE")
        return 2

    source = Path(sys.argv[1]).read_text(encoding="utf-8")
    old_owner = '''local existingGui = playerGui:FindFirstChild("AquariumFreePlacementGui")
if existingGui then
\texistingGui:Destroy()
end'''
    new_owner = '''local existingGui = script.Parent
if not existingGui:IsA("ScreenGui") then
\twarn("[AquariumFreePlacementEditor] Expected AquariumFreePlacementGui ScreenGui parent")
\treturn
end'''
    if old_owner not in source:
        raise RuntimeError("Could not find v1636 existing GUI ownership block")
    source = source.replace(old_owner, new_owner, 1)

    old_builder = 'local gui = Instance.new("ScreenGui")'
    new_builder = '''local gui = existingGui
for _, child in ipairs(gui:GetChildren()) do
\tif child ~= script then
\t\tchild:Destroy()
\tend
end'''
    if old_builder not in source:
        raise RuntimeError("Could not find v1636 ScreenGui construction")
    source = source.replace(old_builder, new_builder, 1)

    Path(sys.argv[2]).write_text(source, encoding="utf-8")
    print(f"Installed the exact v1636 Decor Editor controller at {sys.argv[2]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import argparse
import json
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from compare_authored_ui_to_runtime_dump import (
    PROPERTIES,
    name_of,
    normalize_authored,
    normalize_golden,
    scalar,
    values_equal,
)


@dataclass
class Node:
    class_name: str
    name: str
    props: dict[str, Any]
    children: list["Node"] = field(default_factory=list)


def golden_subtree(path: Path, root_path: str) -> Node:
    items = json.loads(path.read_text(encoding="utf-8"))["items"]
    root_index = next(index for index, item in enumerate(items) if item["path"] == root_path)
    root_depth = root_path.count("/")
    selected = []
    for item in items[root_index:]:
        depth = item["path"].count("/")
        if selected and depth <= root_depth:
            break
        selected.append(item)

    stack: list[tuple[int, Node]] = []
    root = None
    for item in selected:
        depth = item["path"].count("/")
        node = Node(item["class"], item["name"], item.get("props", {}))
        while stack and stack[-1][0] >= depth:
            stack.pop()
        if stack:
            stack[-1][1].children.append(node)
        else:
            root = node
        stack.append((depth, node))
    if root is None:
        raise KeyError(root_path)
    return root


def authored_node(item: ET.Element) -> Node:
    props = {}
    properties = item.find("Properties")
    if properties is not None:
        for value in properties:
            prop_name = value.attrib.get("name")
            if prop_name in PROPERTIES:
                props[prop_name] = scalar(value)
    return Node(
        item.attrib.get("class", "Item"),
        name_of(item),
        props,
        [authored_node(child) for child in item.findall("Item")],
    )


def authored_subtree(path: Path, root_path: str) -> Node:
    parts = root_path.split("/")
    current = None
    children = ET.parse(path).getroot().findall("Item")
    for part in parts:
        current = next((item for item in children if name_of(item) == part), None)
        if current is None:
            raise KeyError(root_path)
        children = current.findall("Item")
    return authored_node(current)


def inert(expected: Node, actual: Node, prop: str) -> bool:
    return prop == "BackgroundColor3" and (
        expected.props.get("BackgroundTransparency") == 1
        and actual.props.get("BackgroundTransparency") == 1
    )


def compare(expected: Node, actual: Node, path: str, differences: list, missing: list) -> None:
    if expected.class_name != actual.class_name:
        differences.append((path, "ClassName", expected.class_name, actual.class_name))
    for prop in PROPERTIES:
        if prop not in expected.props or prop not in actual.props:
            continue
        left = normalize_golden(expected.props[prop])
        right = normalize_authored(actual.props[prop], prop)
        if not values_equal(left, right) and not inert(expected, actual, prop):
            differences.append((path, prop, left, right))

    # Authored migration nodes are deliberately renamed. Pair siblings by
    # their stable visual order and class, then report only genuine omissions.
    cursor = 0
    for expected_child in expected.children:
        match_index = None
        for index in range(cursor, len(actual.children)):
            if actual.children[index].class_name == expected_child.class_name:
                match_index = index
                break
        if match_index is None:
            missing.append(f"{path}/{expected_child.name} ({expected_child.class_name})")
            continue
        actual_child = actual.children[match_index]
        cursor = match_index + 1
        compare(
            expected_child,
            actual_child,
            f"{path}/{expected_child.name}->{actual_child.name}",
            differences,
            missing,
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("golden", type=Path)
    parser.add_argument("golden_root")
    parser.add_argument("authored", type=Path)
    parser.add_argument("authored_root")
    args = parser.parse_args()

    expected = golden_subtree(args.golden, args.golden_root)
    actual = authored_subtree(args.authored, args.authored_root)
    differences: list = []
    missing: list = []
    compare(expected, actual, expected.name + "->" + actual.name, differences, missing)
    print(f"ordered visual differences: {len(differences)}")
    for path, prop, expected_value, actual_value in differences:
        print(f"{path}\t{prop}\t{expected_value!r}\t{actual_value!r}")
    print(f"ordered missing nodes: {len(missing)}")
    for path in missing:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

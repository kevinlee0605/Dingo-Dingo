#!/usr/bin/env python3
"""Recover the legacy serialized FishingClient into a Rojo source tree.

The authored UI migration intentionally changes the extracted files after the
initial recovery. Writing over that active tree would discard those fixes, so
reconciliation now requires an explicit ``--force`` flag. Prefer a separate
``--output`` directory when inspecting the old rollback model.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path, PurePosixPath


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = REPO_ROOT / "src" / "startergui" / "FishingClient_Rollback1568.rbxmx"
DEFAULT_OUTPUT = REPO_ROOT / "src" / "ui" / "FishingGui" / "FishingClient"

SCRIPT_SUFFIXES = {
    "ModuleScript": ".luau",
    "LocalScript": ".client.luau",
    "Script": ".server.luau",
}
SAFE_INSTANCE_NAME = re.compile(r"^[A-Za-z0-9_. -]+$")


class ExtractionError(RuntimeError):
    """Raised when the serialized hierarchy cannot be mapped without loss."""


def _property(item: ET.Element, property_name: str) -> str | None:
    properties = item.find("Properties")
    if properties is None:
        return None

    for element in properties:
        if element.get("name") == property_name:
            return element.text or ""
    return None


def _instance_name(item: ET.Element) -> str:
    name = _property(item, "Name")
    if not name:
        raise ExtractionError(f"{item.get('class', '<unknown>')} has no Name property")
    if name in {".", ".."} or not SAFE_INSTANCE_NAME.fullmatch(name):
        raise ExtractionError(f"unsafe instance name: {name!r}")
    return name


def _script_source(item: ET.Element) -> str:
    source = _property(item, "Source")
    if source is None:
        raise ExtractionError(f"script {_instance_name(item)!r} has no Source property")
    return source


def _collect_children(
    parent: ET.Element,
    destination: PurePosixPath,
    output: dict[PurePosixPath, bytes],
) -> None:
    for child in parent.findall("Item"):
        class_name = child.get("class")
        name = _instance_name(child)

        if class_name == "Folder":
            _collect_children(child, destination / name, output)
            continue

        suffix = SCRIPT_SUFFIXES.get(class_name or "")
        if suffix is None:
            raise ExtractionError(
                f"unsupported child {name!r} ({class_name!r}); refusing to skip it"
            )

        relative_path = destination / f"{name}{suffix}"
        if relative_path in output:
            raise ExtractionError(f"duplicate output path: {relative_path}")
        output[relative_path] = _script_source(child).encode("utf-8")


def extract_sources(model_path: Path) -> dict[PurePosixPath, bytes]:
    try:
        document = ET.parse(model_path)
    except (OSError, ET.ParseError) as exc:
        raise ExtractionError(f"could not parse {model_path}: {exc}") from exc

    root_items = document.getroot().findall("Item")
    if len(root_items) != 1:
        raise ExtractionError(f"expected one root Item, found {len(root_items)}")

    root_script = root_items[0]
    root_class = root_script.get("class")
    root_name = _instance_name(root_script)
    if root_class != "LocalScript" or root_name != "FishingClient":
        raise ExtractionError(
            "expected root LocalScript named 'FishingClient', "
            f"found {root_class!r} named {root_name!r}"
        )

    output: dict[PurePosixPath, bytes] = {
        PurePosixPath("init.client.luau"): _script_source(root_script).encode("utf-8")
    }
    _collect_children(root_script, PurePosixPath(), output)
    return dict(sorted(output.items(), key=lambda pair: pair[0].as_posix()))


def _existing_files(output_dir: Path) -> set[PurePosixPath]:
    if not output_dir.exists():
        return set()
    if output_dir.is_symlink() or not output_dir.is_dir():
        raise ExtractionError(f"output is not a real directory: {output_dir}")

    files: set[PurePosixPath] = set()
    for path in output_dir.rglob("*"):
        if path.is_symlink():
            raise ExtractionError(f"refusing to modify symlink in output tree: {path}")
        if path.is_file():
            files.add(PurePosixPath(path.relative_to(output_dir).as_posix()))
    return files


def _read_bytes(output_dir: Path, relative_path: PurePosixPath) -> bytes | None:
    path = output_dir.joinpath(*relative_path.parts)
    try:
        return path.read_bytes()
    except FileNotFoundError:
        return None


def differences(
    expected: dict[PurePosixPath, bytes], output_dir: Path
) -> tuple[list[PurePosixPath], list[PurePosixPath], list[PurePosixPath]]:
    actual_paths = _existing_files(output_dir)
    expected_paths = set(expected)
    missing = sorted(expected_paths - actual_paths, key=PurePosixPath.as_posix)
    extra = sorted(actual_paths - expected_paths, key=PurePosixPath.as_posix)
    changed = sorted(
        (
            path
            for path in expected_paths & actual_paths
            if _read_bytes(output_dir, path) != expected[path]
        ),
        key=PurePosixPath.as_posix,
    )
    return missing, changed, extra


def reconcile(expected: dict[PurePosixPath, bytes], output_dir: Path) -> None:
    # DEFAULT_OUTPUT is the only tree cleaned by a no-argument invocation. A
    # custom output is still allowed, but must not be the repository root.
    resolved_output = output_dir.resolve()
    if resolved_output == REPO_ROOT.resolve() or REPO_ROOT.resolve() not in resolved_output.parents:
        raise ExtractionError(f"output must be below the repository root: {output_dir}")

    if output_dir.exists() and output_dir.is_symlink():
        raise ExtractionError(f"refusing to replace output symlink: {output_dir}")

    output_dir.mkdir(parents=True, exist_ok=True)
    actual_paths = _existing_files(output_dir)
    expected_paths = set(expected)

    for relative_path in sorted(actual_paths - expected_paths, key=PurePosixPath.as_posix):
        output_dir.joinpath(*relative_path.parts).unlink()

    for relative_path, source in expected.items():
        destination = output_dir.joinpath(*relative_path.parts)
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists() or destination.read_bytes() != source:
            destination.write_bytes(source)

    # Remove directories left empty by stale generated sources, deepest first.
    for directory in sorted(
        (path for path in output_dir.rglob("*") if path.is_dir()),
        key=lambda path: len(path.parts),
        reverse=True,
    ):
        try:
            directory.rmdir()
        except OSError:
            pass


def _format_paths(label: str, paths: list[PurePosixPath]) -> str:
    return f"{label}: " + ", ".join(path.as_posix() for path in paths)


def validate(expected: dict[PurePosixPath, bytes], output_dir: Path) -> None:
    missing, changed, extra = differences(expected, output_dir)
    messages: list[str] = []
    if missing:
        messages.append(_format_paths("missing", missing))
    if changed:
        messages.append(_format_paths("changed", changed))
    if extra:
        messages.append(_format_paths("extra", extra))
    if messages:
        raise ExtractionError("output tree does not match model\n  " + "\n  ".join(messages))

    # Verify source equality again directly and report deterministic hashes.
    for relative_path, source in expected.items():
        written = _read_bytes(output_dir, relative_path)
        if written != source:
            raise ExtractionError(f"source verification failed: {relative_path}")
        digest = hashlib.sha256(source).hexdigest()
        print(f"{digest}  {relative_path.as_posix()}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--check",
        action="store_true",
        help="validate the existing output tree without modifying it",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="allow reconciliation; this can overwrite migrated source files",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source_path = args.source.resolve()
    output_dir = args.output.resolve()

    try:
        expected = extract_sources(source_path)
        if not args.check:
            if not args.force:
                raise ExtractionError(
                    "refusing to overwrite migrated sources without --force; "
                    "use --output with a separate directory for recovery"
                )
            reconcile(expected, output_dir)
        validate(expected, output_dir)
    except ExtractionError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"verified {len(expected)} scripts from {source_path} in {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

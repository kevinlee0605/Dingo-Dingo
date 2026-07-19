import json
import sys
from pathlib import Path


root = Path(sys.argv[1])
needle = sys.argv[2]
limit = int(sys.argv[3]) if len(sys.argv) > 3 else 4000


def walk_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from walk_strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_strings(child)


for path in sorted(root.rglob("*.jsonl")):
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line_number, line in enumerate(handle, 1):
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            matching = [text for text in walk_strings(record) if needle in text]
            if not matching:
                continue
            print(f"\n=== {path}:{line_number} {record.get('timestamp', '')} ===")
            payload = record.get("payload", {})
            print("record_type:", record.get("type"), "payload_type:", payload.get("type"))
            for text in matching:
                index = text.find(needle)
                start = max(0, index - limit // 3)
                end = min(len(text), index + (limit * 2 // 3))
                excerpt = text[start:end]
                if start:
                    excerpt = "..." + excerpt
                if end < len(text):
                    excerpt += "..."
                print(excerpt)

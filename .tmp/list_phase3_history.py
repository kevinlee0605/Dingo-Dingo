import json
import sys
from pathlib import Path


root = Path(sys.argv[1])
needle = sys.argv[2]


for path in sorted(root.rglob("*.jsonl")):
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line_number, line in enumerate(handle, 1):
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if record.get("type") != "response_item":
                continue
            payload = record.get("payload", {})
            if payload.get("type") not in {"custom_tool_call", "function_call"}:
                continue
            content = payload.get("input") or payload.get("arguments") or payload.get("code") or ""
            if not isinstance(content, str) or needle not in content:
                continue
            one_line = " ".join(content.split())
            print(
                f"{record.get('timestamp', '')}\t{path.name}:{line_number}\t"
                f"{payload.get('name', payload.get('tool_name', ''))}\t{len(content)}\t"
                f"{one_line[:500]}"
            )

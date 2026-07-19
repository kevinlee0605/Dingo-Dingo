import json
import sys
from pathlib import Path


root = Path(sys.argv[1])
needle = sys.argv[2].casefold()
paths = [root] if root.is_file() else sorted(root.rglob("*.jsonl"))
for path in paths:
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line_number, line in enumerate(handle, 1):
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if record.get("type") != "response_item":
                continue
            payload = record.get("payload", {})
            if payload.get("type") != "message" or payload.get("role") != "user":
                continue
            parts = payload.get("content", [])
            text = "\n".join(
                part.get("text", "")
                for part in parts
                if isinstance(part, dict) and isinstance(part.get("text"), str)
            )
            if needle not in text.casefold() or "TRANSCRIPT DELTA START" in text:
                continue
            index = text.casefold().find(needle)
            print(
                f"{record.get('timestamp', '')}\t{path.name}:{line_number}\n"
                + text[max(0, index - 500) : index + 2000]
                + "\n"
            )

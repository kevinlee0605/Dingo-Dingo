import json
import sys
from pathlib import Path


path = Path(sys.argv[1])
start_line = int(sys.argv[2]) if len(sys.argv) > 2 else 1
end_line = int(sys.argv[3]) if len(sys.argv) > 3 else 10**12

with path.open("r", encoding="utf-8", errors="replace") as handle:
    for line_number, line in enumerate(handle, 1):
        if line_number < start_line or line_number > end_line:
            continue
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue
        if record.get("type") != "response_item":
            continue
        payload = record.get("payload", {})
        payload_type = payload.get("type")
        if payload_type == "message":
            role = payload.get("role", "")
            chunks = []
            for part in payload.get("content", []):
                if isinstance(part, dict):
                    value = part.get("text") or part.get("input_text") or part.get("output_text")
                    if isinstance(value, str):
                        chunks.append(value)
            text = "\n".join(chunks)
            if "TRANSCRIPT DELTA START" in text:
                continue
            compact = " ".join(text.split())
            print(f"{line_number}\t{record.get('timestamp', '')}\t{role}\t{compact[:1000]}")
        elif payload_type in {"custom_tool_call", "function_call"}:
            value = payload.get("input") or payload.get("arguments") or payload.get("code") or ""
            if isinstance(value, str):
                value = " ".join(value.split())
            print(
                f"{line_number}\t{record.get('timestamp', '')}\ttool:{payload.get('name', payload.get('tool_name', ''))}\t"
                f"{str(value)[:1000]}"
            )
        elif payload_type in {"custom_tool_call_output", "function_call_output"}:
            value = payload.get("output") or payload.get("content") or ""
            if not isinstance(value, str):
                value = json.dumps(value, ensure_ascii=False)
            compact = " ".join(value.split())
            print(f"{line_number}\t{record.get('timestamp', '')}\ttool-result\t{compact[:4000]}")

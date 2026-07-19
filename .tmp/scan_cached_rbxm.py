import struct
import sys
from pathlib import Path


def lz4_decompress(block: bytes, expected: int) -> bytes:
    output = bytearray()
    index = 0
    while index < len(block):
        token = block[index]
        index += 1

        literal_length = token >> 4
        if literal_length == 15:
            while True:
                value = block[index]
                index += 1
                literal_length += value
                if value != 255:
                    break
        output.extend(block[index : index + literal_length])
        index += literal_length
        if index >= len(block):
            break

        offset = block[index] | (block[index + 1] << 8)
        index += 2
        if offset <= 0 or offset > len(output):
            raise ValueError(f"invalid LZ4 offset {offset}")

        match_length = token & 0x0F
        if match_length == 15:
            while True:
                value = block[index]
                index += 1
                match_length += value
                if value != 255:
                    break
        match_length += 4
        start = len(output) - offset
        for position in range(match_length):
            output.append(output[start + position])

    if expected and len(output) != expected:
        raise ValueError(f"LZ4 length {len(output)} != {expected}")
    return bytes(output)


def unpack_rbxh(path: Path) -> bytes | None:
    data = path.read_bytes()
    marker = data.find(b"<roblox!\x89\xff\r\n\x1a\n")
    if marker < 0:
        return None
    return data[marker:]


def iter_chunks(data: bytes):
    if len(data) < 32:
        return
    index = 32
    while index + 16 <= len(data):
        name = data[index : index + 4]
        compressed_length, uncompressed_length, _reserved = struct.unpack_from(
            "<III", data, index + 4
        )
        index += 16
        stored_length = compressed_length or uncompressed_length
        if stored_length < 0 or index + stored_length > len(data):
            return
        stored = data[index : index + stored_length]
        index += stored_length
        if compressed_length:
            try:
                content = lz4_decompress(stored, uncompressed_length)
            except (IndexError, ValueError):
                content = b""
        else:
            content = stored
        yield name, content
        if name == b"END\x00":
            return


root = Path(sys.argv[1])
needles = [value.encode("utf-8") for value in sys.argv[2:]]
candidate_count = 0
parsed_count = 0
for path in root.rglob("*"):
    if not path.is_file():
        continue
    try:
        data = unpack_rbxh(path)
    except OSError:
        continue
    if data is None:
        continue
    candidate_count += 1
    combined = bytearray()
    chunk_names = []
    for name, content in iter_chunks(data):
        chunk_names.append(name)
        combined.extend(content)
    if chunk_names:
        parsed_count += 1
    if needles and not any(needle in combined for needle in needles):
        continue
    print(path, path.stat().st_size, [name.decode("latin1") for name in chunk_names])
    for needle in needles:
        index = combined.find(needle)
        if index >= 0:
            excerpt = combined[max(0, index - 200) : index + 500]
            print(excerpt.decode("utf-8", errors="replace"))

print(f"candidates={candidate_count} parsed={parsed_count}")

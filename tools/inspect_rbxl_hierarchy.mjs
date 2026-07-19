import fs from "node:fs";
import zlib from "node:zlib";

function readUInt32LE(buffer, offset) {
  return buffer.readUInt32LE(offset);
}

function readString(buffer, cursor) {
  const length = readUInt32LE(buffer, cursor.offset);
  cursor.offset += 4;
  const value = buffer.subarray(cursor.offset, cursor.offset + length).toString("utf8");
  cursor.offset += length;
  return value;
}

function decodeReferents(buffer, cursor, count) {
  const start = cursor.offset;
  const output = new Array(count);
  let previous = 0;
  for (let index = 0; index < count; index += 1) {
    let encoded = 0;
    for (let byteIndex = 0; byteIndex < 4; byteIndex += 1) {
      encoded = (encoded << 8) | buffer[start + byteIndex * count + index];
    }
    const delta = (encoded >>> 1) ^ -(encoded & 1);
    previous += delta;
    output[index] = previous;
  }
  cursor.offset += count * 4;
  return output;
}

function readChunks(fileBuffer) {
  const chunks = [];
  let offset = 32;
  while (offset + 16 <= fileBuffer.length) {
    const signature = fileBuffer.subarray(offset, offset + 4).toString("ascii");
    const compressedLength = readUInt32LE(fileBuffer, offset + 4);
    const uncompressedLength = readUInt32LE(fileBuffer, offset + 8);
    const payloadStart = offset + 16;
    const storedLength = compressedLength === 0 ? uncompressedLength : compressedLength;
    const payload = fileBuffer.subarray(payloadStart, payloadStart + storedLength);
    const data = compressedLength === 0 ? payload : zlib.zstdDecompressSync(payload);
    chunks.push({ signature, data });
    offset = payloadStart + storedLength;
    if (signature === "END\0") break;
  }
  return chunks;
}

function readHierarchy(inputPath) {
  const chunks = readChunks(fs.readFileSync(inputPath));
  const classes = new Map();
  const instances = new Map();
  const properties = [];
  const parents = [];
  for (const chunk of chunks) {
    if (chunk.signature === "INST") {
      const cursor = { offset: 0 };
      const classId = readUInt32LE(chunk.data, cursor.offset);
      cursor.offset += 4;
      const className = readString(chunk.data, cursor);
      cursor.offset += 1;
      const count = readUInt32LE(chunk.data, cursor.offset);
      cursor.offset += 4;
      const referents = decodeReferents(chunk.data, cursor, count);
      classes.set(classId, { className, referents });
      for (const referent of referents) {
        instances.set(referent, { referent, className, name: null, parent: -1 });
      }
    } else if (chunk.signature === "PROP") {
      properties.push(chunk.data);
    } else if (chunk.signature === "PRNT") {
      parents.push(chunk.data);
    }
  }

  for (const data of properties) {
    const cursor = { offset: 0 };
    const classId = readUInt32LE(data, cursor.offset);
    cursor.offset += 4;
    const propertyName = readString(data, cursor);
    const typeId = data[cursor.offset];
    cursor.offset += 1;
    const classInfo = classes.get(classId);
    if (!classInfo || propertyName !== "Name" || typeId !== 0x01) continue;
    for (const referent of classInfo.referents) {
      const instance = instances.get(referent);
      const value = readString(data, cursor);
      if (instance) instance.name = value;
    }
  }

  for (const data of parents) {
    const cursor = { offset: 1 };
    const count = readUInt32LE(data, cursor.offset);
    cursor.offset += 4;
    const children = decodeReferents(data, cursor, count);
    const parentReferents = decodeReferents(data, cursor, count);
    for (let index = 0; index < count; index += 1) {
      const instance = instances.get(children[index]);
      if (instance) instance.parent = parentReferents[index];
    }
  }

  function fullName(instance) {
    const pieces = [];
    const seen = new Set();
    let current = instance;
    while (current && !seen.has(current.referent)) {
      seen.add(current.referent);
      pieces.push(current.name ?? `<${current.className}>`);
      current = instances.get(current.parent);
    }
    return pieces.reverse().join(".");
  }

  return [...instances.values()].map((instance) => ({
    ...instance,
    path: fullName(instance),
  }));
}

if (process.argv.length < 3 || process.argv.length > 4) {
  console.error("Usage: node inspect_rbxl_hierarchy.mjs INPUT.rbxl [PATH_REGEX]");
  process.exit(2);
}

const instances = readHierarchy(process.argv[2]);
const needles = process.argv[3]
  ? new RegExp(process.argv[3], "i")
  : /(rod|fish|bluegill|bass|world|assets|template)/i;
for (const instance of instances.filter((item) => needles.test(item.path)).sort((a, b) => a.path.localeCompare(b.path))) {
  console.log(`${instance.className}\t${instance.path}`);
}

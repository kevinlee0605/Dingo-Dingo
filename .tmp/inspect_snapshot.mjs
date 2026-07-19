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
  const interleavedLength = count * 4;
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

  cursor.offset += interleavedLength;
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

function encodeReferents(values) {
  const count = values.length;
  const output = Buffer.alloc(count * 4);
  let previous = 0;

  for (let index = 0; index < count; index += 1) {
    const delta = (values[index] - previous) | 0;
    previous = values[index];
    const encoded = ((delta << 1) ^ (delta >> 31)) >>> 0;
    output[index] = (encoded >>> 24) & 0xff;
    output[count + index] = (encoded >>> 16) & 0xff;
    output[count * 2 + index] = (encoded >>> 8) & 0xff;
    output[count * 3 + index] = encoded & 0xff;
  }

  return output;
}

function readRawChunks(fileBuffer) {
  const chunks = [];
  let offset = 32;

  while (offset + 16 <= fileBuffer.length) {
    const signatureBuffer = fileBuffer.subarray(offset, offset + 4);
    const signature = signatureBuffer.toString("ascii");
    const compressedLength = readUInt32LE(fileBuffer, offset + 4);
    const uncompressedLength = readUInt32LE(fileBuffer, offset + 8);
    const reserved = Buffer.from(fileBuffer.subarray(offset + 12, offset + 16));
    const payloadStart = offset + 16;
    const storedLength = compressedLength === 0 ? uncompressedLength : compressedLength;
    const payload = fileBuffer.subarray(payloadStart, payloadStart + storedLength);
    const data = compressedLength === 0 ? Buffer.from(payload) : zlib.zstdDecompressSync(payload);

    chunks.push({ signature, signatureBuffer: Buffer.from(signatureBuffer), reserved, data });
    offset = payloadStart + storedLength;
    if (signature === "END\0") break;
  }

  return chunks;
}

export function rewriteSnapshotAsSingleRootModel(inputPath, outputPath) {
  const fileBuffer = fs.readFileSync(inputPath);
  const chunks = readRawChunks(fileBuffer);
  const classes = new Map();
  let workspaceReferent = null;

  for (const chunk of chunks) {
    if (chunk.signature !== "INST") continue;
    const cursor = { offset: 0 };
    const classId = readUInt32LE(chunk.data, cursor.offset);
    cursor.offset += 4;
    const className = readString(chunk.data, cursor);
    cursor.offset += 1;
    const count = readUInt32LE(chunk.data, cursor.offset);
    cursor.offset += 4;
    const referents = decodeReferents(chunk.data, cursor, count);
    classes.set(classId, { className, referents });
    if (className === "Workspace" && referents.length === 1) workspaceReferent = referents[0];
  }

  if (workspaceReferent == null) throw new Error("Workspace referent was not found");

  let reparentedRoots = 0;
  for (const chunk of chunks) {
    if (chunk.signature !== "PRNT") continue;
    const cursor = { offset: 0 };
    const version = chunk.data[cursor.offset];
    cursor.offset += 1;
    const count = readUInt32LE(chunk.data, cursor.offset);
    cursor.offset += 4;
    const children = decodeReferents(chunk.data, cursor, count);
    const parents = decodeReferents(chunk.data, cursor, count);
    for (let index = 0; index < count; index += 1) {
      if (parents[index] === -1 && children[index] !== workspaceReferent) {
        parents[index] = workspaceReferent;
        reparentedRoots += 1;
      }
    }

    const rebuilt = Buffer.alloc(5 + count * 8);
    rebuilt[0] = version;
    rebuilt.writeUInt32LE(count, 1);
    encodeReferents(children).copy(rebuilt, 5);
    encodeReferents(parents).copy(rebuilt, 5 + count * 4);
    chunk.data = rebuilt;
  }

  const outputParts = [Buffer.from(fileBuffer.subarray(0, 32))];
  for (const chunk of chunks) {
    const shouldCompress = chunk.signature !== "END\0";
    const payload = shouldCompress ? zlib.zstdCompressSync(chunk.data) : chunk.data;
    const header = Buffer.alloc(16);
    chunk.signatureBuffer.copy(header, 0);
    header.writeUInt32LE(shouldCompress ? payload.length : 0, 4);
    header.writeUInt32LE(chunk.data.length, 8);
    chunk.reserved.copy(header, 12);
    outputParts.push(header, payload);
  }

  fs.writeFileSync(outputPath, Buffer.concat(outputParts));
  return { workspaceReferent, reparentedRoots, outputPath };
}

export function extractNamedItemFromXml(inputPath, outputPath, itemName) {
  const xml = fs.readFileSync(inputPath, "utf8");
  const marker = `<string name="Name">${itemName}</string>`;
  const markerIndex = xml.indexOf(marker);
  if (markerIndex < 0) throw new Error(`Could not find ${marker}`);

  const itemStart = xml.lastIndexOf("<Item", markerIndex);
  if (itemStart < 0) throw new Error(`Could not find the Item containing ${itemName}`);

  const itemTagPattern = /<Item\b|<\/Item>/g;
  itemTagPattern.lastIndex = itemStart;
  let depth = 0;
  let itemEnd = -1;
  let match;
  while ((match = itemTagPattern.exec(xml)) !== null) {
    if (match[0] === "</Item>") {
      depth -= 1;
      if (depth === 0) {
        itemEnd = itemTagPattern.lastIndex;
        break;
      }
    } else {
      depth += 1;
    }
  }
  if (itemEnd < 0) throw new Error(`Could not find the end of ${itemName}`);

  const sharedStart = xml.indexOf("<SharedStrings>");
  const sharedEndMarker = "</SharedStrings>";
  const sharedEnd = sharedStart >= 0 ? xml.indexOf(sharedEndMarker, sharedStart) : -1;
  const sharedStrings = sharedStart >= 0 && sharedEnd >= 0
    ? xml.slice(sharedStart, sharedEnd + sharedEndMarker.length)
    : "";

  const itemXml = xml.slice(itemStart, itemEnd);
  const output = `<roblox version="4">\n${itemXml}\n${sharedStrings}\n</roblox>\n`;
  fs.writeFileSync(outputPath, output, "utf8");
  return {
    itemName,
    itemBytes: Buffer.byteLength(itemXml),
    sharedStringBytes: Buffer.byteLength(sharedStrings),
    outputBytes: Buffer.byteLength(output),
    outputPath,
  };
}

export function inspectSnapshot(filePath) {
  const fileBuffer = fs.readFileSync(filePath);
  const chunks = readChunks(fileBuffer);
  const classes = new Map();
  const instances = new Map();
  const propertyChunks = [];
  const parentChunks = [];

  for (const chunk of chunks) {
    if (chunk.signature === "INST") {
      const cursor = { offset: 0 };
      const classId = readUInt32LE(chunk.data, cursor.offset);
      cursor.offset += 4;
      const className = readString(chunk.data, cursor);
      const isService = chunk.data[cursor.offset] !== 0;
      cursor.offset += 1;
      const count = readUInt32LE(chunk.data, cursor.offset);
      cursor.offset += 4;
      const referents = decodeReferents(chunk.data, cursor, count);
      classes.set(classId, { classId, className, isService, count, referents });
      for (const referent of referents) {
        instances.set(referent, { referent, classId, className, name: null, parent: -1 });
      }
    } else if (chunk.signature === "PROP") {
      propertyChunks.push(chunk.data);
    } else if (chunk.signature === "PRNT") {
      parentChunks.push(chunk.data);
    }
  }

  for (const data of propertyChunks) {
    const cursor = { offset: 0 };
    const classId = readUInt32LE(data, cursor.offset);
    cursor.offset += 4;
    const propertyName = readString(data, cursor);
    const typeId = data[cursor.offset];
    cursor.offset += 1;
    if (propertyName !== "Name" || typeId !== 0x01) continue;

    const classInfo = classes.get(classId);
    if (!classInfo) continue;
    for (const referent of classInfo.referents) {
      const name = readString(data, cursor);
      const instance = instances.get(referent);
      if (instance) instance.name = name;
    }
  }

  for (const data of parentChunks) {
    const cursor = { offset: 0 };
    cursor.offset += 1;
    const count = readUInt32LE(data, cursor.offset);
    cursor.offset += 4;
    const children = decodeReferents(data, cursor, count);
    const parents = decodeReferents(data, cursor, count);
    for (let index = 0; index < count; index += 1) {
      const instance = instances.get(children[index]);
      if (instance) instance.parent = parents[index];
    }
  }

  const childrenByParent = new Map();
  for (const instance of instances.values()) {
    const children = childrenByParent.get(instance.parent) ?? [];
    children.push(instance.referent);
    childrenByParent.set(instance.parent, children);
  }

  function descendantCount(referent) {
    let count = 0;
    const pending = [...(childrenByParent.get(referent) ?? [])];
    while (pending.length) {
      const child = pending.pop();
      count += 1;
      pending.push(...(childrenByParent.get(child) ?? []));
    }
    return count;
  }

  function fullName(instance) {
    const pieces = [];
    let current = instance;
    const seen = new Set();
    while (current && !seen.has(current.referent)) {
      seen.add(current.referent);
      pieces.push(current.name ?? `<${current.className}>`);
      current = instances.get(current.parent);
    }
    return pieces.reverse().join(".");
  }

  const targets = [...instances.values()]
    .filter((instance) =>
      instance.name === "LobbyArea"
      || instance.name === "Terrain"
      || instance.name?.includes("LimestoneLobby")
      || instance.name === "FishyFishWorld"
    )
    .map((instance) => ({
      referent: instance.referent,
      className: instance.className,
      name: instance.name,
      fullName: fullName(instance),
      directChildren: (childrenByParent.get(instance.referent) ?? []).length,
      descendants: descendantCount(instance.referent),
    }));

  const classSummary = [...classes.values()]
    .map(({ className, count }) => ({ className, count }))
    .sort((left, right) => right.count - left.count);

  return {
    fileSize: fileBuffer.length,
    chunkCount: chunks.length,
    instanceCount: instances.size,
    targets,
    topClasses: classSummary.slice(0, 20),
  };
}

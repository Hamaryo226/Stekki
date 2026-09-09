import { Inflate, strFromU8, strToU8, zipSync } from 'fflate';

export const MAX_ARCHIVE = 25 * 1024 * 1024;
const caps: Record<string, number> = { 'manifest.json': 65536, 'integrity.json': 65536,
  'sticker.png': 15 * 1024 * 1024, 'thumbnail.png': 2 * 1024 * 1024 };
export type Manifest = { formatVersion: 1; stickerID: string; authorDisplayName: string; createdAt: string; exportedAt: string };
export type Trade = { manifest: Manifest; png: Uint8Array; thumbnail: Uint8Array; width: number; height: number };
export type Hash = (bytes: Uint8Array) => Promise<string>;
const reject = (reason: string): never => { throw Error(`シール交換ファイルを読み込めません：${reason}`); };
const table = new Uint32Array(256).map((_, n) => {
  let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0;
});
function crc32(bytes: Uint8Array): number {
  let c = 0xffffffff; for (const b of bytes) c = table[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0;
}

function boundedInflate(input: Uint8Array, declared: number): Uint8Array {
  const output = new Uint8Array(declared);
  let written = 0;
  const inflater = new Inflate(chunk => {
    if (written + chunk.length > declared) reject('展開サイズが宣言値を超えています');
    output.set(chunk, written); written += chunk.length;
  });
  // Small compressed chunks bound each transient allocation even for a dishonest ZIP header.
  for (let offset = 0; offset < input.length; offset += 256) {
    inflater.push(input.subarray(offset, offset + 256), offset + 256 >= input.length);
  }
  if (written !== declared) reject('展開サイズが一致しません');
  return output;
}

/** Inspect central AND local headers before bounded inflation. No ZIP64, paths, encryption or descriptors. */
export function extractArchive(data: Uint8Array): Record<string, Uint8Array> {
  if (data.length > MAX_ARCHIVE || data.length < 22) reject('容量が不正です');
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  const u16 = (p: number) => view.getUint16(p, true);
  const u32 = (p: number) => view.getUint32(p, true);
  let end = -1;
  for (let i = data.length - 22; i >= Math.max(0, data.length - 65557); i--) {
    if (u32(i) === 0x06054b50 && i + 22 + u16(i + 20) === data.length) { end = i; break; }
  }
  if (end < 0 || u16(end + 4) !== 0 || u16(end + 6) !== 0 || u16(end + 8) !== 4 || u16(end + 10) !== 4) reject('ZIPの構成が不正です');
  const start = u32(end + 16), length = u32(end + 12);
  if (start + length !== end) reject('ZIPディレクトリが不正です');
  let offset = start;
  const entries: { name: string; size: number; compressed: number; crc: number; method: number; begin: number; local: number; finish: number }[] = [];
  const names = new Set<string>();
  for (let i = 0; i < 4; i++) {
    if (offset + 46 > end || u32(offset) !== 0x02014b50) reject('ZIPヘッダーが不正です');
    const flags = u16(offset + 8), method = u16(offset + 10), crc = u32(offset + 16);
    const compressed = u32(offset + 20), size = u32(offset + 24);
    const n = u16(offset + 28), extra = u16(offset + 30), comment = u16(offset + 32), local = u32(offset + 42);
    if (offset + 46 + n + extra + comment > end || (flags & ~0x800) !== 0 || ![0, 8].includes(method) || u16(offset + 34) !== 0) reject('非対応のZIP形式です');
    const name = strFromU8(data.subarray(offset + 46, offset + 46 + n));
    if (!Object.hasOwn(caps, name) || names.has(name) || size > caps[name] || compressed > caps[name]) reject('ファイル名または容量が不正です');
    names.add(name);
    if (local + 30 > start || u32(local) !== 0x04034b50 || u16(local + 6) !== flags || u16(local + 8) !== method
      || u32(local + 14) !== crc || u32(local + 18) !== compressed || u32(local + 22) !== size) reject('ZIPヘッダーが一致しません');
    const localName = u16(local + 26), localExtra = u16(local + 28), begin = local + 30 + localName + localExtra;
    if (begin + compressed > start || strFromU8(data.subarray(local + 30, local + 30 + localName)) !== name) reject('ZIPの範囲が不正です');
    entries.push({ name, size, compressed, crc, method, begin, local, finish: begin + compressed });
    offset += 46 + n + extra + comment;
  }
  if (offset !== end) reject('余分なZIPエントリがあります');
  const ordered = [...entries].sort((a, b) => a.local - b.local);
  if (ordered[0].local !== 0 || ordered.some((e, i) => i > 0 && e.local !== ordered[i - 1].finish)
      || ordered.at(-1)!.finish !== start) reject('ZIPエントリが重複または欠落しています');
  const result: Record<string, Uint8Array> = {};
  for (const e of entries) {
    const compressed = data.subarray(e.begin, e.finish);
    const bytes = e.method === 0 ? compressed : boundedInflate(compressed, e.size);
    if (bytes.length !== e.size || crc32(bytes) !== e.crc) reject('データが破損しています');
    result[e.name] = bytes;
  }
  return result;
}

export function pngSize(bytes: Uint8Array, max: number): { width: number; height: number } {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 33 || !signature.every((v, i) => bytes[i] === v)) reject('PNG画像ではありません');
  const v = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  if (v.getUint32(8) !== 13 || strFromU8(bytes.subarray(12, 16)) !== 'IHDR') reject('PNGヘッダーが不正です');
  const width = v.getUint32(16), height = v.getUint32(20);
  if (!width || !height || width > max || height > max) reject('画像サイズが上限を超えています');
  return { width, height };
}

function validManifest(value: unknown): asserts value is Manifest {
  const m = value as Manifest;
  if (!m || m.formatVersion !== 1 || typeof m.stickerID !== 'string'
    || !/^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/i.test(m.stickerID)
    || typeof m.authorDisplayName !== 'string' || m.authorDisplayName.length > 1024
    || ![m.createdAt, m.exportedAt].every(v => typeof v === 'string' && Number.isFinite(Date.parse(v)))) reject('シール情報が不正または非対応です');
}

export async function readTrade(bytes: Uint8Array, hash: Hash): Promise<Trade> {
  const entries = extractArchive(bytes);
  const integrity = JSON.parse(strFromU8(entries['integrity.json']));
  const targets = ['manifest.json', 'sticker.png', 'thumbnail.png'];
  if (!integrity || integrity.algorithm !== 'SHA-256' || !integrity.files || Object.keys(integrity.files).sort().join() !== [...targets].sort().join()) reject('整合性情報が不正です');
  for (const name of targets) {
    const expected = integrity.files[name];
    if (typeof expected !== 'string' || !/^[a-f0-9]{64}$/i.test(expected) || (await hash(entries[name])).toLowerCase() !== expected.toLowerCase()) reject('SHA-256が一致しません');
  }
  const manifest: unknown = JSON.parse(strFromU8(entries['manifest.json']));
  validManifest(manifest);
  const size = pngSize(entries['sticker.png'], 4096);
  pngSize(entries['thumbnail.png'], 2048);
  return { manifest, png: entries['sticker.png'], thumbnail: entries['thumbnail.png'], ...size };
}

export async function writeTrade(manifest: Manifest, png: Uint8Array, thumbnail: Uint8Array, hash: Hash): Promise<Uint8Array> {
  validManifest(manifest); pngSize(png, 4096); pngSize(thumbnail, 2048);
  const files: Record<string, Uint8Array> = { 'manifest.json': strToU8(JSON.stringify(manifest)), 'sticker.png': png, 'thumbnail.png': thumbnail };
  const hashes: Record<string, string> = {};
  for (const [name, bytes] of Object.entries(files)) {
    if (bytes.length > caps[name]) throw Error('シールの容量が送信上限を超えています。');
    hashes[name] = await hash(bytes);
  }
  files['integrity.json'] = strToU8(JSON.stringify({ algorithm: 'SHA-256', files: hashes }));
  return zipSync(files, { level: 0 });
}

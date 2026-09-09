import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { zipSync, strToU8 } from 'fflate';
import { extractArchive, MAX_ARCHIVE, readTrade, writeTrade, type Manifest } from '../src/trade-format';

const hash = async (data: Uint8Array) => createHash('sha256').update(data).digest('hex');
const png = Uint8Array.from(Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jW5kAAAAASUVORK5CYII=', 'base64'));
const manifest: Manifest = { formatVersion: 1, stickerID: '12345678-1234-1234-1234-123456789abc', authorDisplayName: '作成者', createdAt: '2026-07-12T08:12:15Z', exportedAt: '2026-09-09T00:00:00Z' };
const archive = () => writeTrade(manifest, png, png, hash);

test('stored ZIP roundtrip matches the native v1 manifest and integrity schema', async () => {
  const result = await readTrade(await archive(), hash);
  assert.deepEqual(result.manifest, manifest); assert.deepEqual(result.png, png);
  assert.equal(result.width, 1); assert.equal(result.height, 1);
});
test('deflated archives are also accepted', async () => {
  const entries = extractArchive(await archive());
  const result = await readTrade(zipSync(entries, { level: 6 }), hash);
  assert.deepEqual(result.manifest, manifest);
});
test('tampering fails even when ZIP CRC is valid', async () => {
  const entries = extractArchive(await archive());
  entries['manifest.json'] = strToU8(JSON.stringify({ ...manifest, authorDisplayName: 'changed' }));
  await assert.rejects(readTrade(zipSync(entries, { level: 0 }), hash), /SHA-256/);
});
test('missing/extra/traversal entries are rejected before extraction', async () => {
  const entries = extractArchive(await archive());
  await assert.rejects(readTrade(zipSync({ ...entries, 'extra.txt': new Uint8Array() }), hash));
  delete entries['thumbnail.png']; entries['../thumbnail.png'] = png;
  await assert.rejects(readTrade(zipSync(entries), hash), /ファイル名/);
});
test('negative and future format versions are rejected with correct hashes', async () => {
  for (const formatVersion of [-1, 0, 2]) {
    const entries = extractArchive(await archive());
    entries['manifest.json'] = strToU8(JSON.stringify({ ...manifest, formatVersion }));
    const files = Object.fromEntries(await Promise.all(['manifest.json', 'sticker.png', 'thumbnail.png'].map(async name => [name, await hash(entries[name])])));
    entries['integrity.json'] = strToU8(JSON.stringify({ algorithm: 'SHA-256', files }));
    await assert.rejects(readTrade(zipSync(entries), hash), /非対応/);
  }
});
test('archive limit, corrupt headers and truncated archives are rejected', async () => {
  assert.throws(() => extractArchive(new Uint8Array(MAX_ARCHIVE + 1)), /容量/);
  const bytes = await archive();
  assert.throws(() => extractArchive(bytes.subarray(0, bytes.length - 3)));
  const broken = bytes.slice(); broken[0] = 0;
  assert.throws(() => extractArchive(broken), /一致/);
});
test('a false tiny declared size cannot bypass bounded decompression', async () => {
  const entries = extractArchive(await archive());
  entries['sticker.png'] = new Uint8Array(200000).fill(42);
  const bytes = zipSync(entries, { level: 6 });
  const v = new DataView(bytes.buffer);
  // Change both headers so the local/central consistency check passes.
  for (let i = 0; i + 46 < bytes.length; i++) {
    if (v.getUint32(i, true) === 0x02014b50 && v.getUint32(i + 24, true) === 200000) {
      v.setUint32(i + 24, 1, true);
      const local = v.getUint32(i + 42, true); v.setUint32(local + 22, 1, true); break;
    }
  }
  assert.throws(() => extractArchive(bytes), /展開サイズ/);
});
test('oversized PNG dimensions are rejected before native decoding', async () => {
  const huge = png.slice(); new DataView(huge.buffer).setUint32(16, 100000);
  await assert.rejects(writeTrade(manifest, huge, png, hash), /画像サイズ/);
});

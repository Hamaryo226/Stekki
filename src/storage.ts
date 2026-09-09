import * as SQLite from 'expo-sqlite';
import { Directory, File, Paths } from 'expo-file-system';
import * as Crypto from 'expo-crypto';
import { manipulateAsync, SaveFormat } from 'expo-image-manipulator';
import * as DocumentPicker from 'expo-document-picker';
import * as Sharing from 'expo-sharing';
import { emptyState, parseState, type Sticker } from './model';
import { SerialStore } from './serial-store';
import { MAX_ARCHIVE, readTrade, writeTrade, type Trade } from './trade-format';

const folder = new Directory(Paths.document, 'stekki-images');
export const imageURI = (name: string) => new File(folder, name).uri;
const hash = async (bytes: Uint8Array) => {
  const digest = await Crypto.digest(Crypto.CryptoDigestAlgorithm.SHA256, Uint8Array.from(bytes));
  return Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, '0')).join('');
};
let instance: Promise<SerialStore> | undefined;
export function openStore(): Promise<SerialStore> {
  if (!instance) instance = (async () => {
    folder.create({ idempotent: true, intermediates: true });
    const db = await SQLite.openDatabaseAsync('stekki-expo-go.db');
    await db.execAsync('PRAGMA journal_mode = WAL; CREATE TABLE IF NOT EXISTS library (id INTEGER PRIMARY KEY CHECK(id = 1), value TEXT NOT NULL);');
    const row = await db.getFirstAsync<{ value: string }>('SELECT value FROM library WHERE id = 1');
    return new SerialStore(row ? parseState(row.value) : emptyState(), async state => {
      await db.runAsync('INSERT INTO library(id, value) VALUES (1, ?) ON CONFLICT(id) DO UPDATE SET value = excluded.value', JSON.stringify(state));
    }, { id: Crypto.randomUUID, now: () => new Date().toISOString() });
  })().catch(error => { instance = undefined; throw error; });
  return instance;
}

export async function addImage(store: SerialStore, uri: string, metadata: { author: string }): Promise<void> {
  const id = Crypto.randomUUID();
  const file = new File(folder, `${id}.png`), thumbnail = new File(folder, `${id}-thumb.png`);
  const temporary = new Set<string>();
  try {
    // Decode before permanent storage; images are bounded to 1024px in our library.
    const source = await manipulateAsync(uri, [], { format: SaveFormat.PNG });
    temporary.add(source.uri);
    const resized = await manipulateAsync(source.uri, [{ resize: source.width > source.height ? { width: Math.min(source.width, 1024) } : { height: Math.min(source.height, 1024) } }], { format: SaveFormat.PNG });
    temporary.add(resized.uri);
    const small = await manipulateAsync(resized.uri, [{ resize: resized.width > resized.height ? { width: 200 } : { height: 200 } }], { format: SaveFormat.PNG });
    temporary.add(small.uri);
    new File(resized.uri).copy(file); new File(small.uri).copy(thumbnail);
    const sticker: Sticker = { id, file: file.name, thumbnail: thumbnail.name,
      width: resized.width, height: resized.height, author: metadata.author.trim().slice(0, 120) || '自分',
      createdAt: new Date().toISOString(), history: [] };
    await store.dispatch({ type: 'addSticker', sticker });
  } catch (error) { safelyDelete(file.uri); safelyDelete(thumbnail.uri); throw error; }
  finally { temporary.forEach(safelyDelete); }
}

export function safelyDelete(uri: string) { try { const f = new File(uri); if (f.exists) f.delete(); } catch { /* OS can reclaim cache later. */ } }
export async function deleteSticker(store: SerialStore, sticker: Sticker) {
  await store.dispatch({ type: 'deleteSticker', id: sticker.id });
  safelyDelete(imageURI(sticker.file)); safelyDelete(imageURI(sticker.thumbnail));
}

export type Incoming = Trade & { preview: string; dispose(): void };
export async function addReceived(store: SerialStore, incoming: Incoming, sender: string): Promise<void> {
  const id = Crypto.randomUUID();
  const file = new File(folder, `${id}.png`), thumbnail = new File(folder, `${id}-thumb.png`);
  try {
    // Preserve received pixels exactly; assign a new identity, never trust the sender's ID.
    file.write(incoming.png); thumbnail.write(incoming.thumbnail);
    await store.dispatch({ type: 'addSticker', sticker: {
      id, file: file.name, thumbnail: thumbnail.name, width: incoming.width, height: incoming.height,
      author: incoming.manifest.authorDisplayName, createdAt: incoming.manifest.createdAt,
      receivedAt: new Date().toISOString(), receivedFrom: sender.trim().slice(0, 120), history: [],
    } });
  } catch (error) { safelyDelete(file.uri); safelyDelete(thumbnail.uri); throw error; }
}

export async function pickTrade(): Promise<Incoming | undefined> {
  // Expo Go cannot register our custom UTI: use Files, including unknown extensions.
  const picked = await DocumentPicker.getDocumentAsync({ type: '*/*', copyToCacheDirectory: true, multiple: false });
  if (picked.canceled) return;
  const asset = picked.assets[0];
  const file = new File(asset.uri);
  let preview: File | undefined;
  try {
    if (!asset.name.toLowerCase().endsWith('.stickertrade')) throw Error('.stickertradeファイルを選んでください。');
    if (file.size > MAX_ARCHIVE) throw Error('ファイルが25MBを超えています。');
    const handle = file.open();
    let bytes: Uint8Array;
    try { bytes = handle.readBytes(Math.min(file.size, MAX_ARCHIVE + 1)); } finally { handle.close(); }
    const trade = await readTrade(bytes, hash);
    preview = new File(Paths.cache, `${Crypto.randomUUID()}-receive.png`);
    preview.write(trade.png);
    // Header limits are checked before invoking the native image decoder.
    const decoded = await manipulateAsync(preview.uri, [], { format: SaveFormat.PNG });
    safelyDelete(decoded.uri);
    const thumb = new File(Paths.cache, `${Crypto.randomUUID()}-receive-thumb.png`);
    try {
      thumb.write(trade.thumbnail);
      const decodedThumb = await manipulateAsync(thumb.uri, [], { format: SaveFormat.PNG });
      safelyDelete(decodedThumb.uri);
    } finally { safelyDelete(thumb.uri); }
    const uri = preview.uri;
    return { ...trade, preview: uri, dispose: () => safelyDelete(uri) };
  } catch (error) { if (preview) safelyDelete(preview.uri); throw error; }
  finally { safelyDelete(asset.uri); }
}

export async function shareSticker(sticker: Sticker) {
  if (!(await Sharing.isAvailableAsync())) throw Error('この端末では共有を利用できません。');
  const bytes = await writeTrade({ formatVersion: 1, stickerID: sticker.id, authorDisplayName: sticker.author,
    createdAt: sticker.createdAt, exportedAt: new Date().toISOString() },
    await new File(imageURI(sticker.file)).bytes(), await new File(imageURI(sticker.thumbnail)).bytes(), hash);
  const file = new File(Paths.cache, `Stekki-${Crypto.randomUUID()}.stickertrade`);
  try {
    file.write(bytes);
    await Sharing.shareAsync(file.uri, { UTI: 'public.data', mimeType: 'application/vnd.stekki.stickertrade+zip', dialogTitle: 'シールを送る' });
  } finally { safelyDelete(file.uri); }
}

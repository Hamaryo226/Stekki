import { test } from 'node:test';
import assert from 'node:assert/strict';
import { emptyState, parseState, reduce, type Clock, type Sticker, type State } from '../src/model';
import { SerialStore } from '../src/serial-store';
import { movePose } from '../src/gesture';

const clock = (): Clock => { let id = 0; return { id: () => `id-${++id}`, now: () => '2026-09-09T00:00:00Z' }; };
function fixture() {
  const c = clock();
  let s = reduce(emptyState(), { type: 'createBook', title: 'テスト' }, c);
  const sticker: Sticker = { id: 'sticker-1', file: 'sticker-1.png', thumbnail: 'sticker-1-thumb.png', width: 100, height: 100, author: '自分', createdAt: c.now(), history: [] };
  s = reduce(s, { type: 'addSticker', sticker }, c);
  s = reduce(s, { type: 'place', id: sticker.id, pageId: s.books[0].pages[0].id, x: 0.5, y: 0.5 }, c);
  return { c, s };
}
test('book deletion returns stickers to tray and keeps a location snapshot', () => {
  const { c, s } = fixture();
  const next = reduce(s, { type: 'deleteBook', id: s.books[0].id }, c);
  assert.equal(next.books.length, 0); assert.equal(next.stickers.length, 1);
  assert.equal(next.stickers[0].placement, undefined);
  assert.equal(next.stickers[0].history[0].book, 'テスト');
  assert.equal(next.stickers[0].history[0].action, 'removed');
  assert.ok(s.stickers[0].placement, 'original snapshot is immutable');
  assert.deepEqual(parseState(JSON.stringify(next)), JSON.parse(JSON.stringify(next)));
});
test('the last page cannot be deleted; other pages return their stickers', () => {
  const { c, s } = fixture();
  const action = { type: 'deletePage' as const, bookId: s.books[0].id, pageId: s.books[0].pages[0].id };
  assert.throws(() => reduce(s, action, c), /最後/);
  const next = reduce(reduce(s, { type: 'addPage', bookId: s.books[0].id }, c), action, c);
  assert.equal(next.books[0].pages.length, 1); assert.equal(next.stickers[0].placement, undefined);
});
test('transforms clamp scale/position and record one history entry', () => {
  const { c, s } = fixture();
  const next = reduce(s, { type: 'transform', id: 'sticker-1', patch: { x: 8, y: -3, scale: 8, rotation: Math.PI / 2 + 0.01, flipped: true } }, c);
  const p = next.stickers[0].placement!;
  assert.equal(p.x, 1); assert.equal(p.y, 0); assert.equal(p.scale, 4); assert.equal(p.rotation, Math.PI / 2);
  assert.equal(p.flipped, true); assert.equal(next.stickers[0].history.length, 2);
  assert.throws(() => reduce(s, { type: 'transform', id: 'sticker-1', patch: { x: NaN } }, c));
});
test('a sticker has exactly one placement when moved between pages', () => {
  const { c, s } = fixture();
  const added = reduce(s, { type: 'addPage', bookId: s.books[0].id }, c);
  const pageId = added.books[0].pages[1].id;
  const next = reduce(added, { type: 'place', id: 'sticker-1', pageId, x: 0.2, y: 0.3 }, c);
  assert.equal(next.stickers.length, 1); assert.equal(next.stickers[0].placement!.pageId, pageId);
});
test('future, corrupt and broken-reference stores are rejected', () => {
  const { s } = fixture();
  assert.throws(() => parseState('{'));
  assert.throws(() => parseState(JSON.stringify({ ...s, version: 2 })));
  assert.throws(() => parseState(JSON.stringify({ ...s, books: [] })));
  assert.throws(() => parseState(JSON.stringify({ ...s, stickers: [{ ...s.stickers[0], file: '../../file.png' }] })));
  assert.deepEqual(parseState(JSON.stringify(s)), s);
});
test('failed persistence does not publish or lose the next operation', async () => {
  const c = clock(); let attempts = 0, notifications = 0;
  const store = new SerialStore(emptyState(), async () => { if (++attempts === 1) throw Error('disk full'); }, c);
  store.subscribe(() => notifications++);
  await assert.rejects(store.dispatch({ type: 'createBook', title: '失敗' }), /disk full/);
  assert.equal(store.snapshot().books.length, 0); assert.equal(notifications, 0);
  await store.dispatch({ type: 'createBook', title: '成功' });
  assert.equal(store.snapshot().books[0].title, '成功'); assert.equal(notifications, 1);
});
test('concurrent operations serialize against the latest committed snapshot', async () => {
  let release!: () => void;
  const gate = new Promise<void>(resolve => { release = resolve; });
  const persisted: State[] = [];
  const store = new SerialStore(emptyState(), async s => { await gate; persisted.push(s); }, clock());
  const first = store.dispatch({ type: 'createBook', title: '一冊目' });
  const second = store.dispatch({ type: 'createBook', title: '二冊目' });
  await Promise.resolve(); assert.equal(store.snapshot().books.length, 0);
  release(); await Promise.all([first, second]);
  assert.equal(persisted.length, 2); assert.equal(store.snapshot().books.length, 2);
});
test('two-finger scaling preserves the grasped anchor with translation', () => {
  const result = movePose({ x: 20, y: 10, scale: 1, rotation: 0 }, [{ x: 0, y: 0 }, { x: 20, y: 0 }], [{ x: 0, y: 5 }, { x: 40, y: 5 }]);
  assert.deepEqual(result, { x: 40, y: 25, scale: 2, rotation: 0 });
});
test('two-finger rotation moves the sticker center around the fingers', () => {
  const result = movePose({ x: 20, y: 0, scale: 1, rotation: 0 }, [{ x: -10, y: 0 }, { x: 10, y: 0 }], [{ x: 0, y: -10 }, { x: 0, y: 10 }]);
  assert.ok(Math.abs(result.x) < 1e-10); assert.equal(result.y, 20); assert.equal(result.rotation, Math.PI / 2);
});

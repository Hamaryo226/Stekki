export type Placement = {
  pageId: string; x: number; y: number; scale: number; rotation: number;
  z: number; flipped: boolean; shadow: boolean;
};
export type History = Placement & { id: string; date: string; action: 'placed' | 'moved' | 'removed'; book: string; page: number };
export type Sticker = {
  id: string; file: string; thumbnail: string; width: number; height: number;
  author: string; createdAt: string; receivedAt?: string; receivedFrom?: string;
  placement?: Placement; history: History[];
};
export type Page = { id: string; color: string };
export type Book = { id: string; title: string; color: string; pages: Page[]; createdAt: string };
export type State = { version: 1; books: Book[]; stickers: Sticker[] };
export const emptyState = (): State => ({ version: 1, books: [], stickers: [] });
export const palette = ['#F3BCD1', '#C9C5F1', '#B8DCD3', '#F3DCA7', '#BBD7EF'];
export const clamp = (v: number, min: number, max: number) => Math.min(max, Math.max(min, v));
export const snapRotation = (angle: number) => {
  const snapped = Math.round(angle / (Math.PI / 2)) * (Math.PI / 2);
  return Math.abs(snapped - angle) < Math.PI / 45 ? snapped : angle;
};

export type Action =
  | { type: 'createBook'; title: string }
  | { type: 'renameBook'; id: string; title: string }
  | { type: 'deleteBook'; id: string }
  | { type: 'addPage'; bookId: string }
  | { type: 'deletePage'; bookId: string; pageId: string }
  | { type: 'addSticker'; sticker: Sticker }
  | { type: 'deleteSticker'; id: string }
  | { type: 'metadata'; id: string; author: string; receivedFrom?: string }
  | { type: 'place'; id: string; pageId: string; x: number; y: number }
  | { type: 'transform'; id: string; patch: Partial<Omit<Placement, 'pageId'>> }
  | { type: 'remove'; id: string };
export type Clock = { id(): string; now(): string };

function location(state: State, pageId: string) {
  const book = state.books.find(b => b.pages.some(p => p.id === pageId));
  if (!book) throw Error('ページが見つかりません。');
  return { book: book.title, page: book.pages.findIndex(p => p.id === pageId) + 1 };
}
function history(state: State, placement: Placement, action: History['action'], clock: Clock): History {
  return { ...placement, ...location(state, placement.pageId), action, id: clock.id(), date: clock.now() };
}
function remove(state: State, sticker: Sticker, clock: Clock): Sticker {
  if (!sticker.placement) return sticker;
  return { ...sticker, placement: undefined, history: [history(state, sticker.placement, 'removed', clock), ...sticker.history] };
}
function normalize(p: Placement): Placement {
  for (const n of [p.x, p.y, p.scale, p.rotation, p.z]) if (!Number.isFinite(n)) throw Error('位置が不正です。');
  return { ...p, x: clamp(p.x, 0, 1), y: clamp(p.y, 0, 1), scale: clamp(p.scale, 0.25, 4), rotation: snapRotation(p.rotation) };
}

/** Pure state transition. Caller persists the returned snapshot before publishing it. */
export function reduce(state: State, action: Action, clock: Clock): State {
  switch (action.type) {
    case 'createBook': return { ...state, books: [{ id: clock.id(), title: action.title.trim().slice(0, 120) || '新しいシール帳',
      color: palette[state.books.length % palette.length], createdAt: clock.now(), pages: [{ id: clock.id(), color: '#FFFDF7' }] }, ...state.books] };
    case 'renameBook': {
      if (!action.title.trim()) throw Error('名前を入力してください。');
      if (!state.books.some(b => b.id === action.id)) throw Error('シール帳が見つかりません。');
      return { ...state, books: state.books.map(b => b.id === action.id ? { ...b, title: action.title.trim().slice(0, 120) } : b) };
    }
    case 'deleteBook': {
      const book = state.books.find(b => b.id === action.id);
      if (!book) throw Error('シール帳が見つかりません。');
      const pages = new Set(book.pages.map(p => p.id));
      return { ...state, books: state.books.filter(b => b.id !== action.id),
        stickers: state.stickers.map(s => s.placement && pages.has(s.placement.pageId) ? remove(state, s, clock) : s) };
    }
    case 'addPage': {
      if (!state.books.some(b => b.id === action.bookId)) throw Error('シール帳が見つかりません。');
      return { ...state, books: state.books.map(b => b.id === action.bookId ? { ...b, pages: [...b.pages, { id: clock.id(), color: '#FFFDF7' }] } : b) };
    }
    case 'deletePage': {
      const book = state.books.find(b => b.id === action.bookId);
      if (!book || !book.pages.some(p => p.id === action.pageId)) throw Error('ページが見つかりません。');
      if (book.pages.length === 1) throw Error('最後のページは削除できません。');
      return { ...state, books: state.books.map(b => b === book ? { ...b, pages: b.pages.filter(p => p.id !== action.pageId) } : b),
        stickers: state.stickers.map(s => s.placement?.pageId === action.pageId ? remove(state, s, clock) : s) };
    }
    case 'addSticker': {
      if (state.stickers.some(s => s.id === action.sticker.id)) throw Error('同じIDのシールが存在します。');
      return { ...state, stickers: [action.sticker, ...state.stickers] };
    }
    default: {
      const sticker = state.stickers.find(s => s.id === action.id);
      if (!sticker) throw Error('シールが見つかりません。');
      if (action.type === 'deleteSticker') return { ...state, stickers: state.stickers.filter(s => s.id !== action.id) };
      let next = sticker;
      if (action.type === 'metadata') next = { ...sticker, author: action.author.trim().slice(0, 120) || '自分',
        receivedFrom: sticker.receivedAt ? action.receivedFrom?.trim().slice(0, 120) : undefined };
      if (action.type === 'remove') next = remove(state, sticker, clock);
      if (action.type === 'place') {
        location(state, action.pageId);
        const z = Math.max(-1, ...state.stickers.map(s => s.placement?.pageId === action.pageId ? s.placement.z : -1)) + 1;
        const placement = normalize({ pageId: action.pageId, x: action.x, y: action.y, scale: 1, rotation: 0, z, flipped: false, shadow: false });
        next = { ...sticker, placement, history: [history(state, placement, 'placed', clock), ...sticker.history] };
      }
      if (action.type === 'transform') {
        if (!sticker.placement) throw Error('シールはトレイにあります。');
        const placement = normalize({ ...sticker.placement, ...action.patch });
        next = { ...sticker, placement, history: [history(state, placement, 'moved', clock), ...sticker.history] };
      }
      return { ...state, stickers: state.stickers.map(s => s.id === next.id ? next : s) };
    }
  }
}

/** Reject malformed/future data, without replacing it with an empty database. */
export function parseState(text: string): State {
  const s = JSON.parse(text) as State;
  const fail = () => { throw Error('保存データを読み込めません。データは変更していません。'); };
  if (!s || s.version !== 1 || !Array.isArray(s.books) || !Array.isArray(s.stickers)) fail();
  const ids = new Set<string>();
  const id = (v: unknown) => { if (typeof v !== 'string' || !v || ids.has(v)) fail(); ids.add(v as string); };
  const date = (v: unknown) => { if (typeof v !== 'string' || !Number.isFinite(Date.parse(v))) fail(); };
  const color = (v: unknown) => { if (typeof v !== 'string' || !/^#[0-9a-f]{6}$/i.test(v)) fail(); };
  const pages = new Set<string>();
  for (const b of s.books) {
    if (!b || typeof b.title !== 'string' || !Array.isArray(b.pages) || !b.pages.length) fail();
    id(b.id); date(b.createdAt); color(b.color);
    for (const p of b.pages) { if (!p) fail(); id(p.id); pages.add(p.id); color(p.color); }
  }
  const checkPlacement = (p: Placement) => {
    if (!p || typeof p.pageId !== 'string' || ![p.x, p.y, p.scale, p.rotation, p.z].every(Number.isFinite)
      || p.x < 0 || p.x > 1 || p.y < 0 || p.y > 1 || p.scale < 0.25 || p.scale > 4
      || typeof p.flipped !== 'boolean' || typeof p.shadow !== 'boolean') fail();
  };
  for (const sticker of s.stickers) {
    if (!sticker || typeof sticker.author !== 'string' || !Array.isArray(sticker.history)) fail();
    id(sticker.id); date(sticker.createdAt);
    for (const name of [sticker.file, sticker.thumbnail]) if (typeof name !== 'string' || !/^[a-z0-9-]+\.png$/i.test(name)) fail();
    if (![sticker.width, sticker.height].every(v => Number.isFinite(v) && v > 0 && v <= 4096)) fail();
    if (sticker.receivedAt !== undefined) date(sticker.receivedAt);
    if (sticker.receivedFrom !== undefined && typeof sticker.receivedFrom !== 'string') fail();
    if (sticker.placement) { checkPlacement(sticker.placement); if (!pages.has(sticker.placement.pageId)) fail(); }
    for (const h of sticker.history) {
      checkPlacement(h); id(h.id); date(h.date);
      if (!['placed', 'moved', 'removed'].includes(h.action) || typeof h.book !== 'string' || !Number.isInteger(h.page) || h.page < 1) fail();
    }
  }
  return s;
}

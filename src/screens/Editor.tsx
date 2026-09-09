import { useRef, useState } from 'react';
import { Alert, Image, Pressable, ScrollView, Text, View, useWindowDimensions } from 'react-native';
import Slider from '@react-native-community/slider';
import type { SerialStore } from '../serial-store';
import { Button, Header, Label, ui, useLibrary, useTask, useTheme } from '../ui';
import { CanvasSticker, type CanvasFrame } from '../components/CanvasSticker';
import { imageURI } from '../storage';
import type { Placement } from '../model';

export function Editor({ store, bookId, pageId, setPage, back, detail, create }: { store: SerialStore; bookId: string; pageId?: string;
  setPage(id: string): void; back(): void; detail(id: string): void; create(kind: 'photo' | 'text'): void }) {
  const state = useLibrary(store), c = useTheme(), { busy, run } = useTask(), window = useWindowDimensions();
  const book = state.books.find(b => b.id === bookId)!;
  const page = book.pages.find(p => p.id === pageId) ?? book.pages[0];
  const [editing, setEditing] = useState(false), [selectedId, select] = useState<string>(), [dragging, setDragging] = useState(false);
  const selected = state.stickers.find(s => s.id === selectedId && s.placement?.pageId === page.id);
  const canvas = useRef<View>(null);
  const [frame, setFrame] = useState<CanvasFrame>({ x: 0, y: 0, width: 1, height: 1 });
  const width = Math.min(window.width - 40, 540), height = Math.max(140, Math.min(width * 1.3, window.height - (editing ? 400 : 230)));
  const measure = () => canvas.current?.measureInWindow((x, y, w, h) => setFrame({ x, y, width: w, height: h }));
  const transform = (patch: Partial<Placement>) => { if (selected) void run(() => store.dispatch({ type: 'transform', id: selected.id, patch })); };
  const placed = state.stickers.filter(s => s.placement?.pageId === page.id).sort((a, b) => a.placement!.z - b.placement!.z);
  return <View style={ui.fill}>
    <Header title={book.title} back={back} right={<Button title={editing ? '完了' : '編集'} onPress={() => { setEditing(!editing); select(undefined); }} />} />
    <View style={[ui.row, { paddingHorizontal: 20, paddingBottom: 10 }]}>
      <Button title="前へ" small disabled={book.pages.indexOf(page) === 0} onPress={() => { select(undefined); setPage(book.pages[book.pages.indexOf(page) - 1].id); }} />
      <Label>{book.pages.indexOf(page) + 1} / {book.pages.length}ページ</Label>
      <Button title="次へ" small disabled={book.pages.indexOf(page) === book.pages.length - 1} onPress={() => { select(undefined); setPage(book.pages[book.pages.indexOf(page) + 1].id); }} />
      {editing && <Button title="＋" small disabled={busy} onPress={() => { void run(async () => { await store.dispatch({ type: 'addPage', bookId }); setPage(store.snapshot().books.find(b => b.id === bookId)!.pages.at(-1)!.id); }); }} />}
      {editing && <Button title="削除" small danger disabled={busy || book.pages.length === 1} onPress={() => Alert.alert('ページを削除', 'このページのシールはトレイに戻ります。', [
        { text: 'キャンセル', style: 'cancel' }, { text: '削除', style: 'destructive', onPress: () => { void run(() => store.dispatch({ type: 'deletePage', bookId, pageId: page.id })); } },
      ])} />}
    </View>
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', zIndex: dragging ? 10 : 0 }}>
      <View key={page.id} ref={canvas} onLayout={measure} collapsable={false}
        style={{ width, height, backgroundColor: page.color, borderRadius: 18, overflow: dragging ? 'visible' : 'hidden' }}>
        {!placed.length && <View pointerEvents="none" style={ui.center}><Text style={{ color: '#AAAAAA', textAlign: 'center' }}>{editing ? 'トレイのシールをタップして貼り付け' : '「編集」からシールを貼り付けましょう'}</Text></View>}
        {placed.map(s => <CanvasSticker key={s.id} sticker={s} frame={frame} editing={editing} disabled={busy} selected={selectedId === s.id}
          onSelect={() => select(s.id)} onDetail={() => detail(s.id)} onDragging={setDragging}
          onCommit={patch => run(() => store.dispatch({ type: 'transform', id: s.id, patch }))}
          onReturn={() => run(() => store.dispatch({ type: 'remove', id: s.id })).then(ok => { if (ok) select(undefined); return ok; })} />)}
      </View>
    </View>
    {editing && <View style={{ padding: 14, gap: 8 }} onLayout={measure}>
      <View style={{ minHeight: 106 }}>{selected ? <>
        <View style={ui.row}><Button title="反転" small disabled={busy} onPress={() => transform({ flipped: !selected.placement!.flipped })} />
          <Button title={selected.placement!.shadow ? '影なし' : '影あり'} small disabled={busy} onPress={() => transform({ shadow: !selected.placement!.shadow })} />
          <Button title="手前へ" small disabled={busy} onPress={() => transform({ z: Math.max(...placed.map(s => s.placement!.z)) + 1 })} />
          <Button title="取り出す" small disabled={busy} onPress={() => { void run(() => store.dispatch({ type: 'remove', id: selected.id })); }} /></View>
        <View style={ui.row}><Label>大きさ</Label><Slider style={{ flex: 1, minWidth: 100 }} minimumValue={0.25} maximumValue={4} value={selected.placement!.scale} disabled={busy}
          onSlidingComplete={scale => transform({ scale })} accessibilityLabel="シールの大きさ" />
          <Button title="90°回転" small disabled={busy} onPress={() => transform({ rotation: selected.placement!.rotation + Math.PI / 2 })} /></View>
      </> : <Label>ドラッグで移動、2本指で拡縮・回転。下へ運ぶとトレイに戻ります。</Label>}</View>
      <ScrollView horizontal style={{ height: 70 }} contentContainerStyle={{ gap: 12 }}>
        {state.stickers.filter(s => !s.placement).map(s => <Pressable key={s.id} accessibilityRole="button" accessibilityLabel={`${s.author}のシールを貼る`} disabled={busy}
          onLongPress={() => detail(s.id)} onPress={() => { void run(() => store.dispatch({ type: 'place', id: s.id, pageId: page.id, x: 0.5, y: 0.5 })).then(ok => { if (ok) select(s.id); }); }}>
          <Image source={{ uri: imageURI(s.thumbnail) }} style={{ width: 62, height: 62 }} resizeMode="contain" />
        </Pressable>)}
      </ScrollView>
      <View style={ui.row}><Button title="写真から" onPress={() => create('photo')} /><Button title="文字から" onPress={() => create('text')} /></View>
    </View>}
  </View>;
}

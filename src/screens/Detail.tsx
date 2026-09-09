import { SafeAreaView } from 'react-native-safe-area-context';
import { useState } from 'react';
import { Alert, Image, ScrollView, Text, TextInput, View } from 'react-native';
import type { SerialStore } from '../serial-store';
import { deleteSticker, imageURI, shareSticker } from '../storage';
import { Button, Header, Label, ui, useLibrary, useTask, useTheme } from '../ui';

export function Detail({ store, id, back }: { store: SerialStore; id: string; back(): void }) {
  const state = useLibrary(store), sticker = state.stickers.find(s => s.id === id);
  const c = useTheme(), { busy, run } = useTask();
  const [author, setAuthor] = useState(sticker?.author ?? ''), [sender, setSender] = useState(sticker?.receivedFrom ?? '');
  if (!sticker) return <Header nativeBack title="シールは削除されました" back={back} />;
  const book = state.books.find(b => b.pages.some(p => p.id === sticker.placement?.pageId));
  return <SafeAreaView edges={['bottom']} style={ui.fill}><Header nativeBack title="シールの詳細" back={busy ? undefined : back} />
    <ScrollView automaticallyAdjustKeyboardInsets keyboardDismissMode="interactive" contentContainerStyle={ui.body}>
      <ScrollView style={{ height: 260, borderRadius: 18, backgroundColor: '#D6D8DF' }} minimumZoomScale={1} maximumZoomScale={4} centerContent>
        <Image source={{ uri: imageURI(sticker.file) }} style={{ width: 300, height: 260, alignSelf: 'center' }} resizeMode="contain" />
      </ScrollView>
      <Label>作成：{new Date(sticker.createdAt).toLocaleString()}</Label>
      <Label>作成者</Label><TextInput value={author} onChangeText={setAuthor} maxLength={120} accessibilityLabel="作成者" style={[ui.input, { backgroundColor: c.card, color: c.text }]} />
      {sticker.receivedAt && <><Label>受取：{new Date(sticker.receivedAt).toLocaleString()}</Label><TextInput value={sender} onChangeText={setSender} maxLength={120} accessibilityLabel="受取元" style={[ui.input, { backgroundColor: c.card, color: c.text }]} /></>}
      <Button title="情報を保存" disabled={busy} onPress={() => { void run(() => store.dispatch({ type: 'metadata', id, author, receivedFrom: sender })); }} />
      <Button title="このシールを送る" disabled={busy} onPress={() => { void run(() => shareSticker(sticker)); }} />
      <Label>{book ? `現在のシール帳：${book.title} / ${book.pages.findIndex(p => p.id === sticker.placement?.pageId) + 1}ページ` : '現在：未貼付トレイ'}</Label>
      {sticker.placement && <><Label>位置 {sticker.placement.x.toFixed(2)}, {sticker.placement.y.toFixed(2)} · {sticker.placement.scale.toFixed(2)}倍 · {Math.round(sticker.placement.rotation * 180 / Math.PI)}°</Label>
        <Button title="トレイに戻す" disabled={busy} onPress={() => { void run(() => store.dispatch({ type: 'remove', id })); }} /></>}
      <Text style={[ui.title, { color: c.text }]}>貼付履歴</Text>
      {!sticker.history.length && <Label>まだ貼り付けられていません。</Label>}
      {sticker.history.map(h => <View key={h.id} style={[ui.card, { backgroundColor: c.card }]}>
        <Text style={{ color: c.text }}>{h.action === 'placed' ? '貼り付け' : h.action === 'removed' ? 'トレイに戻した' : '位置・見た目を変更'}</Text>
        <Label>{h.book} · {h.page}ページ / {new Date(h.date).toLocaleString()}</Label>
      </View>)}
      <Button title="シールを完全に削除" disabled={busy} danger onPress={() => Alert.alert('シールを削除', '画像と履歴も削除されます。', [
        { text: 'キャンセル', style: 'cancel' }, { text: '削除', style: 'destructive', onPress: () => { void run(() => deleteSticker(store, sticker)).then(ok => { if (ok) back(); }); } },
      ])} />
    </ScrollView>
  </SafeAreaView>;
}

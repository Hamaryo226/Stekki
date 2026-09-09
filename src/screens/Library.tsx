import { useState } from 'react';
import { Alert, FlatList, Image, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import type { SerialStore } from '../serial-store';
import { imageURI } from '../storage';
import { Button, Header, Label, ui, useLibrary, useTask, useTheme } from '../ui';
import type { Book } from '../model';

export function Library({ store, openBook, create, detail, receive }: { store: SerialStore;
  openBook(id: string): void; create(kind: 'photo' | 'text'): void; detail(id: string): void; receive(): void }) {
  const state = useLibrary(store), c = useTheme(), { busy, run } = useTask();
  const [form, setForm] = useState<{ id?: string; title: string }>();
  const options = (book: Book) => Alert.alert(book.title, 'シール帳の操作', [
    { text: '名前を変更', onPress: () => setForm({ id: book.id, title: book.title }) },
    { text: '削除', style: 'destructive', onPress: () => Alert.alert('シール帳を削除', 'ページは削除され、シールはトレイに戻ります。', [
      { text: 'キャンセル', style: 'cancel' }, { text: '削除', style: 'destructive', onPress: () => { void run(() => store.dispatch({ type: 'deleteBook', id: book.id })); } },
    ]) }, { text: 'キャンセル', style: 'cancel' },
  ]);
  if (form) return <View style={ui.fill}><Header title={form.id ? '名前を変更' : '新しいシール帳'} back={() => setForm(undefined)} />
    <View style={ui.body}><TextInput autoFocus accessibilityLabel="シール帳の名前" placeholder="お気に入りコレクション" placeholderTextColor={c.muted}
      maxLength={120} value={form.title} onChangeText={title => setForm({ ...form, title })} style={[ui.input, { color: c.text, backgroundColor: c.card }]} />
      <Button title="保存" disabled={busy} onPress={() => { void run(() => store.dispatch(form.id ? { type: 'renameBook', id: form.id, title: form.title } : { type: 'createBook', title: form.title })).then(ok => { if (ok) setForm(undefined); }); }} />
    </View></View>;
  return <View style={ui.fill}>
    <Header title="シール帳" right={<Button title="＋ 新規" disabled={busy} onPress={() => setForm({ title: '' })} />} />
    <FlatList data={state.books} keyExtractor={b => b.id} numColumns={2} contentContainerStyle={{ padding: 20, flexGrow: 1 }} columnWrapperStyle={{ gap: 20 }}
      ListEmptyComponent={<View style={ui.center}><Text style={{ fontSize: 70, color: c.accent }}>✳</Text>
        <Text style={[ui.title, { color: c.text }]}>最初の一冊を作りましょう</Text><Label>お気に入りの写真や言葉を、自分だけのシール帳に。</Label>
        <Button title="シール帳を作成" onPress={() => setForm({ title: '' })} /></View>}
      renderItem={({ item: b }) => <View style={{ flex: 1, maxWidth: '47%', marginBottom: 22 }}>
        <Pressable accessibilityRole="button" accessibilityLabel={b.title} onPress={() => openBook(b.id)} onLongPress={() => options(b)}
          style={{ aspectRatio: 0.8, padding: 20, borderRadius: 14, backgroundColor: b.color, justifyContent: 'flex-end', gap: 20 }}>
          <Text style={{ fontSize: 48, color: '#35343B' }}>✳</Text><Text numberOfLines={3} style={{ fontWeight: '700', fontSize: 19, color: '#25252A' }}>{b.title}</Text>
        </Pressable>
        <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 8 }}><View style={{ flex: 1 }}>
          <Text numberOfLines={1} style={{ color: c.text, fontWeight: '600' }}>{b.title}</Text>
          <Label>{b.pages.length}ページ · {state.stickers.filter(s => b.pages.some(p => p.id === s.placement?.pageId)).length}枚</Label>
        </View><Button title="⋯" small onPress={() => options(b)} /></View>
      </View>} />
    <View style={{ padding: 16, gap: 10, borderTopWidth: 0.5, borderTopColor: c.line }}>
      <Label>未貼付トレイ · {state.stickers.filter(s => !s.placement).length}枚</Label>
      <ScrollView horizontal style={{ maxHeight: 72 }} contentContainerStyle={{ gap: 12 }}>
        {state.stickers.filter(s => !s.placement).map(s => <Pressable key={s.id} accessibilityRole="button" accessibilityLabel={`${s.author}のシールの詳細`} onPress={() => detail(s.id)}>
          <Image source={{ uri: imageURI(s.thumbnail) }} style={{ width: 62, height: 62 }} resizeMode="contain" />
        </Pressable>)}
      </ScrollView>
      <View style={ui.row}><Button title="写真から" onPress={() => create('photo')} /><Button title="文字から" onPress={() => create('text')} /></View>
      <Button title="ファイルから受け取る" onPress={receive} />
    </View>
  </View>;
}

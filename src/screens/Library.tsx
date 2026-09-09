import { SafeAreaView } from 'react-native-safe-area-context';
import { SymbolView } from 'expo-symbols';
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
  if (form) return <SafeAreaView edges={['bottom']} style={ui.fill}><Header title={form.id ? '名前を変更' : '新しいシール帳'} back={busy ? undefined : () => setForm(undefined)} right={<Button small title="保存" disabled={busy} onPress={() => { void run(() => store.dispatch(form.id ? { type: 'renameBook', id: form.id, title: form.title } : { type: 'createBook', title: form.title })).then(ok => { if (ok) setForm(undefined); }); }} />} />
    <View style={ui.body}><TextInput autoFocus accessibilityLabel="シール帳の名前" placeholder="お気に入りコレクション" placeholderTextColor={c.muted}
      maxLength={120} value={form.title} onChangeText={title => setForm({ ...form, title })} style={[ui.input, { color: c.text, backgroundColor: c.card }]} />

    </View></SafeAreaView>;
  return <SafeAreaView edges={['bottom']} style={ui.fill}>
    <Header title="シール帳" right={<Button title="新規" small disabled={busy} onPress={() => setForm({ title: '' })} />} />
    <FlatList data={state.books} keyExtractor={b => b.id} contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={{ padding: 16, flexGrow: 1 }}
      ListEmptyComponent={<View style={ui.center}><SymbolView name="book.closed" tintColor={c.muted} style={{ width: 56, height: 56 }} />
        <Text style={[ui.title, { color: c.text }]}>シール帳がありません</Text><Label>新規をタップして、最初のシール帳を作成します。</Label>
        <Button title="シール帳を作成" onPress={() => setForm({ title: '' })} /></View>}
      renderItem={({ item: b, index }) => <View style={{ backgroundColor: c.card,
        borderTopLeftRadius: index === 0 ? 10 : 0, borderTopRightRadius: index === 0 ? 10 : 0,
        borderBottomLeftRadius: index === state.books.length - 1 ? 10 : 0, borderBottomRightRadius: index === state.books.length - 1 ? 10 : 0 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', paddingLeft: 16 }}>
          <Pressable accessibilityRole="button" accessibilityLabel={`${b.title}、${b.pages.length}ページ`} onPress={() => openBook(b.id)} onLongPress={() => options(b)}
            style={({ pressed }) => ({ flex: 1, flexDirection: 'row', alignItems: 'center', gap: 14, paddingVertical: 14, opacity: pressed ? 0.45 : 1 })}>
            <SymbolView name="book.closed" tintColor={c.accent} style={{ width: 28, height: 28 }} />
            <View style={{ flex: 1 }}><Text numberOfLines={2} style={{ fontSize: 17, color: c.text }}>{b.title}</Text>
              <Label>{b.pages.length}ページ · {state.stickers.filter(s => b.pages.some(p => p.id === s.placement?.pageId)).length}枚</Label>
            </View>
            <SymbolView name="chevron.right" tintColor={c.muted} style={{ width: 12, height: 16 }} />
          </Pressable>
          <Pressable accessibilityRole="button" accessibilityLabel={`${b.title}の操作`} onPress={() => options(b)} style={{ minWidth: 44, minHeight: 44, alignItems: 'center', justifyContent: 'center' }}>
            <SymbolView name="ellipsis.circle" tintColor={c.accent} style={{ width: 22, height: 22 }} />
          </Pressable>
        </View>
        {index < state.books.length - 1 && <View style={{ marginLeft: 58, height: 0.5, backgroundColor: c.line }} />}
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
  </SafeAreaView>;
}

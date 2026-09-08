import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator, Alert, AppState, FlatList, Linking, Platform,
  Pressable, StyleSheet, Text, TextInput, useColorScheme, View,
} from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { native, type Book } from './modules/stekki-native';
import { createOperationQueue, isTradeURL } from './src/receive-queue.cjs';

export default function App() {
  return <SafeAreaProvider><Library /><StatusBar style="auto" /></SafeAreaProvider>;
}

function Library() {
  const api = native;
  const dark = useColorScheme() === 'dark';
  const colors = dark
    ? { background: '#171719', text: '#FAFAFA', muted: '#AAAAB2', card: '#29292D', accent: '#A8BAFF' }
    : { background: '#F5F5F7', text: '#25252A', muted: '#707078', card: '#FFFFFF', accent: '#465DB4' };
  const [books, setBooks] = useState<Book[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);
  const [form, setForm] = useState<{ id?: string; title: string }>();
  const enqueue = useMemo(createOperationQueue, []);
  const pendingURLs = useRef(new Set<string>());

  const refresh = useCallback(async () => {
    if (!api) { setLoading(false); return; }
    try { setBooks(await api.listBooks()); setError(undefined); }
    catch (cause) { setError(message(cause)); }
    finally { setLoading(false); }
  }, []);

  const run = useCallback((operation: () => Promise<unknown>) => {
    return enqueue(async () => {
      setBusy(true);
      try { await operation(); }
      catch (cause) { Alert.alert('処理できませんでした', message(cause)); }
      finally { await refresh(); setBusy(false); }
    });
  }, [enqueue, refresh]);

  useEffect(() => {
    void refresh();
    const receive = (url: string) => {
      if (!api || !isTradeURL(url) || pendingURLs.current.has(url)) return;
      pendingURLs.current.add(url);
      // The form is an inline overlay, so it cannot race a api presentation.
      setForm(undefined);
      void run(async () => {
        await api.receiveFile(url);
      }).finally(() => pendingURLs.current.delete(url));
    };
    const linkSubscription = Linking.addEventListener('url', event => receive(event.url));
    void Linking.getInitialURL().then(url => { if (url) receive(url); }).catch(cause => setError(message(cause)));
    const stateSubscription = AppState.addEventListener('change', state => {
      if (state === 'active') void refresh();
    });
    return () => { linkSubscription.remove(); stateSubscription.remove(); };
  }, [refresh, run]);

  const button = (title: string, onPress: () => void, secondary = false) => (
    <Pressable accessibilityRole="button" accessibilityState={{ disabled: busy }} disabled={busy}
      onPress={onPress} style={({ pressed }) => [styles.button,
        { backgroundColor: secondary ? colors.card : colors.accent, opacity: pressed || busy ? 0.55 : 1 }]}>
      <Text style={[styles.buttonText, { color: secondary ? colors.text : dark ? '#171719' : '#FFFFFF' }]}>{title}</Text>
    </Pressable>
  );

  if (!api || Platform.OS !== 'ios') {
    return <SafeAreaView style={[styles.root, styles.center, { backgroundColor: colors.background }]}>
      <Text style={[styles.title, { color: colors.text }]}>Stekki</Text>
      <Text style={[styles.description, { color: colors.muted }]}>
        このアプリにはiOS用のDevelopment Buildが必要です。Expo Goでは編集・保存機能を利用できません。
      </Text>
      <Text selectable style={[styles.description, { color: colors.muted }]}>Macで npm run ios を実行するか、EAS Buildで作成したアプリを開いてください。</Text>
    </SafeAreaView>;
  }

  const options = (book: Book) => Alert.alert(book.title, 'シール帳の操作', [
    { text: '名前を変更', onPress: () => setForm({ id: book.id, title: book.title }) },
    { text: '削除', style: 'destructive', onPress: () => Alert.alert('シール帳を削除しますか？',
      '貼ってあるシールはトレイに戻ります。シール帳とページは削除されます。', [
        { text: 'キャンセル', style: 'cancel' },
        { text: '削除', style: 'destructive', onPress: () => { void run(() => api.deleteBook(book.id)); } },
      ]) },
    { text: 'キャンセル', style: 'cancel' },
  ]);

  return <SafeAreaView style={[styles.root, { backgroundColor: colors.background }]}>
    <View style={styles.header}>
      <View><Text style={[styles.eyebrow, { color: colors.accent }]}>STEKKI</Text>
        <Text accessibilityRole="header" style={[styles.title, { color: colors.text }]}>シール帳</Text></View>
      <Pressable accessibilityRole="button" accessibilityLabel="新しいシール帳" disabled={busy}
        onPress={() => setForm({ title: '' })} style={[styles.add, { backgroundColor: colors.card }]}>
        <Text style={{ fontSize: 30, color: colors.accent }}>＋</Text>
      </Pressable>
    </View>
    {error && <View style={styles.notice}><Text accessibilityRole="alert" style={{ color: colors.text }}>{error}</Text>
      {button('再読み込み', () => { void refresh(); }, true)}</View>}
    {loading ? <ActivityIndicator style={styles.loading} color={colors.accent} /> :
      <FlatList data={books} keyExtractor={book => book.id} numColumns={2}
        contentContainerStyle={styles.grid} columnWrapperStyle={styles.columns}
        refreshing={loading} onRefresh={() => { setLoading(true); void refresh(); }}
        ListEmptyComponent={<View style={styles.empty}>
          <Text style={[styles.emptySymbol, { color: colors.accent }]}>✳</Text>
          <Text style={[styles.emptyTitle, { color: colors.text }]}>最初の一冊を作りましょう</Text>
          <Text style={[styles.description, { color: colors.muted }]}>お気に入りの写真や言葉をシールに。{ '\n' }自分だけのページを、少しずつ。</Text>
          {button('シール帳を作成', () => setForm({ title: '' }))}
        </View>}
        renderItem={({ item }) => <View style={styles.bookCell}>
          <Pressable accessibilityRole="button" accessibilityLabel={`${item.title}、${item.pageCount}ページ、シール${item.stickerCount}枚`}
            disabled={busy} onPress={() => { void run(() => api.openBook(item.id)); }} onLongPress={() => options(item)}
            style={({ pressed }) => [styles.cover, { backgroundColor: item.color, opacity: pressed ? 0.7 : 1 }]}>
            <View style={styles.spine} /><Text style={styles.coverSymbol}>✳</Text>
            <Text numberOfLines={3} style={styles.coverTitle}>{item.title}</Text>
          </Pressable>
          <View style={styles.bookCaption}><View style={{ flex: 1 }}>
            <Text numberOfLines={1} style={[styles.bookTitle, { color: colors.text }]}>{item.title}</Text>
            <Text style={[styles.count, { color: colors.muted }]}>{item.pageCount}ページ · {item.stickerCount}枚</Text>
          </View><Pressable accessibilityRole="button" accessibilityLabel={`${item.title}の操作`} disabled={busy}
            onPress={() => options(item)} hitSlop={10}><Text style={{ color: colors.muted, fontSize: 24 }}>⋯</Text></Pressable></View>
        </View>} />}
    <View style={[styles.footer, { borderTopColor: dark ? '#333338' : '#E5E5EA' }]}>
      <Text style={[styles.footerLabel, { color: colors.muted }]}>シールを作る</Text>
      <View style={styles.actions}>
        {button('写真から', () => { void run(() => api.createSticker('photo')); }, true)}
        {button('文字から', () => { void run(() => api.createSticker('text')); }, true)}
        {busy && <ActivityIndicator color={colors.accent} accessibilityLabel="処理中" />}
      </View>
    </View>
    {form && <View accessibilityViewIsModal style={StyleSheet.absoluteFill}>
      <SafeAreaView style={[styles.root, styles.form, { backgroundColor: colors.background }]}>
        <Text style={[styles.emptyTitle, { color: colors.text }]}>{form?.id ? '名前を変更' : '新しいシール帳'}</Text>
        <TextInput accessibilityLabel="シール帳の名前" autoFocus maxLength={120} placeholder="例：お気に入りコレクション"
          placeholderTextColor={colors.muted} value={form?.title ?? ''}
          onChangeText={title => setForm(current => current ? { ...current, title } : current)}
          style={[styles.input, { color: colors.text, backgroundColor: colors.card }]} />
        {button('保存', () => {
          if (!form) return;
          const input = form;
          setForm(undefined);
          void run(() => input.id ? api.renameBook(input.id, input.title) : api.createBook(input.title));
        })}
        {button('キャンセル', () => setForm(undefined), true)}
      </SafeAreaView>
    </View>}
  </SafeAreaView>;
}

function message(cause: unknown): string {
  return cause instanceof Error ? cause.message : '処理に失敗しました。もう一度お試しください。';
}

const styles = StyleSheet.create({
  root: { flex: 1 }, center: { justifyContent: 'center', padding: 28, gap: 20 },
  header: { paddingHorizontal: 24, paddingTop: 14, paddingBottom: 22, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  eyebrow: { fontSize: 11, letterSpacing: 3, fontWeight: '700', marginBottom: 6 },
  title: { fontSize: 34, fontWeight: '700', letterSpacing: -1 },
  add: { width: 48, height: 48, borderRadius: 24, alignItems: 'center', justifyContent: 'center' },
  grid: { paddingHorizontal: 24, paddingBottom: 32, flexGrow: 1 }, columns: { gap: 24 },
  bookCell: { flex: 1, maxWidth: '47%', marginBottom: 26 },
  cover: { aspectRatio: 0.78, borderRadius: 12, padding: 20, justifyContent: 'flex-end', overflow: 'hidden' },
  spine: { position: 'absolute', top: 0, bottom: 0, left: 10, width: 2, backgroundColor: '#00000012' },
  coverSymbol: { fontSize: 54, color: '#31313B', marginBottom: 14 },
  coverTitle: { color: '#25252A', fontSize: 19, fontWeight: '700' },
  bookCaption: { marginTop: 12, flexDirection: 'row', alignItems: 'center', gap: 6 },
  bookTitle: { fontSize: 15, fontWeight: '600' }, count: { fontSize: 12, marginTop: 4 },
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: 40, gap: 16 },
  emptySymbol: { fontSize: 76 }, emptyTitle: { fontSize: 22, fontWeight: '700' },
  description: { fontSize: 15, lineHeight: 24, textAlign: 'center' },
  button: { borderRadius: 16, paddingHorizontal: 22, paddingVertical: 15, alignItems: 'center', minHeight: 48 },
  buttonText: { fontSize: 15, fontWeight: '600' },
  footer: { padding: 20, paddingBottom: 12, borderTopWidth: StyleSheet.hairlineWidth },
  footerLabel: { fontSize: 12, marginBottom: 10 }, actions: { flexDirection: 'row', gap: 10, alignItems: 'center' },
  form: { padding: 28, gap: 20 }, input: { borderRadius: 14, padding: 18, fontSize: 17 },
  notice: { padding: 20, gap: 12 }, loading: { flex: 1 },
});

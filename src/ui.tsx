import { useRef, useState, useSyncExternalStore, type ReactNode } from 'react';
import { Alert, Pressable, StyleSheet, Text, useColorScheme, View } from 'react-native';
import type { SerialStore } from './serial-store';

export const useLibrary = (store: SerialStore) => useSyncExternalStore(store.subscribe, store.snapshot);
export const useTheme = () => useColorScheme() === 'dark'
  ? { bg: '#171719', card: '#29292D', text: '#FAFAFA', muted: '#AEAEB7', accent: '#ABBFFF', line: '#38383C' }
  : { bg: '#F5F5F7', card: '#FFFFFF', text: '#25252A', muted: '#707078', accent: '#465DB4', line: '#E5E5EA' };

export function useTask() {
  const active = useRef(false);
  const [busy, setBusy] = useState(false);
  const run = async (operation: () => Promise<unknown>): Promise<boolean> => {
    if (active.current) return false;
    active.current = true; setBusy(true);
    try { await operation(); return true; }
    catch (error) { Alert.alert('処理できませんでした', error instanceof Error ? error.message : 'もう一度お試しください。'); return false; }
    finally { active.current = false; setBusy(false); }
  };
  return { busy, run };
}

export function Button({ title, onPress, disabled, danger, small }: {
  title: string; onPress(): void; disabled?: boolean; danger?: boolean; small?: boolean;
}) {
  const c = useTheme();
  return <Pressable accessibilityRole="button" accessibilityState={{ disabled: !!disabled }} disabled={disabled}
    onPress={onPress} style={({ pressed }) => [ui.button, { backgroundColor: c.card, opacity: disabled || pressed ? 0.45 : 1 }, small && { paddingHorizontal: 12 }]}>
    <Text style={{ color: danger ? '#D8404D' : c.accent, fontWeight: '600', fontSize: 15 }}>{title}</Text>
  </Pressable>;
}
export function Header({ title, back, right }: { title: string; back?: () => void; right?: ReactNode }) {
  const c = useTheme();
  return <View style={ui.header}>
    {back && <Button title="戻る" onPress={back} small />}
    <Text accessibilityRole="header" numberOfLines={1} style={[ui.heading, { color: c.text }]}>{title}</Text>
    {right}
  </View>;
}
export function Label({ children }: { children: ReactNode }) { const c = useTheme(); return <Text style={[ui.label, { color: c.muted }]}>{children}</Text>; }
export const ui = StyleSheet.create({
  fill: { flex: 1 }, header: { flexDirection: 'row', alignItems: 'center', gap: 10, padding: 16 },
  heading: { flex: 1, fontWeight: '700', fontSize: 25 }, button: { paddingVertical: 12, paddingHorizontal: 18, borderRadius: 14, minHeight: 44, alignItems: 'center', justifyContent: 'center' },
  body: { padding: 20, gap: 16 }, row: { flexDirection: 'row', alignItems: 'center', gap: 10, flexWrap: 'wrap' },
  label: { fontSize: 13, lineHeight: 20 }, title: { fontSize: 19, fontWeight: '700' },
  input: { borderRadius: 14, padding: 15, fontSize: 17, minHeight: 48 },
  card: { padding: 18, borderRadius: 18, gap: 12 }, center: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 24, gap: 20 },
});

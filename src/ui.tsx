import { useLayoutEffect, useRef, useState, useSyncExternalStore, type ReactNode } from 'react';
import { Alert, Pressable, StyleSheet, Text, useColorScheme } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { SerialStore } from './serial-store';

export const useLibrary = (store: SerialStore) => useSyncExternalStore(store.subscribe, store.snapshot);
export const useTheme = () => useColorScheme() === 'dark'
  ? { bg: '#000000', card: '#1C1C1E', text: '#FFFFFF', muted: '#98989D', accent: '#0A84FF', line: '#38383A' }
  : { bg: '#F2F2F7', card: '#FFFFFF', text: '#000000', muted: '#8E8E93', accent: '#007AFF', line: '#E5E5EA' };

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
    onPress={onPress} style={({ pressed }) => [ui.button, { backgroundColor: small ? 'transparent' : c.card, opacity: disabled || pressed ? 0.45 : 1 }, small && { paddingHorizontal: 12 }]}>
    <Text style={{ color: danger ? '#FF3B30' : c.accent, fontWeight: '400', fontSize: 17 }}>{title}</Text>
  </Pressable>;
}
// The native stack owns the navigation bar, title, back indicator and transitions.
export function Header({ title, back, right, nativeBack = false }: {
  title: string; back?: () => void; right?: ReactNode; nativeBack?: boolean;
}) {
  const navigation = useNavigation<NativeStackNavigationProp<Record<string, object | undefined>>>();
  useLayoutEffect(() => {
    navigation.setOptions({
      title,
      headerBackVisible: nativeBack && !!back,
      gestureEnabled: nativeBack && !!back,
      headerLeft: nativeBack ? undefined : () => back ? <Button title="キャンセル" onPress={back} small /> : null,
      headerRight: () => right,
      headerLargeTitle: title === 'シール帳' && !back,
    });
  }, [navigation, title, back, right, nativeBack]);
  return null;
}
export function Label({ children }: { children: ReactNode }) { const c = useTheme(); return <Text style={[ui.label, { color: c.muted }]}>{children}</Text>; }
export const ui = StyleSheet.create({
  fill: { flex: 1 }, button: { paddingVertical: 12, paddingHorizontal: 18, borderRadius: 10, minHeight: 44, alignItems: 'center', justifyContent: 'center' },
  body: { padding: 16, paddingBottom: 40, gap: 16 }, row: { flexDirection: 'row', alignItems: 'center', gap: 10, flexWrap: 'wrap' },
  label: { fontSize: 13, lineHeight: 20 }, title: { fontSize: 20, fontWeight: '600' },
  input: { borderRadius: 10, padding: 12, fontSize: 17, minHeight: 48 },
  card: { padding: 16, borderRadius: 10, gap: 12 }, center: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 24, gap: 20 },
});

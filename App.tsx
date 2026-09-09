import { useEffect, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { openStore, pickTrade, type Incoming } from './src/storage';
import type { SerialStore } from './src/serial-store';
import { Button, Label, ui, useTask, useTheme } from './src/ui';
import { Library } from './src/screens/Library';
import { Editor } from './src/screens/Editor';
import { Create } from './src/screens/Create';
import { Detail } from './src/screens/Detail';
import { Receive } from './src/screens/Receive';

type Route = { name: 'library' } | { name: 'editor'; bookId: string; pageId?: string }
  | { name: 'create'; kind: 'photo' | 'text' } | { name: 'detail'; id: string }
  | { name: 'receive'; incoming: Incoming };

export default function App() {
  return <SafeAreaProvider><Root /><StatusBar style="auto" /></SafeAreaProvider>;
}
function Root() {
  const c = useTheme(), { busy, run } = useTask();
  const [store, setStore] = useState<SerialStore>(), [error, setError] = useState<string>();
  const [routes, setRoutes] = useState<Route[]>([{ name: 'library' }]);
  const load = async () => {
    setError(undefined);
    try { setStore(await openStore()); }
    catch (e) { setError(e instanceof Error ? e.message : '保存データを読み込めません。'); }
  };
  useEffect(() => { void load(); }, []);
  const push = (route: Route) => setRoutes(current => [...current, route]);
  const route = routes.at(-1)!;
  const back = () => {
    if (route.name === 'receive') route.incoming.dispose();
    setRoutes(current => current.length > 1 ? current.slice(0, -1) : current);
  };
  let content;
  if (!store) content = <View style={ui.center}>{error ? <><Label>{error}</Label><Button title="再読み込み" onPress={() => { void load(); }} /></> : <ActivityIndicator color={c.accent} />}</View>;
  else switch (route.name) {
    case 'library': content = <Library store={store} openBook={bookId => push({ name: 'editor', bookId })}
      create={kind => push({ name: 'create', kind })} detail={id => push({ name: 'detail', id })}
      receive={() => { void run(async () => { const incoming = await pickTrade(); if (incoming) push({ name: 'receive', incoming }); }); }} />; break;
    case 'editor': content = <Editor store={store} bookId={route.bookId} pageId={route.pageId} back={back}
      setPage={pageId => setRoutes(current => [...current.slice(0, -1), { ...route, pageId }])}
      create={kind => push({ name: 'create', kind })} detail={id => push({ name: 'detail', id })} />; break;
    case 'create': content = <Create store={store} kind={route.kind} back={back} />; break;
    case 'detail': content = <Detail store={store} id={route.id} back={back} />; break;
    case 'receive': content = <Receive store={store} incoming={route.incoming} back={back} />; break;
  }
  return <SafeAreaView style={[ui.fill, { backgroundColor: c.bg }]}>{content}
    {busy && <View accessibilityViewIsModal style={{ position: 'absolute', top: 0, right: 0, bottom: 0, left: 0, backgroundColor: '#00000044', justifyContent: 'center' }}><ActivityIndicator size="large" color={c.accent} /></View>}
  </SafeAreaView>;
}

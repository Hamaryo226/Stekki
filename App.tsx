import { useEffect, useState } from 'react';
import { ActivityIndicator, View, useColorScheme } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { NavigationContainer, DefaultTheme, DarkTheme } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { StatusBar } from 'expo-status-bar';
import { openStore, pickTrade, type Incoming } from './src/storage';
import type { SerialStore } from './src/serial-store';
import { Button, Label, ui, useTask, useTheme } from './src/ui';
import { Library } from './src/screens/Library';
import { Editor } from './src/screens/Editor';
import { Create } from './src/screens/Create';
import { Detail } from './src/screens/Detail';
import { Receive } from './src/screens/Receive';

type Routes = {
  library: undefined;
  editor: { bookId: string; pageId?: string };
  create: { kind: 'photo' | 'text' };
  detail: { id: string };
  receive: undefined;
};
const Stack = createNativeStackNavigator<Routes>();

export default function App() {
  return <SafeAreaProvider><Root /><StatusBar style="auto" /></SafeAreaProvider>;
}
function Root() {
  const c = useTheme(), dark = useColorScheme() === 'dark', { busy, run } = useTask();
  const [store, setStore] = useState<SerialStore>(), [error, setError] = useState<string>();
  const [incoming, setIncoming] = useState<Incoming>();
  const load = async () => {
    setError(undefined);
    try { setStore(await openStore()); }
    catch (e) { setError(e instanceof Error ? e.message : '保存データを読み込めません。'); }
  };
  useEffect(() => { void load(); }, []);
  if (!store) return <SafeAreaView style={[ui.center, { backgroundColor: c.bg }]}>{error ? <><Label>{error}</Label><Button title="再読み込み" onPress={() => { void load(); }} /></> : <ActivityIndicator color={c.accent} />}</SafeAreaView>;
  return <View style={ui.fill}>
    <NavigationContainer theme={dark ? DarkTheme : DefaultTheme}>
      <Stack.Navigator screenOptions={{ headerTintColor: c.accent, contentStyle: { backgroundColor: c.bg }, headerBackTitle: '戻る' }}>
        <Stack.Screen name="library" options={{ title: 'シール帳', headerLargeTitle: true }}>{({ navigation }) =>
          <Library store={store} openBook={bookId => navigation.push('editor', { bookId })}
            create={kind => navigation.push('create', { kind })} detail={id => navigation.push('detail', { id })}
            receive={() => { void run(async () => { const value = await pickTrade(); if (value) { setIncoming(value); navigation.navigate('receive'); } }); }} />
        }</Stack.Screen>
        <Stack.Screen name="editor">{({ navigation, route }) =>
          <Editor store={store} {...route.params} back={navigation.goBack} setPage={pageId => navigation.setParams({ pageId })}
            create={kind => navigation.push('create', { kind })} detail={id => navigation.push('detail', { id })} />
        }</Stack.Screen>
        <Stack.Screen name="detail" options={{ title: 'シールの詳細' }}>{({ navigation, route }) =>
          <Detail store={store} id={route.params.id} back={navigation.goBack} />
        }</Stack.Screen>
        <Stack.Group screenOptions={{ presentation: 'modal', gestureEnabled: false }}>
          <Stack.Screen name="create">{({ navigation, route }) =>
            <Create store={store} kind={route.params.kind} back={navigation.goBack} />
          }</Stack.Screen>
          <Stack.Screen name="receive" options={{ title: 'シールを受け取る' }}>{({ navigation }) => incoming ?
            <Receive store={store} incoming={incoming} back={() => { incoming.dispose(); navigation.goBack(); }} /> : null
          }</Stack.Screen>
        </Stack.Group>
      </Stack.Navigator>
    </NavigationContainer>
    {busy && <View accessibilityViewIsModal style={{ position: 'absolute', top: 0, right: 0, bottom: 0, left: 0, backgroundColor: '#00000044', justifyContent: 'center' }}><ActivityIndicator size="large" color={c.accent} /></View>}
  </View>;
}

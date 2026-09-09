import { useState } from 'react';
import { Image, TextInput, View } from 'react-native';
import type { SerialStore } from '../serial-store';
import { addReceived, type Incoming } from '../storage';
import { Button, Header, Label, ui, useTask, useTheme } from '../ui';

export function Receive({ store, incoming, back }: { store: SerialStore; incoming: Incoming; back(): void }) {
  const c = useTheme(), { busy, run } = useTask();
  const [sender, setSender] = useState(incoming.manifest.authorDisplayName);
  return <View style={ui.fill}><Header title="シールを受け取る" back={busy ? undefined : back} />
    <View style={ui.body}><Image source={{ uri: incoming.preview }} style={{ width: '100%', height: 240 }} resizeMode="contain" />
      <Label>作成者：{incoming.manifest.authorDisplayName}</Label><Label>作成：{new Date(incoming.manifest.createdAt).toLocaleString()}</Label>
      <Label>受取元</Label><TextInput accessibilityLabel="受取元" value={sender} onChangeText={setSender} maxLength={120} style={[ui.input, { color: c.text, backgroundColor: c.card }]} />
      <Label>「トレイに追加」を押したときだけ保存されます。</Label>
      <Button title="トレイに追加" disabled={busy} onPress={() => { void run(() => addReceived(store, incoming, sender)).then(ok => { if (ok) back(); }); }} />
      <Button title="受け取らない" disabled={busy} onPress={back} />
    </View>
  </View>;
}

import { useRef, useState } from 'react';
import { Image, Keyboard, Pressable, ScrollView, Switch, Text, TextInput, View, useWindowDimensions } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { manipulateAsync, SaveFormat, type ImageResult } from 'expo-image-manipulator';
import { captureRef, releaseCapture } from 'react-native-view-shot';
import Slider from '@react-native-community/slider';
import type { SerialStore } from '../serial-store';
import { addImage, safelyDelete } from '../storage';
import { Button, Header, Label, ui, useTask, useTheme } from '../ui';
import { TextSticker, textFonts, type TextStyle } from '../components/TextSticker';

const colors = ['#222222', '#FFFFFF', '#F35173', '#F39C37', '#EDD544', '#76AD79', '#6F9CDD', '#9E80CF'];
export function Create({ store, kind, back }: { store: SerialStore; kind: 'photo' | 'text'; back(): void }) {
  const c = useTheme(), { busy, run } = useTask(), window = useWindowDimensions();
  const capture = useRef<View>(null);
  const [text, setText] = useState(''), [photo, setPhoto] = useState<ImageResult>(), [loaded, setLoaded] = useState(false);
  const [radius, setRadius] = useState(0), [author, setAuthor] = useState('自分');
  const [style, setStyle] = useState<TextStyle>({ font: textFonts[1].value, color: '#222222', stroke: '#FFFFFF', strokeWidth: 3, shape: 'plain', intensity: 0.5 });
  const width = Math.min(320, window.width - 60);
  const previewHeight = kind === 'text' ? width * 0.75 : photo ? Math.min(320, width * photo.height / photo.width) : 220;
  const previewWidth = kind === 'text' || !photo ? width : previewHeight * photo.width / photo.height;
  const pick = () => { void run(async () => {
    const selected = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], allowsEditing: false, quality: 1 });
    if (selected.canceled) return;
    const asset = selected.assets[0];
    const result = await manipulateAsync(asset.uri, [{ resize: asset.width > asset.height ? { width: Math.min(1024, asset.width) } : { height: Math.min(1024, asset.height) } }], { format: SaveFormat.PNG });
    if (photo) safelyDelete(photo.uri);
    setLoaded(false); setPhoto(result);
  }); };
  const close = () => { if (photo) safelyDelete(photo.uri); back(); };
  const save = () => { void run(async () => {
    Keyboard.dismiss();
    const uri = await captureRef(capture, { format: 'png', result: 'tmpfile', quality: 1 });
    try { await addImage(store, uri, { author }); } finally { releaseCapture(uri); }
  }).then(ok => { if (ok) close(); }); };
  const choice = (field: 'color' | 'stroke' | 'plate') => <View style={ui.row}>{colors.map(value => <Pressable key={value} accessibilityRole="button"
    accessibilityLabel={`${field === 'color' ? '文字' : field === 'stroke' ? '縁取り' : '背景'}色 ${value}`} onPress={() => setStyle(s => ({ ...s, [field]: value }))}
    style={{ width: 32, height: 32, borderRadius: 16, backgroundColor: value, borderWidth: style[field] === value ? 3 : 1, borderColor: style[field] === value ? c.accent : '#888888' }} />)}</View>;
  return <View style={ui.fill}><Header title={kind === 'photo' ? '写真シール' : '文字シール'} back={busy ? undefined : close}
    right={<Button title={busy ? '保存中…' : '保存'} disabled={busy || (kind === 'photo' ? !loaded : !text.trim())} onPress={save} />} />
    <ScrollView keyboardShouldPersistTaps="handled" keyboardDismissMode="on-drag" contentContainerStyle={ui.body}>
      <Pressable onPress={Keyboard.dismiss} style={{ alignItems: 'center', padding: 10, borderRadius: 18, backgroundColor: '#D6D8DF' }}>
        <View ref={capture} collapsable={false} style={{ width: previewWidth, height: previewHeight, backgroundColor: 'transparent', overflow: 'hidden', borderRadius: kind === 'photo' ? Math.min(previewWidth, previewHeight) * radius : 0 }}>
          {kind === 'text' ? <TextSticker text={text} style={style} /> : photo ? <Image source={{ uri: photo.uri }} onLoad={() => setLoaded(true)} onError={() => setLoaded(false)} style={{ width: '100%', height: '100%' }} resizeMode="contain" /> : null}
        </View>
      </Pressable>
      {kind === 'photo' ? <>
        <Button title="写真を選ぶ" disabled={busy} onPress={pick} />
        <Label>角丸：{Math.round(radius * 100)}%</Label><Slider minimumValue={0} maximumValue={0.5} value={radius} onValueChange={setRadius} disabled={busy} accessibilityLabel="角の丸さ" />
        <Label>透明PNGも取り込めます。背景の自動切り抜きはExpo Go版では利用できません。</Label>
      </> : <>
        <TextInput accessibilityLabel="シールの文字" multiline maxLength={60} placeholder="シールにする言葉" placeholderTextColor={c.muted} value={text}
          onChangeText={value => setText(value.split('\n').slice(0, 4).join('\n'))} style={[ui.input, { backgroundColor: c.card, color: c.text }]} />
        <Label>最大60文字・4行。長い文章は改行して調整できます。</Label>
        <ScrollView horizontal contentContainerStyle={{ gap: 8 }}>{textFonts.map(font => <Button key={font.value} title={`${style.font === font.value ? '✓ ' : ''}${font.name}`} small onPress={() => setStyle(s => ({ ...s, font: font.value }))} />)}</ScrollView>
        <View style={ui.row}>{(['plain', 'arch', 'wave', 'bulge'] as const).map((shape, i) => <Button key={shape} title={`${style.shape === shape ? '✓ ' : ''}${['通常', 'アーチ', '波', 'ふくらみ'][i]}`} small onPress={() => setStyle(s => ({ ...s, shape }))} />)}</View>
        {style.shape !== 'plain' && <><Label>形の強さ</Label><Slider minimumValue={-1} maximumValue={1} value={style.intensity} onValueChange={intensity => setStyle(s => ({ ...s, intensity }))} accessibilityLabel="形の強さ" /></>}
        <Label>文字色</Label>{choice('color')}
        <Label>縁取り</Label>{choice('stroke')}<Slider minimumValue={0} maximumValue={8} value={style.strokeWidth} onValueChange={strokeWidth => setStyle(s => ({ ...s, strokeWidth }))} accessibilityLabel="縁取りの太さ" />
        <View style={ui.row}><Text style={{ color: c.text }}>背景プレート</Text><Switch value={!!style.plate} onValueChange={value => setStyle(s => ({ ...s, plate: value ? '#FFFFFF' : undefined }))} /></View>
        {style.plate && choice('plate')}
      </>}
      <Label>作成者</Label><TextInput accessibilityLabel="作成者" maxLength={120} value={author} onChangeText={setAuthor} style={[ui.input, { backgroundColor: c.card, color: c.text }]} />
    </ScrollView>
  </View>;
}

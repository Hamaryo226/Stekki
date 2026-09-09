import Svg, { G, Rect, Text as SvgText } from 'react-native-svg';

export type TextStyle = { font: string; color: string; stroke: string; strokeWidth: number; plate?: string; shape: 'plain' | 'arch' | 'wave' | 'bulge'; intensity: number };
export const textFonts = [{ name: '標準', value: 'Helvetica-Bold' }, { name: '丸ゴシック', value: 'ArialRoundedMTBold' },
  { name: '手書き', value: 'MarkerFelt-Wide' }, { name: 'かわいい', value: 'ChalkboardSE-Bold' }, { name: 'タイプライター', value: 'AmericanTypewriter-Bold' }];
export function TextSticker({ text, style }: { text: string; style: TextStyle }) {
  const lines = text.split('\n').filter(Boolean).slice(0, 4);
  const longest = Math.max(1, ...lines.map(l => Array.from(l).length));
  const fontSize = Math.min(48, 260 / longest, 180 / (Math.max(1, lines.length) * 1.8)), lineHeight = fontSize * 1.8;
  const characters = lines.flatMap((line, row) => {
    const chars = Array.from(line);
    return chars.map((char, i) => {
      const relative = chars.length === 1 ? 0 : i / (chars.length - 1) - 0.5;
      const x = 160 + (i - (chars.length - 1) / 2) * fontSize;
      let y = 125 + (row - (lines.length - 1) / 2) * lineHeight;
      let angle = 0, size = fontSize;
      if (style.shape === 'arch') { y += style.intensity * fontSize * 2 * relative * relative; angle = style.intensity * relative * 45; }
      if (style.shape === 'wave') { y += Math.sin(relative * Math.PI * 2) * style.intensity * fontSize * 0.5; angle = Math.cos(relative * Math.PI * 2) * style.intensity * 15; }
      if (style.shape === 'bulge') size *= 1 + Math.cos(relative * Math.PI) * style.intensity * 0.5;
      return { char, x, y, angle, size, key: `${row}-${i}` };
    });
  });
  return <Svg width="100%" height="100%" viewBox="0 0 320 240">
    {style.plate && <Rect x="5" y="5" width="310" height="230" rx="25" fill={style.plate} />}
    {characters.map(ch => <G key={ch.key} transform={`rotate(${ch.angle}, ${ch.x}, ${ch.y})`}>
      {style.strokeWidth > 0 && <SvgText x={ch.x} y={ch.y} fontSize={ch.size} fontFamily={style.font} textAnchor="middle"
        fill={style.stroke} stroke={style.stroke} strokeWidth={style.strokeWidth} strokeLinejoin="round">{ch.char}</SvgText>}
      <SvgText x={ch.x} y={ch.y} fontSize={ch.size} fontFamily={style.font} textAnchor="middle" fill={style.color}>{ch.char}</SvgText>
    </G>)}
  </Svg>;
}

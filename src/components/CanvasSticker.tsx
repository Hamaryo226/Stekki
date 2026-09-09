import { useEffect, useMemo, useRef } from 'react';
import { Animated, Image, PanResponder, type GestureResponderEvent } from 'react-native';
import type { Sticker, Placement } from '../model';
import { movePose, type Point, type Pose } from '../gesture';
import { imageURI } from '../storage';

export type CanvasFrame = { x: number; y: number; width: number; height: number };
export function CanvasSticker({ sticker, frame, editing, disabled, selected, onSelect, onDetail, onCommit, onReturn, onDragging }: {
  sticker: Sticker; frame: CanvasFrame; editing: boolean; disabled: boolean; selected: boolean;
  onSelect(): void; onDetail(): void; onCommit(p: Partial<Placement>): Promise<boolean>; onReturn(): Promise<boolean>; onDragging(value: boolean): void;
}) {
  const p = sticker.placement!;
  const props = useRef({ frame, editing, disabled, onSelect, onDetail, onCommit, onReturn, onDragging, p });
  props.current = { frame, editing, disabled, onSelect, onDetail, onCommit, onReturn, onDragging, p };
  const initial = () => ({ x: p.x * frame.width, y: p.y * frame.height, scale: p.scale, rotation: p.rotation });
  const current = useRef<Pose>(initial());
  const baseline = useRef<{ pose: Pose; touches: Point[] }>({ pose: initial(), touches: [] });
  const moved = useRef(false), active = useRef(false);
  const x = useRef(new Animated.Value(initial().x)).current, y = useRef(new Animated.Value(initial().y)).current;
  const scale = useRef(new Animated.Value(p.scale)).current, rotation = useRef(new Animated.Value(p.rotation)).current;
  const display = (v: Pose) => { current.current = v; x.setValue(v.x); y.setValue(v.y); scale.setValue(v.scale); rotation.setValue(v.rotation); };
  useEffect(() => { if (!active.current) display(initial()); }, [p, frame.width, frame.height]);
  const touches = (e: GestureResponderEvent) => e.nativeEvent.touches.slice(0, 2).map(t => ({ x: t.pageX - props.current.frame.x, y: t.pageY - props.current.frame.y }));
  const responder = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => !props.current.disabled,
    onPanResponderGrant: e => {
      moved.current = false; active.current = true;
      baseline.current = { pose: { ...current.current }, touches: touches(e) };
      if (props.current.editing) props.current.onSelect();
    },
    onPanResponderMove: e => {
      if (!props.current.editing) return;
      const points = touches(e);
      if (points.length !== baseline.current.touches.length) { baseline.current = { pose: { ...current.current }, touches: points }; return; }
      const next = movePose(baseline.current.pose, baseline.current.touches, points);
      if (Math.hypot(next.x - current.current.x, next.y - current.current.y) > 1 || points.length > 1) {
        moved.current = true; props.current.onDragging(true);
      }
      display(next);
    },
    onPanResponderRelease: () => {
      active.current = false; props.current.onDragging(false);
      if (!props.current.editing) { props.current.onDetail(); return; }
      if (!moved.current) return;
      const pose = current.current, f = props.current.frame;
      const result = pose.y > f.height + 12 ? props.current.onReturn()
        : props.current.onCommit({ x: pose.x / f.width, y: pose.y / f.height, scale: pose.scale, rotation: pose.rotation });
      void result.then(ok => {
        if (!ok) {
          const saved = props.current.p;
          display({ x: saved.x * f.width, y: saved.y * f.height, scale: saved.scale, rotation: saved.rotation });
        }
      });
    },
    onPanResponderTerminationRequest: () => false,
    onPanResponderTerminate: () => {
      active.current = false; props.current.onDragging(false);
      const { p: saved, frame: f } = props.current;
      display({ x: saved.x * f.width, y: saved.y * f.height, scale: saved.scale, rotation: saved.rotation });
    },
  }), []);
  const longest = Math.max(sticker.width, sticker.height);
  const width = 120 * sticker.width / longest, height = 120 * sticker.height / longest;
  return <Animated.View {...responder.panHandlers} accessibilityRole="button" accessibilityLabel={`${sticker.author}のシール`}
    style={{ position: 'absolute', left: x, top: y, width, height, marginLeft: -width / 2, marginTop: -height / 2,
      zIndex: selected ? 100000 : p.z, borderWidth: editing && selected ? 1 : 0, borderColor: '#637EDF', borderStyle: 'dashed',
      shadowColor: '#000', shadowOpacity: p.shadow ? 0.22 : 0, shadowRadius: 5, shadowOffset: { width: 2, height: 3 },
      transform: [{ rotate: rotation.interpolate({ inputRange: [-Math.PI, Math.PI], outputRange: ['-180deg', '180deg'], extrapolate: 'extend' }) }, { scale }, { scaleX: p.flipped ? -1 : 1 }] }}>
    <Image source={{ uri: imageURI(sticker.file) }} style={{ width: '100%', height: '100%' }} resizeMode="contain" />
  </Animated.View>;
}

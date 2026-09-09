export type Point = { x: number; y: number };
export type Pose = Point & { scale: number; rotation: number };
const midpoint = (p: Point[]) => p.length === 1 ? p[0] : { x: (p[0].x + p[1].x) / 2, y: (p[0].y + p[1].y) / 2 };
const distance = (p: Point[]) => Math.hypot(p[1].x - p[0].x, p[1].y - p[0].y);
const angle = (p: Point[]) => Math.atan2(p[1].y - p[0].y, p[1].x - p[0].x);
/** Transform around the fingers, preserving the grasped point rather than scaling about the sticker center. */
export function movePose(base: Pose, start: Point[], next: Point[]): Pose {
  if (!start.length || start.length !== next.length) return base;
  const a = midpoint(start), b = midpoint(next);
  const ratio = start.length > 1 ? Math.min(16, Math.max(0.0625, distance(next) / Math.max(distance(start), 1))) : 1;
  const rotation = start.length > 1 ? angle(next) - angle(start) : 0;
  const x = (base.x - a.x) * ratio, y = (base.y - a.y) * ratio;
  return { x: b.x + x * Math.cos(rotation) - y * Math.sin(rotation), y: b.y + x * Math.sin(rotation) + y * Math.cos(rotation),
    scale: base.scale * ratio, rotation: base.rotation + rotation };
}

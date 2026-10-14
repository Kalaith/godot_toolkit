extends RefCounted
## Placeholder-art primitives for any CanvasItem's _draw(), so prototypes can
## be drawn in code before art exists. Every function takes the canvas first.


## A filled ellipse with radii (x, y).
static func oval(canvas: CanvasItem, center: Vector2, radii: Vector2, tint: Color) -> void:
	canvas.draw_set_transform(center, 0.0, radii)
	canvas.draw_circle(Vector2.ZERO, 1.0, tint)
	canvas.draw_set_transform(Vector2.ZERO)


## A soft ground shadow under a feet-origin actor: stacked ovals fading out.
static func ground_shadow(canvas: CanvasItem, feet: Vector2, width: float, alpha: float = 0.28, layers: int = 4) -> void:
	for i in range(layers):
		var grow: float = 1.0 + float(i) * 0.18
		oval(canvas, feet, Vector2(width * 0.5 * grow, width * 0.16 * grow), Color(0, 0, 0, alpha / float(layers)))


static func ring(canvas: CanvasItem, center: Vector2, radius: float, tint: Color, width: float = 2.0, points: int = 64) -> void:
	canvas.draw_arc(center, radius, 0.0, TAU, points, tint, width, true)


## An arc broken into `dashes` dashes with gaps of `gap` (0..1 of each step).
static func dashed_ring(canvas: CanvasItem, center: Vector2, radius: float, tint: Color, dashes: int = 24, gap: float = 0.4, width: float = 2.0, turn: float = 0.0) -> void:
	var step: float = TAU / maxi(dashes, 1)
	for i in range(dashes):
		var start: float = turn + i * step
		canvas.draw_arc(center, radius, start, start + step * (1.0 - gap), 8, tint, width, true)


## The points of a regular polygon (or a star when `inner` > 0, as a fraction
## of `radius`), starting straight up.
static func polygon_points(center: Vector2, radius: float, sides: int, inner: float = 0.0, turn: float = 0.0) -> PackedVector2Array:
	var result := PackedVector2Array()
	var count: int = sides * (2 if inner > 0.0 else 1)
	for i in range(count):
		var angle: float = turn - PI / 2.0 + TAU * float(i) / count
		var reach: float = radius * (inner if inner > 0.0 and i % 2 == 1 else 1.0)
		result.append(center + Vector2(cos(angle), sin(angle)) * reach)
	return result


static func polygon(canvas: CanvasItem, center: Vector2, radius: float, sides: int, fill: Color, inner: float = 0.0, turn: float = 0.0) -> void:
	canvas.draw_colored_polygon(polygon_points(center, radius, sides, inner, turn), fill)


## A closed outline through `points`.
static func outline(canvas: CanvasItem, points: PackedVector2Array, tint: Color, width: float = 2.0) -> void:
	if points.size() < 2:
		return
	var closed := points.duplicate()
	closed.append(points[0])
	canvas.draw_polyline(closed, tint, width, true)


## A rounded rectangle's outline points, `segments` per corner.
static func rounded_rect_points(rect: Rect2, corner: float, segments: int = 6) -> PackedVector2Array:
	var result := PackedVector2Array()
	var r: float = minf(corner, minf(rect.size.x, rect.size.y) * 0.5)
	var centers: Array[Vector2] = [
		rect.position + Vector2(rect.size.x - r, r), rect.end - Vector2(r, r),
		rect.position + Vector2(r, rect.size.y - r), rect.position + Vector2(r, r),
	]
	for corner_index in range(4):
		var start: float = -PI / 2.0 + corner_index * PI / 2.0
		for s in range(segments + 1):
			var angle: float = start + PI / 2.0 * float(s) / segments
			result.append(centers[corner_index] + Vector2(cos(angle), sin(angle)) * r)
	return result


## A gentle bob for idle props and actors: -amplitude..amplitude over `period` seconds.
static func bob(time: float, period: float = 1.6, amplitude: float = 2.0, phase: float = 0.0) -> float:
	return sin((time / maxf(period, 0.001) + phase) * TAU) * amplitude

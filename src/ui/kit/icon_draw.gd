@tool
class_name IconDraw
extends Control
## Vector icons drawn in code (placeholders until AI art arrives).
## kinds: gold, gem, shard, power, heart, sword, lock, star, plus one per door kind.

@export var kind: String = "gold":
	set(v):
		kind = v
		queue_redraw()
@export var tint: Color = Color.TRANSPARENT:
	set(v):
		tint = v
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var r := s * 0.42
	var outline := Palette.OUTLINE
	match kind:
		"gold":
			draw_circle(c, r, outline)
			draw_circle(c, r * 0.82, _col(Palette.GOLD))
			draw_circle(c + Vector2(-r * 0.2, -r * 0.2), r * 0.25, Color(1, 1, 1, 0.6))
		"gem":
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.85, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.85, -r * 0.2)])
			_poly(pts, _col(Palette.PURPLE), outline, s * 0.06)
			draw_line(c + Vector2(-r * 0.85, -r * 0.2), c + Vector2(r * 0.85, -r * 0.2), Color(1, 1, 1, 0.5), s * 0.04)
		"shard":
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.45, 0), c + Vector2(0, r), c + Vector2(-r * 0.45, 0)])
			_poly(pts, _col(Color("#5fd0f0")), outline, s * 0.06)
		"power", "sword":
			var blade := PackedVector2Array([c + Vector2(-r * 0.15, r * 0.3), c + Vector2(-r * 0.15, -r), c + Vector2(r * 0.15, -r * 1.05), c + Vector2(r * 0.15, r * 0.3)])
			_poly(blade, _col(Color("#dfe8f0")), outline, s * 0.05)
			draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.3), Vector2(r, r * 0.18)), outline)
			draw_rect(Rect2(c + Vector2(-r * 0.12, r * 0.45), Vector2(r * 0.24, r * 0.5)), _col(Palette.ORANGE))
		"heart":
			draw_circle(c + Vector2(-r * 0.42, -r * 0.2), r * 0.48, _col(Palette.RED))
			draw_circle(c + Vector2(r * 0.42, -r * 0.2), r * 0.48, _col(Palette.RED))
			_poly(PackedVector2Array([c + Vector2(-r * 0.88, -r * 0.05), c + Vector2(r * 0.88, -r * 0.05), c + Vector2(0, r)]), _col(Palette.RED), _col(Palette.RED), 0)
		"lock":
			draw_arc(c + Vector2(0, -r * 0.15), r * 0.4, PI, TAU, 16, outline, s * 0.1)
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.15), Vector2(r * 1.2, r)), outline)
			draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.05), Vector2(r * 1.0, r * 0.8)), _col(Palette.GOLD_DARK))
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
			_poly(pts, _col(Palette.GOLD), outline, s * 0.05)
		_:
			var col: Color = Palette.DOOR.get(kind, Palette.ORANGE)
			draw_circle(c, r, outline)
			draw_circle(c, r * 0.84, _col(col))


func _col(fallback: Color) -> Color:
	return tint if tint != Color.TRANSPARENT else fallback


func _poly(pts: PackedVector2Array, fill: Color, line: Color, width: float) -> void:
	draw_colored_polygon(pts, fill)
	if width > 0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, line, width, true)

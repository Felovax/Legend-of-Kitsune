class_name CreatureDraw
extends Control
## Placeholder creatures drawn in code with soft shading (layered circles).
## If res://assets/sprites/<creature_id>.png exists, that texture is drawn instead,
## so AI-generated art drops in without code changes.

@export var creature_id: String = "kitsune":
	set(v):
		creature_id = v
		_texture = _load_sprite(v)
		queue_redraw()
@export var tails: int = 1:
	set(v):
		tails = clampi(v, 1, 9)
		queue_redraw()
@export var flip: bool = false:
	set(v):
		flip = v
		queue_redraw()
## 0..1, flashes the creature white (hit feedback).
var flash: float = 0.0:
	set(v):
		flash = v
		queue_redraw()

var _texture: Texture2D = null

const OUTLINE := Color("#4a2c16")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


static func _load_sprite(id: String) -> Texture2D:
	var path := "res://assets/sprites/%s.png" % id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	# Flat shadow ellipse at the feet.
	draw_set_transform(c + Vector2(0, s * 0.4), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, s * 0.3, Color(0, 0, 0, 0.2))
	draw_set_transform(c, 0.0, Vector2(-1 if flip else 1, 1))
	if _texture != null:
		draw_texture_rect(_texture, Rect2(Vector2(-s / 2, -s / 2), Vector2(s, s)), false)
	else:
		match creature_id:
			"kitsune":
				_kitsune(s)
			"moss_slime":
				_slime(s, Color("#7bd35a"), Color("#4fa83a"))
			"ember_imp":
				_imp(s)
			"stone_sentinel":
				_sentinel(s)
			"lantern_wisp":
				_wisp(s)
			"ruin_brute":
				_brute(s)
			"gatekeeper_golem":
				_golem(s)
			_:
				_slime(s, Color("#c0a0ff"), Color("#8a6ad0"))
	if flash > 0.0:
		draw_circle(Vector2.ZERO, s * 0.42, Color(1, 1, 1, flash * 0.6))
	draw_set_transform(Vector2.ZERO)


func _shaded_circle(center: Vector2, r: float, base: Color) -> void:
	draw_circle(center, r + 4, OUTLINE)
	draw_circle(center, r, base.darkened(0.12))
	draw_circle(center + Vector2(-r * 0.12, -r * 0.12), r * 0.86, base)
	draw_circle(center + Vector2(-r * 0.35, -r * 0.38), r * 0.22, Color(1, 1, 1, 0.45))


func _eyes(center: Vector2, spread: float, r: float) -> void:
	for side in [-1, 1]:
		var e := center + Vector2(side * spread, 0)
		draw_circle(e, r, Color("#2a1608"))
		draw_circle(e + Vector2(-r * 0.3, -r * 0.35), r * 0.38, Color.WHITE)


func _poly(pts: PackedVector2Array, fill: Color) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_colored_polygon(pts, fill)
	draw_polyline(closed, OUTLINE, 4.0, true)


func _kitsune(s: float) -> void:
	var fur := Color("#ff9a3c")
	var cream := Color("#fff1d8")
	# Fluffy curved tails fan out behind the body.
	for i in tails:
		var spread := 0.0 if tails == 1 else lerpf(-1.25, 0.75, float(i) / float(tails - 1))
		var dir := Vector2(0.6, -0.3).normalized().rotated(spread)
		var base := Vector2(s * 0.1, s * 0.22)
		var length := s * (0.44 if tails < 5 else 0.48)
		var tip := base + dir * length
		var bend := base + dir * length * 0.5 + dir.orthogonal() * length * 0.25
		_fluffy_tail(base, bend, tip, s * 0.11, fur if i % 2 == 0 else fur.lightened(0.08), cream)
	# Body.
	_shaded_circle(Vector2(0, s * 0.2), s * 0.2, fur)
	draw_circle(Vector2(-s * 0.02, s * 0.24), s * 0.12, cream)
	# Head with ears.
	for side in [-1, 1]:
		_poly(PackedVector2Array([Vector2(side * s * 0.1, -s * 0.28), Vector2(side * s * 0.3, -s * 0.48), Vector2(side * s * 0.3, -s * 0.18)]), fur)
		draw_colored_polygon(PackedVector2Array([Vector2(side * s * 0.15, -s * 0.28), Vector2(side * s * 0.27, -s * 0.41), Vector2(side * s * 0.27, -s * 0.24)]), Color("#ffc9a8"))
	_shaded_circle(Vector2(0, -s * 0.12), s * 0.25, fur)
	draw_circle(Vector2(0, -s * 0.02), s * 0.14, cream)
	_eyes(Vector2(0, -s * 0.13), s * 0.1, s * 0.045)
	draw_circle(Vector2(0, -s * 0.04), s * 0.025, Color("#2a1608"))
	for side in [-1, 1]:
		draw_circle(Vector2(side * s * 0.17, -s * 0.04), s * 0.035, Color(1, 0.45, 0.45, 0.5))
	# Satchel strap and lantern charm.
	draw_line(Vector2(-s * 0.15, s * 0.08), Vector2(s * 0.12, s * 0.33), Color("#8a5a2e"), s * 0.03)
	draw_circle(Vector2(s * 0.13, s * 0.34), s * 0.045 + 3, OUTLINE)
	draw_circle(Vector2(s * 0.13, s * 0.34), s * 0.045, Color("#ffd65a"))


## A tail made of overlapping circles along a curve: thick in the middle,
## with a cream tip.
func _fluffy_tail(a: Vector2, ctrl: Vector2, b: Vector2, width: float, fur: Color, tip: Color) -> void:
	var steps := 14
	for pass_index in 2:
		for k in steps + 1:
			var t := float(k) / steps
			var p := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
			var r := width * (0.55 + 0.6 * sin(t * PI * 0.85))
			if pass_index == 0:
				draw_circle(p, r + 4, OUTLINE)
			else:
				draw_circle(p, r, tip if t > 0.78 else fur)


func _slime(s: float, base: Color, dark: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := PI + PI * i / 23.0
		pts.append(Vector2(cos(a) * s * 0.34, sin(a) * s * 0.36 + s * 0.2))
	pts.append(Vector2(s * 0.34, s * 0.32))
	pts.append(Vector2(-s * 0.34, s * 0.32))
	_poly(pts, base)
	draw_circle(Vector2(-s * 0.12, -s * 0.02), s * 0.08, Color(1, 1, 1, 0.4))
	draw_line(Vector2(-s * 0.34, s * 0.3), Vector2(s * 0.34, s * 0.3), dark, 6)
	_eyes(Vector2(0, s * 0.1), s * 0.1, s * 0.05)
	draw_circle(Vector2(s * 0.05, -s * 0.17), s * 0.05, Color("#ff7aa8"))


func _imp(s: float) -> void:
	var red := Color("#ff6b3d")
	_poly(PackedVector2Array([Vector2(-s * 0.3, s * 0.05), Vector2(-s * 0.45, -s * 0.2), Vector2(-s * 0.2, -s * 0.05)]), Color("#c43d2a"))
	_poly(PackedVector2Array([Vector2(s * 0.3, s * 0.05), Vector2(s * 0.45, -s * 0.2), Vector2(s * 0.2, -s * 0.05)]), Color("#c43d2a"))
	_shaded_circle(Vector2(0, s * 0.05), s * 0.24, red)
	for side in [-1, 1]:
		_poly(PackedVector2Array([Vector2(side * s * 0.08, -s * 0.15), Vector2(side * s * 0.16, -s * 0.34), Vector2(side * s * 0.2, -s * 0.12)]), Color("#ffd65a"))
	_eyes(Vector2(0, s * 0.02), s * 0.09, s * 0.045)
	draw_arc(Vector2(0, s * 0.12), s * 0.07, 0.2, PI - 0.2, 10, Color("#2a1608"), 5)
	_poly(PackedVector2Array([Vector2(-s * 0.06, s * 0.3), Vector2(0, s * 0.45), Vector2(s * 0.06, s * 0.3)]), Color("#ffb03d"))


func _sentinel(s: float) -> void:
	var stone := Color("#a8b4c0")
	draw_rect(Rect2(Vector2(-s * 0.3, -s * 0.28), Vector2(s * 0.6, s * 0.62)), OUTLINE)
	draw_rect(Rect2(Vector2(-s * 0.27, -s * 0.25), Vector2(s * 0.54, s * 0.56)), stone)
	draw_rect(Rect2(Vector2(-s * 0.27, -s * 0.25), Vector2(s * 0.54, s * 0.1)), Color("#7bd35a"))
	draw_line(Vector2(-s * 0.27, s * 0.08), Vector2(s * 0.27, s * 0.08), Color("#8a96a2"), 4)
	for side in [-1, 1]:
		draw_circle(Vector2(side * s * 0.1, -s * 0.03), s * 0.05, Color("#5fd0f0"))
	draw_rect(Rect2(Vector2(s * 0.2, -s * 0.05), Vector2(s * 0.18, s * 0.3)), OUTLINE)
	draw_rect(Rect2(Vector2(s * 0.22, -s * 0.03), Vector2(s * 0.14, s * 0.26)), Color("#8a96a2"))


func _wisp(s: float) -> void:
	draw_circle(Vector2(0, -s * 0.02), s * 0.36, Color(1, 0.86, 0.4, 0.25))
	_poly(PackedVector2Array([Vector2(-s * 0.1, s * 0.15), Vector2(0, s * 0.42), Vector2(s * 0.1, s * 0.15)]), Color("#fff0b0"))
	draw_rect(Rect2(Vector2(-s * 0.22, -s * 0.24), Vector2(s * 0.44, s * 0.42)), OUTLINE)
	draw_rect(Rect2(Vector2(-s * 0.19, -s * 0.21), Vector2(s * 0.38, s * 0.36)), Color("#ffd65a"))
	for y in [-0.12, 0.0, 0.1]:
		draw_line(Vector2(-s * 0.19, s * y), Vector2(s * 0.19, s * y), Color("#e0a020"), 3)
	draw_rect(Rect2(Vector2(-s * 0.12, -s * 0.3), Vector2(s * 0.24, s * 0.07)), Color("#c43d2a"))
	_eyes(Vector2(0, -s * 0.04), s * 0.08, s * 0.04)


func _brute(s: float) -> void:
	var skin := Color("#9a7a5a")
	_shaded_circle(Vector2(0, s * 0.12), s * 0.3, skin)
	_shaded_circle(Vector2(0, -s * 0.2), s * 0.17, skin.lightened(0.1))
	draw_line(Vector2(-s * 0.3, -s * 0.05), Vector2(-s * 0.2, s * 0.2), Color("#5fa83a"), 8)
	draw_line(Vector2(s * 0.1, -s * 0.3), Vector2(s * 0.3, s * 0.1), Color("#5fa83a"), 8)
	_eyes(Vector2(0, -s * 0.2), s * 0.07, s * 0.035)
	for side in [-1, 1]:
		draw_line(Vector2(side * s * 0.11, -s * 0.28), Vector2(side * s * 0.03, -s * 0.25), Color("#2a1608"), 5)
	draw_rect(Rect2(Vector2(s * 0.28, -s * 0.35), Vector2(s * 0.12, s * 0.6)), OUTLINE)
	draw_rect(Rect2(Vector2(s * 0.3, -s * 0.33), Vector2(s * 0.08, s * 0.56)), Color("#c8d2dc"))


func _golem(s: float) -> void:
	var stone := Color("#8a96a2")
	for side in [-1, 1]:
		_shaded_circle(Vector2(side * s * 0.33, s * 0.12), s * 0.11, stone)
	_shaded_circle(Vector2(0, s * 0.08), s * 0.3, stone)
	draw_line(Vector2(-s * 0.15, -s * 0.05), Vector2(s * 0.05, s * 0.2), Color("#5fd0f0"), 5)
	draw_line(Vector2(s * 0.12, s * 0.0), Vector2(s * 0.2, s * 0.25), Color("#5fd0f0"), 5)
	for side in [-1, 1]:
		_poly(PackedVector2Array([Vector2(side * s * 0.22, -s * 0.2), Vector2(side * s * 0.3, -s * 0.46), Vector2(side * s * 0.36, -s * 0.18)]), Color("#9ff3fb"))
	_eyes(Vector2(0, -s * 0.02), s * 0.1, s * 0.05)
	for side in [-1, 1]:
		draw_line(Vector2(side * s * 0.15, -s * 0.1), Vector2(side * s * 0.04, -s * 0.06), Color("#2a1608"), 6)

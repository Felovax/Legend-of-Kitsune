class_name Backdrop
extends Control
## Bright painted background drawn in code: sky gradient, sun, clouds, hills
## and a shrine gate. Replaced by AI-generated art later.

@export var variant: String = "camp":
	set(v):
		variant = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if variant != "camp":
		_draw_ruins()
		return
	var w := size.x
	var h := size.y
	var top := Color("#7cc8ff")
	var bottom := Color("#d8f1ff")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([top, top, bottom, bottom]))
	draw_circle(Vector2(w * 0.8, h * 0.12), w * 0.09, Color("#fff3b0"))
	draw_circle(Vector2(w * 0.8, h * 0.12), w * 0.065, Color("#ffe066"))
	for cloud in [[0.2, 0.1, 1.0], [0.55, 0.18, 0.8], [0.9, 0.28, 0.7]]:
		_cloud(Vector2(w * cloud[0], h * cloud[1]), w * 0.08 * cloud[2])
	_hill(h * 0.47, Color("#8fdc6a"), w, h, 0.0)
	_gate(Vector2(w * 0.8, h * 0.5), w * 0.15)
	_hill(h * 0.55, Color("#6cc84a"), w, h, 1.7)
	_hill(h * 0.7, Color("#57b83c"), w, h, 3.1)


## Dusky lantern-lit shrine ruins for expeditions.
func _draw_ruins() -> void:
	var w := size.x
	var h := size.y
	var top := Color("#2b2350")
	var bottom := Color("#6a4a7a")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.7), Vector2(0, h * 0.7)]),
		PackedColorArray([top, top, bottom, bottom]))
	for i in 18:
		var star := Vector2(fmod(i * 197.0, w), fmod(i * 131.0, h * 0.35))
		draw_circle(star, 2.0 + (i % 3), Color(1, 1, 0.85, 0.7))
	draw_circle(Vector2(w * 0.18, h * 0.1), w * 0.06, Color("#fff6d8"))
	draw_circle(Vector2(w * 0.2, h * 0.095), w * 0.05, top.lerp(bottom, 0.15))
	# Distant pillars.
	var stone_far := Color("#4a3d66")
	for x in [0.05, 0.3, 0.62, 0.9]:
		draw_rect(Rect2(Vector2(w * x, h * 0.28), Vector2(w * 0.07, h * 0.45)), stone_far)
		draw_rect(Rect2(Vector2(w * x - w * 0.015, h * 0.27), Vector2(w * 0.1, h * 0.025)), stone_far.darkened(0.2))
	# Floor.
	draw_rect(Rect2(Vector2(0, h * 0.7), Vector2(w, h * 0.3)), Color("#5a4a5e"))
	for row in 6:
		var y := h * 0.7 + row * h * 0.05
		draw_line(Vector2(0, y), Vector2(w, y), Color("#4a3a4e"), 3)
		for col in 8:
			var x := fmod(col * w / 7.0 + (row % 2) * w / 14.0, w)
			draw_line(Vector2(x, y), Vector2(x, y + h * 0.05), Color("#4a3a4e"), 3)
	# Hanging lanterns with glow.
	for lx in [0.15, 0.5, 0.85]:
		var lp := Vector2(w * lx, h * 0.22)
		draw_line(Vector2(lp.x, 0), lp, Color("#2a1d33"), 3)
		draw_circle(lp + Vector2(0, 30), 80, Color(1, 0.7, 0.3, 0.12))
		draw_rect(Rect2(lp + Vector2(-22, 0), Vector2(44, 60)), Color("#2a1d33"))
		draw_rect(Rect2(lp + Vector2(-18, 4), Vector2(36, 52)), Color("#ffb347"))


func _cloud(c: Vector2, r: float) -> void:
	var col := Color(1, 1, 1, 0.92)
	draw_circle(c, r, col)
	draw_circle(c + Vector2(r * 0.9, r * 0.2), r * 0.75, col)
	draw_circle(c + Vector2(-r * 0.9, r * 0.25), r * 0.7, col)
	draw_rect(Rect2(c + Vector2(-r * 1.5, r * 0.2), Vector2(r * 3.0, r * 0.75)), col)


func _hill(y: float, col: Color, w: float, h: float, phase: float) -> void:
	var pts := PackedVector2Array([Vector2(0, h)])
	for i in 25:
		var x := w * i / 24.0
		pts.append(Vector2(x, y + sin(i * 0.5 + phase) * h * 0.02))
	pts.append(Vector2(w, h))
	draw_colored_polygon(pts, col)


func _gate(base: Vector2, width: float) -> void:
	var red := Color("#e0503c")
	var dark := Color("#5a3a1e")
	var pillar := width * 0.09
	var height := width * 0.9
	for x in [base.x - width * 0.35, base.x + width * 0.35 - pillar]:
		draw_rect(Rect2(Vector2(x, base.y - height), Vector2(pillar, height)), red)
	draw_rect(Rect2(Vector2(base.x - width * 0.55, base.y - height - width * 0.1), Vector2(width * 1.1, width * 0.1)), dark)
	draw_rect(Rect2(Vector2(base.x - width * 0.5, base.y - height), Vector2(width, width * 0.08)), red)
	draw_rect(Rect2(Vector2(base.x - width * 0.42, base.y - height * 0.72), Vector2(width * 0.84, width * 0.06)), red)

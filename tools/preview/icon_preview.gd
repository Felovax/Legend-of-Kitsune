extends Control
## Renders the placeholder app icon: the kitsune on a warm two-tone badge.
## Render it in a square window; everything is placed relative to the window.

func _ready() -> void:
	var vs := get_viewport_rect().size
	var side := minf(vs.x, vs.y)
	var origin := (vs - Vector2(side, side)) / 2.0
	var bg := ColorRect.new()
	bg.color = Color("#ff9b3d")
	bg.position = origin
	bg.size = Vector2(side, side)
	add_child(bg)
	var ground := ColorRect.new()
	ground.color = Color("#5fd0f0")
	ground.position = origin + Vector2(0, side * 0.68)
	ground.size = Vector2(side, side * 0.32)
	add_child(ground)
	var kitsune := CreatureDraw.new()
	kitsune.creature_id = "kitsune"
	kitsune.tails = 3
	kitsune.size = Vector2(side, side) * 1.08
	kitsune.position = origin + Vector2(-side * 0.1, side * 0.0)
	add_child(kitsune)

extends Control
## Preview of all placeholder creatures (for screenshots).

func _ready() -> void:
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(40, 200)
	add_child(grid)
	var ids := ["kitsune", "kitsune", "kitsune", "moss_slime", "ember_imp", "stone_sentinel", "lantern_wisp", "ruin_brute", "gatekeeper_golem"]
	for i in ids.size():
		var c := CreatureDraw.new()
		c.creature_id = ids[i]
		c.tails = [1, 3, 9][i] if i < 3 else 1
		c.custom_minimum_size = Vector2(320, 320)
		grid.add_child(c)

extends Control
## Placeholder entry scene. Replaced by the real Camp screen in milestone M3.

func _ready() -> void:
	var label := Label.new()
	label.text = "Legend of Kitsune\nprototype %s" % ProjectSettings.get_setting("application/config/version")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 64)
	add_child(label)

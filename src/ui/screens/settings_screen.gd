class_name SettingsScreen
extends Control
## Audio, comfort and accessibility options. Saved to user://settings.cfg.

const TEXT_SIZES := [["Normal", 1.0], ["Large", 1.15], ["Huge", 1.3]]


func _ready() -> void:
	var list := UiKit.vbox([], 16)
	list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(list)
	list.add_child(UiKit.label(tr("Settings"), "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var toggles := UiKit.vbox([], 6)
	for entry: Array in [["music", "Music"], ["sfx", "Sound effects"], ["reduced_effects", "Reduced effects"], ["screen_shake", "Screen shake"]]:
		var key: String = entry[0]
		var check := CheckButton.new()
		check.text = tr(entry[1])
		check.button_pressed = bool(Game.settings.get(key, false))
		check.custom_minimum_size.y = UiKit.TOUCH_HEIGHT
		check.add_theme_font_size_override("font_size", 34)
		check.toggled.connect(func(on: bool) -> void: Game.set_setting(key, on))
		toggles.add_child(check)
	list.add_child(UiKit.panel(toggles))

	var sizes := UiKit.hbox([], 10)
	for entry: Array in TEXT_SIZES:
		var value: float = entry[1]
		var selected := is_equal_approx(float(Game.settings.get("text_scale", 1.0)), value)
		var b := UiKit.button(tr(entry[0]), func() -> void: Game.set_setting("text_scale", value), "GreenButton" if selected else "GhostButton")
		UiKit.expand(b)
		sizes.add_child(b)
	list.add_child(UiKit.panel(UiKit.vbox([UiKit.label(tr("Text size"), "HeadingLabel"), sizes], 8)))

	var about := UiKit.vbox([
		UiKit.label(tr("Legend of Kitsune %s") % ProjectSettings.get_setting("application/config/version"), "HeadingLabel"),
		UiKit.wrap_label(tr("Fonts: Lilita One and Nunito (SIL Open Font License 1.1)."), "SmallLabel"),
	], 4)
	list.add_child(UiKit.panel(about))

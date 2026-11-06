class_name SettingsScreen
extends Control
## Audio, comfort and accessibility options. Saved to user://settings.cfg.

const TEXT_SIZES := [["Normal", 1.0], ["Large", 1.15], ["Huge", 1.3]]


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := UiKit.vbox([], 16)
	UiKit.expand(list)
	scroll.add_child(list)
	list.add_child(UiKit.label(tr("Settings"), "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var toggles := UiKit.vbox([], 6)
	for entry: Array in [["music", "Music"], ["sfx", "Sound effects"], ["reduced_effects", "Reduced effects"], ["screen_shake", "Screen shake"]]:
		var key: String = entry[0]
		toggles.add_child(_check(tr(entry[1]), bool(Game.settings.get(key, false)), func(on: bool) -> void: Game.set_setting(key, on)))
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
	if Game.debug_enabled():
		list.add_child(_debug_panel())


## Test tools, only in debug builds (the CI test APK), never in store builds.
func _debug_panel() -> Control:
	var box := UiKit.vbox([UiKit.label(tr("Test tools (debug build only)"), "HeadingLabel")], 8)
	var row1 := UiKit.hbox([
		UiKit.expand(UiKit.button("+10K " + tr("gold"), func() -> void: Game.debug_add(Wallet.GOLD, 10000), "GhostButton")),
		UiKit.expand(UiKit.button("+1K " + tr("gems"), func() -> void: Game.debug_add(Wallet.GEMS, 1000), "GhostButton")),
		UiKit.expand(UiKit.button("+500 " + tr("shards"), func() -> void: Game.debug_add(Wallet.SHARDS, 500), "GhostButton")),
	], 8)
	box.add_child(row1)
	var reset := UiKit.button(tr("Reset save"), Callable(), "RedButton")
	reset.pressed.connect(func() -> void:
		if reset.text != tr("Tap again to reset"):
			reset.text = tr("Tap again to reset")
		else:
			Game.debug_reset()
			reset.text = tr("Reset save"))
	box.add_child(UiKit.hbox([UiKit.expand(UiKit.button(tr("Unlock next chapter"), func() -> void: Game.debug_unlock_chapter(), "GhostButton")), reset], 8))
	box.add_child(_check(tr("Test store: purchases fail"), Game.store.simulate_failure, func(on: bool) -> void: Game.store.simulate_failure = on))
	var log_stats := Game.analytics.summary()
	var stats := tr("Play log (on this phone only): %d sessions, %d runs, %d wins, %d level-ups, %d purchases") % [log_stats["sessions"], log_stats["runs"], log_stats["wins"], log_stats["level_ups"], log_stats["purchases"]]
	box.add_child(UiKit.wrap_label(stats, "SmallLabel"))
	return UiKit.panel(box)


func _check(text: String, on: bool, on_toggle: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = on
	check.custom_minimum_size.y = UiKit.TOUCH_HEIGHT
	check.add_theme_font_size_override("font_size", 34)
	check.toggled.connect(on_toggle)
	return check

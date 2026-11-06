class_name App
extends Control
## Root of the game UI: backdrop, top currency bar, the current screen and the
## bottom tabs. The Expedition screen takes over the whole view.

const TABS := [["shop", "Shop"], ["hero", "Hero"], ["camp", "Delve"], ["codex", "Codex"]]

var _top_bar: HBoxContainer
var _tab_bar: HBoxContainer
var _holder: Control
var _toast_layer: VBoxContainer
var _tab_buttons: Dictionary = {}
var _values: Dictionary = {}
var _current: Control = null
var _current_tab: String = ""
var _backdrop: Backdrop


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not Game.booted:
		Game.boot()
	theme = UiTheme.build(float(Game.settings.get("text_scale", 1.0)))
	_build()
	Game.profile_changed.connect(_refresh_bar)
	Game.settings_changed.connect(func() -> void: theme = UiTheme.build(float(Game.settings.get("text_scale", 1.0))))
	Game.expedition_started.connect(_open_expedition)
	_refresh_bar()
	show_tab("camp")
	if Game.expedition != null:
		_open_expedition(Game.expedition)


func _build() -> void:
	_backdrop = Backdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets := _safe_insets()
	safe.add_theme_constant_override("margin_left", 24)
	safe.add_theme_constant_override("margin_right", 24)
	safe.add_theme_constant_override("margin_top", 20 + insets.x)
	safe.add_theme_constant_override("margin_bottom", 20 + insets.y)
	add_child(safe)

	var column := UiKit.vbox([], 18)
	safe.add_child(column)
	_top_bar = UiKit.hbox([], 12)
	for kind in ["gold", "gem", "shard"]:
		var value := UiKit.label("0", "ValueLabel")
		_values[kind] = value
		_top_bar.add_child(UiKit.panel(UiKit.hbox([UiKit.icon(kind, 44), value], 8), "DarkPanel"))
	_top_bar.add_child(UiKit.spacer())
	_top_bar.add_child(UiKit.button(tr("Settings"), func() -> void: show_tab("settings"), "GhostButton"))
	column.add_child(_top_bar)

	_holder = Control.new()
	UiKit.expand(_holder, true, true)
	column.add_child(_holder)

	_tab_bar = UiKit.hbox([], 12)
	for tab: Array in TABS:
		var id: String = tab[0]
		var b := UiKit.button(tr(tab[1]), func() -> void: show_tab(id), "GhostButton")
		UiKit.expand(b)
		if id == "camp":
			b.custom_minimum_size.y = 120
		_tab_buttons[id] = b
		_tab_bar.add_child(b)
	column.add_child(_tab_bar)

	_toast_layer = UiKit.vbox([], 10)
	_toast_layer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_layer.position.y = 180
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_layer)


func show_tab(id: String) -> void:
	if _current != null:
		_current.queue_free()
	_current_tab = id
	Audio.play_music("camp")
	match id:
		"shop":
			_current = ShopScreen.new()
		"hero":
			_current = HeroScreen.new()
		"codex":
			_current = CodexScreen.new()
		"settings":
			_current = SettingsScreen.new()
		_:
			_current_tab = "camp"
			var camp := CampScreen.new()
			camp.delve_requested.connect(_on_delve)
			_current = camp
	_current.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(_current)
	_top_bar.visible = true
	_tab_bar.visible = true
	_backdrop.variant = "camp"
	for tab_id: String in _tab_buttons:
		(_tab_buttons[tab_id] as Button).theme_type_variation = "GreenButton" if tab_id == _current_tab else "GhostButton"


func toast(text: String) -> void:
	var label := UiKit.label(text, "ValueLabel", HORIZONTAL_ALIGNMENT_CENTER)
	var p := UiKit.panel(label, "DarkPanel")
	_toast_layer.add_child(p)
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(p, "modulate:a", 0.0, 0.4)
	tween.tween_callback(p.queue_free)


func _on_delve(chapter: int) -> void:
	if Game.start_expedition(chapter) == null:
		toast(tr("That chapter is locked"))


func _open_expedition(exp: Expedition) -> void:
	if _current != null:
		_current.queue_free()
	_top_bar.visible = false
	_tab_bar.visible = false
	_backdrop.variant = "ruins"
	Audio.play_music("delve")
	var screen := ExpeditionScreen.new()
	screen.setup(exp)
	screen.closed.connect(func() -> void: show_tab("camp"))
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_current = screen
	_current_tab = "expedition"
	_holder.add_child(screen)


func _refresh_bar() -> void:
	if Game.profile == null:
		return
	var w := Game.profile.wallet
	(_values["gold"] as Label).text = UiKit.format_number(w.gold)
	(_values["gem"] as Label).text = UiKit.format_number(w.balance(Wallet.GEMS))
	(_values["shard"] as Label).text = UiKit.format_number(w.shards)


## Safe-area insets (top, bottom) in viewport pixels, for notches and home bars.
func _safe_insets() -> Vector2i:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0 or safe.size.y <= 0:
		return Vector2i.ZERO
	var scale := get_viewport_rect().size.y / float(win.y)
	var top := maxi(0, safe.position.y)
	var bottom := maxi(0, win.y - safe.end.y)
	return Vector2i(int(top * scale), int(bottom * scale))

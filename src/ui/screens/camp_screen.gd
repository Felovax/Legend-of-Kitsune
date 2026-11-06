class_name CampScreen
extends Control
## Home screen: the kitsune, chapter picker with Recommended vs your Power,
## offline income and the big Delve button.

signal delve_requested(chapter: int)

var _chapter: int = 1
var _chapter_title: Label
var _chapter_name: Label
var _power_label: Label
var _recommended_label: Label
var _prev: Button
var _next: Button
var _kitsune: CreatureDraw
var _echo_label: Label
var _offline_panel: Control


func _ready() -> void:
	var p := Game.profile
	_chapter = clampi(p.best_chapter + 1, 1, Game.db.max_chapter())
	_build()
	_refresh()
	Game.profile_changed.connect(_refresh)


func _build() -> void:
	var column := UiKit.vbox([], 20)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	column.add_child(UiKit.label(tr("Legend of Kitsune"), "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))

	_offline_panel = _make_offline_panel()
	column.add_child(_offline_panel)

	var stage := CenterContainer.new()
	UiKit.expand(stage, true, true)
	_kitsune = CreatureDraw.new()
	_kitsune.creature_id = "kitsune"
	_kitsune.custom_minimum_size = Vector2(520, 520)
	stage.add_child(_kitsune)
	column.add_child(stage)

	_echo_label = UiKit.label("", "SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_echo_label)

	_prev = UiKit.button("<", func() -> void: _step(-1), "GhostButton", 110)
	_next = UiKit.button(">", func() -> void: _step(1), "GhostButton", 110)
	_chapter_title = UiKit.label("", "HeadingLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_chapter_name = UiKit.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
	_recommended_label = UiKit.label("", "SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_power_label = UiKit.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
	var info := UiKit.vbox([_chapter_title, _chapter_name, _recommended_label, _power_label], 4)
	UiKit.expand(info)
	column.add_child(UiKit.panel(UiKit.hbox([_prev, info, _next], 12)))

	if int(Game.profile.counters.get("runs", 0)) == 0:
		column.add_child(UiKit.panel(UiKit.wrap_label(tr("Tap DELVE to begin your first expedition!"), "", HORIZONTAL_ALIGNMENT_CENTER), "CardPanel"))
	var delve := UiKit.button(tr("DELVE"), func() -> void: delve_requested.emit(_chapter), "GreenButton")
	delve.custom_minimum_size = Vector2(0, 150)
	delve.add_theme_font_size_override("font_size", 64)
	column.add_child(delve)


func _make_offline_panel() -> Control:
	var gold := int(Game.last_offline.get("gold", 0))
	if gold <= 0:
		return Control.new()
	var minutes := int(Game.last_offline.get("minutes", 0))
	var text := tr("While you were away (%dh %dm)") % [minutes / 60, minutes % 60]
	var row := UiKit.hbox([UiKit.icon("gold", 56), UiKit.vbox([UiKit.label(text, "SmallLabel"),
		UiKit.label("+" + UiKit.format_number(gold), "HeadingLabel")], 0)], 12)
	var ok := UiKit.button(tr("Nice!"), Callable(), "", 180)
	row.add_child(UiKit.spacer())
	row.add_child(ok)
	var panel := UiKit.panel(row, "CardPanel")
	ok.pressed.connect(func() -> void:
		Game.last_offline = {}
		panel.queue_free())
	return panel


func _step(delta: int) -> void:
	_chapter = clampi(_chapter + delta, 1, mini(Game.profile.best_chapter + 1, Game.db.max_chapter()))
	_refresh()


func _refresh() -> void:
	var p := Game.profile
	var def := Game.db.chapter_def(_chapter)
	_chapter_title.text = tr("Chapter %d") % _chapter
	_chapter_name.text = tr(def.get("name_key", ""))
	var power := Game.prog.power(p)
	var rec := Game.prog.recommended_power(_chapter)
	_recommended_label.text = tr("Recommended Power %s") % UiKit.format_number(rec)
	_power_label.text = tr("Your Power %s") % UiKit.format_number(power)
	_power_label.add_theme_color_override("font_color", Palette.GREEN_DARK if power >= rec else Palette.RED)
	_prev.disabled = _chapter <= 1
	_next.disabled = _chapter >= mini(p.best_chapter + 1, Game.db.max_chapter())
	_kitsune.tails = 1 + p.codex_resonances.size()
	_echo_label.text = (tr("Echo Keepsake: %s") % tr(Game.db.relics[p.echo_relic]["name_key"])) if p.echo_relic != "" else ""

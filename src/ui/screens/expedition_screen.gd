class_name ExpeditionScreen
extends Control
## Runs one Expedition: room track, hero status, then by phase: door choice,
## battle replay, relic draft, event, and the results with the Echo choice.

signal closed

const DOOR_TEXT := {
	"fight": ["Fight", "Battle monsters for gold and a relic."],
	"elite": ["Elite", "A tough foe. More gold, maybe gear."],
	"boss": ["Boss", "The guardian of this chapter."],
	"shrine": ["Shrine", "Rest and heal 30% HP."],
	"treasure": ["Treasure", "A free relic, no fight."],
	"event": ["Mystery", "Something strange awaits..."],
}

const DOOR_ICONS := {"fight": "sword", "elite": "sword", "boss": "star", "shrine": "heart", "treasure": "gem", "event": "star"}

var expedition: Expedition
var _result: RunResult = null
var _header_title: Label
var _track: HBoxContainer
var _hp_bar: ProgressBar
var _hp_label: Label
var _tails_label: Label
var _relic_row: HFlowContainer
var _body: Control
var _battle: BattleView = null


func setup(exp: Expedition) -> void:
	expedition = exp


func _ready() -> void:
	var column := UiKit.vbox([], 14)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	_header_title = UiKit.label("", "HeadingLabel")
	_header_title.add_theme_color_override("font_color", Color.WHITE)
	_header_title.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_header_title.add_theme_constant_override("outline_size", 10)
	UiKit.expand(_header_title)
	var retreat := UiKit.button(tr("Retreat"), _on_retreat, "GhostButton")
	column.add_child(UiKit.hbox([_header_title, retreat]))

	_track = UiKit.hbox([], 8)
	_track.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_track)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0, 36)
	UiKit.expand(_hp_bar)
	_hp_label = UiKit.label("", "ValueLabel")
	_tails_label = UiKit.label("", "ValueLabel")
	column.add_child(UiKit.hbox([UiKit.icon("heart", 44), _hp_bar, _hp_label, UiKit.icon("star", 44), _tails_label], 10))

	_relic_row = HFlowContainer.new()
	_relic_row.add_theme_constant_override("h_separation", 8)
	_relic_row.add_theme_constant_override("v_separation", 8)
	column.add_child(_relic_row)

	_body = Control.new()
	UiKit.expand(_body, true, true)
	column.add_child(_body)
	_refresh()


func _refresh() -> void:
	_refresh_status()
	for c in _body.get_children():
		c.queue_free()
	_battle = null
	match expedition.phase:
		Expedition.Phase.DOOR:
			_show_doors()
		Expedition.Phase.BATTLE:
			_start_battle()
		Expedition.Phase.DRAFT:
			_show_draft()
		Expedition.Phase.EVENT:
			_show_event()
		Expedition.Phase.FINISHED:
			_show_results()


func _refresh_status() -> void:
	var def := expedition.chapter_def
	_header_title.text = tr("Chapter %d: %s") % [expedition.chapter, tr(def.get("name_key", ""))]
	for c in _track.get_children():
		c.queue_free()
	for r in range(1, expedition.rooms + 1):
		var kind := "fight"
		if r == int(expedition.run_cfg["elite_room"]):
			kind = "elite"
		elif r == expedition.rooms:
			kind = "boss"
		var dot := UiKit.icon(kind, 64 if r == expedition.room else 44)
		if r < expedition.room or (expedition.is_finished() and expedition.result().won):
			dot.tint = Palette.GREEN
		elif r > expedition.room:
			dot.modulate = Color(1, 1, 1, 0.55)
		_track.add_child(dot)
	_hp_bar.max_value = expedition.hero_max_hp
	_hp_bar.value = expedition.hero_hp
	_hp_label.text = "%s/%s" % [UiKit.format_number(expedition.hero_hp), UiKit.format_number(expedition.hero_max_hp)]
	_tails_label.text = str(1 + expedition.tails())
	for c in _relic_row.get_children():
		c.queue_free()
	for relic_id: String in expedition.relics:
		var def_relic: Dictionary = expedition.db.relics[relic_id]
		var chip := UiKit.label("%s %d" % [tr(def_relic["name_key"]), int(expedition.relics[relic_id])], "SmallLabel")
		chip.add_theme_color_override("font_color", Color.WHITE)
		var style := UiTheme.box(Palette.element_of(def_relic["tags"]).darkened(0.25), Palette.OUTLINE, 16, 3, 2)
		var panel := UiKit.panel(chip)
		panel.add_theme_stylebox_override("panel", style)
		_relic_row.add_child(panel)


# --- doors ---------------------------------------------------------------------------

func _show_doors() -> void:
	var column := UiKit.vbox([UiKit.label(tr("Choose your path"), "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)], 24)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in expedition.doors.size():
		var kind := expedition.doors[i]
		var text: Array = DOOR_TEXT.get(kind, [kind, ""])
		var b := UiKit.button("", func() -> void: _choose_door(i), "GhostButton")
		b.custom_minimum_size = Vector2(0, 220)
		var style := UiTheme.box(Palette.DOOR.get(kind, Palette.ORANGE), Palette.OUTLINE, 30, 6, 10)
		b.add_theme_stylebox_override("normal", style)
		b.add_theme_stylebox_override("hover", style)
		var info := UiKit.vbox([UiKit.label(tr(text[0]), "TitleLabel"), UiKit.wrap_label(tr(text[1]), "ValueLabel")], 0)
		UiKit.expand(info)
		var row := UiKit.hbox([UiKit.icon(DOOR_ICONS.get(kind, "star"), 110), info], 24)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 30
		row.offset_right = -30
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for child in row.get_children():
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		column.add_child(b)
	_body.add_child(column)


func _choose_door(index: int) -> void:
	expedition.choose_door(index)
	_refresh()


# --- battle ----------------------------------------------------------------------------

func _start_battle() -> void:
	var battle := expedition.fight()
	_battle = BattleView.new()
	_battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle.speed = float(Game.settings.get("battle_speed", 2))
	_battle.reduced_effects = bool(Game.settings.get("reduced_effects", false))
	_battle.screen_shake = bool(Game.settings.get("screen_shake", true))
	for res_id: String in expedition.db.resonances:
		_battle.resonance_names[res_id] = tr(expedition.db.resonances[res_id]["name_key"])
		_battle.resonance_tags[res_id] = expedition.db.resonances[res_id]["requires_tags"]
	_body.add_child(_battle)
	_battle.play(battle, expedition.factory.cfg.tps)
	_battle.finished.connect(_refresh, CONNECT_ONE_SHOT)
	var speed_button := UiKit.button(_speed_text(), Callable(), "GhostButton", 160)
	speed_button.pressed.connect(func() -> void:
		var next := 1 if int(Game.settings.get("battle_speed", 2)) >= 2 else 2
		Game.set_setting("battle_speed", next)
		if _battle != null:
			_battle.speed = next
		speed_button.text = _speed_text())
	var skip := UiKit.button(tr("Skip"), func() -> void:
		if _battle != null:
			_battle.skip(), "GhostButton", 180)
	var controls := UiKit.hbox([UiKit.spacer(), speed_button, skip], 12)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_top = -110
	_body.add_child(controls)


func _speed_text() -> String:
	return "%dx" % int(Game.settings.get("battle_speed", 2))


# --- draft ----------------------------------------------------------------------------------

func _show_draft() -> void:
	var column := UiKit.vbox([UiKit.label(tr("Choose a relic"), "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)], 18)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in expedition.draft_offer.size():
		column.add_child(_relic_card(expedition.draft_offer[i], i))
	var reroll := UiKit.button(tr("Reroll (%d)") % expedition.rerolls_left, func() -> void:
		if expedition.reroll() == Progression.OK:
			_refresh(), "BlueButton")
	reroll.disabled = expedition.rerolls_left <= 0
	UiKit.expand(reroll)
	var skip := UiKit.button(tr("Skip"), func() -> void:
		expedition.skip_draft()
		_refresh(), "GhostButton")
	column.add_child(UiKit.hbox([reroll, skip], 12))
	_body.add_child(column)


func _relic_card(offer: Dictionary, index: int) -> Control:
	var relic_id: String = offer["relic"]
	var def: Dictionary = expedition.db.relics[relic_id]
	var color := Palette.element_of(def["tags"])
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 230)
	var style := UiTheme.box(Palette.WHITE, Palette.RARITY.get(def["rarity"], Palette.OUTLINE), 26, 8, 8)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", style)
	b.pressed.connect(func() -> void:
		UiKit.sfx("pick")
		expedition.pick_relic(index)
		_refresh())
	var title := UiKit.label(tr(def["name_key"]), "HeadingLabel")
	var level := UiKit.label(tr("NEW") if not offer["upgrade"] else tr("Level %d") % int(offer["level"]), "ValueLabel")
	level.add_theme_color_override("font_color", color)
	var tags := UiKit.label(" ".join((def["tags"] as Array).map(func(t: String) -> String: return tr(t.capitalize()))), "SmallLabel")
	var desc := UiKit.wrap_label(tr(def["name_key"] + "_DESC"))
	var info := UiKit.vbox([UiKit.hbox([title, UiKit.spacer(), level]), tags, desc], 2)
	var completes: PackedStringArray = offer["completes"]
	if not completes.is_empty():
		var names: PackedStringArray = []
		for res_id in completes:
			names.append(tr(expedition.db.resonances[res_id]["name_key"]))
		var hint := UiKit.label(tr("Awakens %s!") % ", ".join(names), "ValueLabel")
		hint.add_theme_color_override("font_color", Palette.GOLD)
		info.add_child(hint)
	var gem := UiKit.icon("gem", 90, color)
	var row := UiKit.hbox([gem, UiKit.expand(info)], 18)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24
	row.offset_right = -24
	row.offset_top = 14
	row.offset_bottom = -14
	_ignore_mouse(row)
	b.add_child(row)
	return b


# --- events -------------------------------------------------------------------------------

func _show_event() -> void:
	var ev: Dictionary = expedition.db.events[expedition.event_id]
	var column := UiKit.vbox([
		UiKit.label(tr(ev["name_key"]), "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER),
		UiKit.panel(UiKit.wrap_label(tr(ev["name_key"] + "_DESC"), "", HORIZONTAL_ALIGNMENT_CENTER), "CardPanel"),
	], 24)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var options: Array = ev["options"]
	for i in options.size():
		column.add_child(UiKit.button(tr(options[i]["text_key"]), func() -> void:
			expedition.choose_event_option(i)
			_refresh(), "Button"))
	_body.add_child(column)


# --- results -------------------------------------------------------------------------------

func _show_results() -> void:
	if _result == null:
		var codex_before := Game.profile.codex_relics.size() + Game.profile.codex_resonances.size()
		_result = Game.finish_expedition()
		_result.set_meta("new_codex", Game.profile.codex_relics.size() + Game.profile.codex_resonances.size() - codex_before)
		UiKit.sfx("victory" if _result.won else "defeat")
	var r := _result
	var column := UiKit.vbox([], 18)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := UiKit.label(tr("Victory!") if r.won else tr("Defeated"), "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", Palette.GOLD if r.won else Palette.RED)
	column.add_child(title)
	var rows := UiKit.vbox([], 10)
	rows.add_child(UiKit.label(tr("Rooms cleared: %d / %d") % [r.rooms_cleared, expedition.rooms]))
	rows.add_child(UiKit.hbox([UiKit.icon("gold", 48), UiKit.label("+" + UiKit.format_number(r.gold), "HeadingLabel")]))
	rows.add_child(UiKit.hbox([UiKit.icon("shard", 48), UiKit.label("+" + UiKit.format_number(r.shards), "HeadingLabel")]))
	if r.first_clear and r.won:
		rows.add_child(UiKit.label(tr("First clear! New chapter unlocked."), "HeadingLabel"))
	for drop in r.gear_drops:
		var item_label := UiKit.label(tr("New gear: %s (%s)") % [tr(expedition.db.gear_items[drop["item"]]["name_key"]), tr(String(drop["rarity"]).capitalize())])
		item_label.add_theme_color_override("font_color", Palette.INK if drop["rarity"] == "common" else Palette.RARITY.get(drop["rarity"], Palette.INK).darkened(0.35))
		rows.add_child(item_label)
	var new_codex := int(r.get_meta("new_codex", 0))
	if new_codex > 0:
		rows.add_child(UiKit.label(tr("Codex discoveries: %d") % new_codex))
	column.add_child(UiKit.panel(rows, "CardPanel"))
	if not r.won and not Game.profile.echo_options.is_empty():
		column.add_child(UiKit.label(tr("Echo Keepsake: keep one relic for your next delve"), "ValueLabel", HORIZONTAL_ALIGNMENT_CENTER))
		var flow := HFlowContainer.new()
		for relic_id in Game.profile.echo_options:
			flow.add_child(UiKit.button(tr(expedition.db.relics[relic_id]["name_key"]), func() -> void:
				Game.choose_echo(relic_id)
				_refresh(), "BlueButton"))
		column.add_child(flow)
	elif Game.profile.echo_relic != "":
		column.add_child(UiKit.label(tr("Echo Keepsake: %s") % tr(expedition.db.relics[Game.profile.echo_relic]["name_key"]), "ValueLabel", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UiKit.spacer())
	column.add_child(UiKit.button(tr("Back to camp"), func() -> void: closed.emit(), "GreenButton"))
	_body.add_child(column)


func _on_retreat() -> void:
	if expedition.is_finished():
		closed.emit()
		return
	expedition.abandon()
	_refresh()


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_ignore_mouse(c)

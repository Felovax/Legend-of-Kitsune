class_name BattleView
extends Control
## Replays a BattleResult's event log as animation. The outcome is already
## decided by BattleSim; this view only shows it (so skip is always safe).

signal finished

const STATUS_COLORS := {"burn": Color("#ff7a3d"), "chill": Color("#7fd8ff"), "freeze": Color("#bfefff"), "shock": Color("#ffe14d")}
const KIND_COLORS := {"hit": Color.WHITE, "burn": Color("#ff9b3d"), "bolt": Color("#ffe14d"), "arc": Color("#d9a0ff"),
	"shatter": Color("#9ff3fb"), "slam": Color("#ff5d6c"), "flare": Color("#ffd65a")}

var result: BattleResult
var speed: float = 2.0
var reduced_effects: bool = false
var screen_shake: bool = true
var resonance_names: Dictionary = {}

var _tps: int = 20
var _clock: float = 0.0
var _index: int = 0
var _playing: bool = false
var _units: Dictionary = {}
var _fx_layer: Control
var _banner: Label


func play(battle: BattleResult, tps: int) -> void:
	result = battle
	_tps = tps
	_clock = 0.0
	_index = 0
	_fx_layer = Control.new()
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not result.events.is_empty() and result.events[0]["type"] == "battle_start":
		_spawn_units(result.events[0]["units"])
		_index = 1
	add_child(_fx_layer)
	_playing = true


## Shows the end state immediately.
func skip() -> void:
	if not _playing:
		return
	var saved_reduced := reduced_effects
	reduced_effects = true
	while _index < result.events.size():
		_apply(result.events[_index], true)
		_index += 1
	reduced_effects = saved_reduced
	_finish()


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	if not _playing:
		return
	_clock += delta * _tps * speed
	while _index < result.events.size() and float(result.events[_index]["t"]) <= _clock:
		_apply(result.events[_index], false)
		_index += 1
	if _index >= result.events.size():
		_finish()


func _finish() -> void:
	_playing = false
	var tween := create_tween()
	tween.tween_interval(0.5 / maxf(speed, 1.0))
	tween.tween_callback(finished.emit)


# --- units ---------------------------------------------------------------------

func _spawn_units(units: Array) -> void:
	var enemies: Array = units.filter(func(u: Dictionary) -> bool: return int(u["team"]) == Combatant.TEAM_ENEMY)
	var enemy_index := 0
	for u: Dictionary in units:
		var is_hero := int(u["team"]) == Combatant.TEAM_HERO
		var big := String(u["id"]) == "gatekeeper_golem" or String(u["id"]) == "ruin_brute"
		var box := Control.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var creature_size := 300.0 if is_hero else (320.0 if big else 230.0)
		var creature := CreatureDraw.new()
		creature.creature_id = u["id"]
		creature.flip = not is_hero
		creature.tails = 1 + (u.get("resonances", []) as Array).size()
		creature.size = Vector2(creature_size, creature_size)
		creature.position = Vector2(-creature_size / 2, -creature_size)
		box.add_child(creature)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = int(u["max_hp"])
		bar.value = int(u["hp"])
		bar.size = Vector2(minf(creature_size, 240.0), 26)
		bar.position = Vector2(-bar.size.x / 2, -creature_size - 40)
		if not is_hero:
			var fill := UiTheme.box(Palette.HP_ENEMY, Color.TRANSPARENT, 8, 0, 0)
			bar.add_theme_stylebox_override("fill", fill)
		box.add_child(bar)
		var status := UiKit.label("", "SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
		status.size = Vector2(260, 34)
		status.position = Vector2(-130, -creature_size - 78)
		status.add_theme_color_override("font_color", Color.WHITE)
		status.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		status.add_theme_constant_override("outline_size", 8)
		box.add_child(status)
		add_child(box)
		var home := _home_position(is_hero, enemy_index, enemies.size())
		if not is_hero:
			enemy_index += 1
		box.position = home
		_units[int(u["uid"])] = {"box": box, "creature": creature, "bar": bar, "status": status, "home": home,
			"statuses": {}, "hero": is_hero}
	resized.connect(_relayout)


func _home_position(is_hero: bool, index: int, count: int) -> Vector2:
	var w := maxf(size.x, 1080.0 - 48.0)
	var h := maxf(size.y, 900.0)
	if is_hero:
		return Vector2(w * 0.24, h * 0.78)
	var col := [Vector2(0.74, 0.76), Vector2(0.62, 0.52), Vector2(0.86, 0.5)]
	if count == 1:
		return Vector2(w * 0.72, h * 0.78)
	var p: Vector2 = col[mini(index, col.size() - 1)]
	return Vector2(w * p.x, h * p.y)


func _relayout() -> void:
	var enemy_index := 0
	var enemy_count := 0
	for uid: int in _units:
		if not _units[uid]["hero"]:
			enemy_count += 1
	for uid: int in _units:
		var u: Dictionary = _units[uid]
		var home := _home_position(u["hero"], enemy_index, enemy_count)
		if not u["hero"]:
			enemy_index += 1
		u["home"] = home
		(u["box"] as Control).position = home


# --- events --------------------------------------------------------------------

func _apply(e: Dictionary, instant: bool) -> void:
	match e["type"]:
		"attack":
			if not instant:
				_lunge(int(e["src"]), int(e["dst"]))
		"damage":
			_set_hp(int(e["dst"]), int(e["hp"]))
			if not instant:
				var kind: String = e.get("kind", "hit")
				var text := UiKit.format_number(int(e["amount"]))
				var big := bool(e.get("crit", false)) or kind == "shatter" or kind == "slam"
				if e.get("crit", false):
					text = tr("CRIT %s!") % text
				if int(e.get("absorbed", 0)) > 0 and int(e["absorbed"]) >= int(e["amount"]):
					text = tr("Blocked")
				_float_text(int(e["dst"]), text, KIND_COLORS.get(kind, Color.WHITE), big)
				_flash(int(e["dst"]))
				if big and screen_shake and not reduced_effects:
					_shake(14.0 if kind == "slam" else 8.0)
		"heal":
			_set_hp(int(e["dst"]), int(e["hp"]))
			if not instant:
				_float_text(int(e["dst"]), "+" + UiKit.format_number(int(e["amount"])), Palette.HP, false)
		"shield":
			if not instant:
				_float_text(int(e["dst"]), tr("Shield +%s") % UiKit.format_number(int(e["amount"])), Palette.SHIELD, false)
		"status":
			_set_status(int(e["dst"]), e["status"], int(e.get("stacks", 1)))
		"status_end":
			_set_status(int(e["dst"]), e["status"], 0)
		"proc":
			if e.get("source_kind", "") == "resonance" and not instant:
				_show_banner(resonance_names.get(e["source"], String(e["source"])))
		"death":
			var u: Dictionary = _units.get(int(e["dst"]), {})
			if not u.is_empty():
				var box: Control = u["box"]
				if instant:
					box.modulate.a = 0.0
				else:
					create_tween().tween_property(box, "modulate:a", 0.0, 0.35)


func _set_hp(uid: int, hp: int) -> void:
	var u: Dictionary = _units.get(uid, {})
	if not u.is_empty():
		(u["bar"] as ProgressBar).value = hp


func _set_status(uid: int, status: String, stacks: int) -> void:
	var u: Dictionary = _units.get(uid, {})
	if u.is_empty():
		return
	var statuses: Dictionary = u["statuses"]
	if stacks <= 0:
		statuses.erase(status)
	else:
		statuses[status] = stacks
	var parts: PackedStringArray = []
	for s: String in statuses:
		parts.append(tr(s.capitalize()) + ("" if s == "freeze" or s == "shock" else " %d" % statuses[s]))
	(u["status"] as Label).text = "  ".join(parts)
	var creature: CreatureDraw = u["creature"]
	creature.modulate = Color("#a8e4ff") if statuses.has("freeze") else Color.WHITE


func _lunge(src: int, dst: int) -> void:
	var a: Dictionary = _units.get(src, {})
	var b: Dictionary = _units.get(dst, {})
	if a.is_empty() or b.is_empty():
		return
	var box: Control = a["box"]
	var home: Vector2 = a["home"]
	var toward: Vector2 = home + (Vector2(b["home"]) - home).normalized() * 60.0
	var t := 0.12 / maxf(speed, 0.5)
	var tween := create_tween()
	tween.tween_property(box, "position", toward, t)
	tween.tween_property(box, "position", home, t)


func _flash(uid: int) -> void:
	var u: Dictionary = _units.get(uid, {})
	if u.is_empty() or reduced_effects:
		return
	var creature: CreatureDraw = u["creature"]
	creature.flash = 1.0
	create_tween().tween_property(creature, "flash", 0.0, 0.18)


func _float_text(uid: int, text: String, color: Color, big: bool) -> void:
	var u: Dictionary = _units.get(uid, {})
	if u.is_empty():
		return
	var label := UiKit.label(text, "ValueLabel", HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 60 if big else 40)
	label.size = Vector2(320, 70)
	var start: Vector2 = Vector2(u["home"]) + Vector2(-160 + randf_range(-30, 30), -330)
	label.position = start
	_fx_layer.add_child(label)
	var tween := create_tween().set_parallel(true)
	var duration := 0.7 / maxf(speed * 0.5, 0.5)
	tween.tween_property(label, "position:y", start.y - 90.0, duration)
	tween.tween_property(label, "modulate:a", 0.0, duration).set_delay(duration * 0.5)
	tween.chain().tween_callback(label.queue_free)


func _show_banner(text: String) -> void:
	if _banner != null:
		_banner.queue_free()
	_banner = UiKit.label(tr("RESONANCE!") + "\n" + text, "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_banner.add_theme_color_override("font_color", Palette.GOLD)
	_banner.size = Vector2(size.x, 200)
	_banner.position = Vector2(0, size.y * 0.12)
	_banner.pivot_offset = _banner.size / 2
	_fx_layer.add_child(_banner)
	var label := _banner
	var tween := create_tween()
	if not reduced_effects:
		label.scale = Vector2(0.4, 0.4)
		tween.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)


func _shake(strength: float) -> void:
	var tween := create_tween()
	for i in 4:
		tween.tween_property(self, "position", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.03)
	tween.tween_property(self, "position", Vector2.ZERO, 0.03)

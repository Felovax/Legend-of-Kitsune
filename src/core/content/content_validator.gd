class_name ContentValidator
extends RefCounted
## Validates raw content (as parsed from JSON) and returns readable errors.
## An empty result means the content is safe to load.

var errors: PackedStringArray = []


static func validate(data: Dictionary) -> PackedStringArray:
	var v := ContentValidator.new()
	v._validate_all(data)
	return v.errors


func _validate_all(data: Dictionary) -> void:
	_validate_balance(data.get("balance", null))
	var hero_ids := _validate_list(data, "heroes", _validate_hero)
	if hero_ids.is_empty():
		_err("heroes: at least one hero is required")
	_validate_list(data, "enemies", _validate_enemy)
	_validate_list(data, "relics", _validate_relic)
	_validate_list(data, "resonances", _validate_resonance)
	_validate_resonance_tags(data)


func _validate_list(data: Dictionary, key: String, check: Callable) -> PackedStringArray:
	var ids: PackedStringArray = []
	var list: Variant = data.get(key, null)
	if not list is Array:
		_err("%s: must be a list" % key)
		return ids
	for i in (list as Array).size():
		var entry: Variant = list[i]
		var path := "%s[%d]" % [key, i]
		if not entry is Dictionary:
			_err("%s: must be an object" % path)
			continue
		var id: Variant = entry.get("id", null)
		if not _is_id(id):
			_err("%s.id: must be a lower_snake_case string" % path)
		else:
			path = "%s[%s]" % [key, id]
			if ids.has(id):
				_err("%s: duplicate id" % path)
			ids.append(id)
		check.call(entry, path)
	return ids


func _validate_balance(balance: Variant) -> void:
	if not balance is Dictionary:
		_err("balance: missing or not an object")
		return
	var sim: Variant = balance.get("sim", null)
	if not sim is Dictionary:
		_err("balance.sim: missing")
	else:
		for key in ["ticks_per_second", "max_battle_seconds", "start_gauge_bp", "armor_cap_bp", "crit_cap_bp", "relic_level_bonus_bp", "max_trigger_depth"]:
			_require_int(sim, key, "balance.sim", 0)
		if _is_int(sim.get("ticks_per_second")) and int(sim["ticks_per_second"]) < 1:
			_err("balance.sim.ticks_per_second: must be >= 1")
	var status: Variant = balance.get("status", null)
	if not status is Dictionary:
		_err("balance.status: missing")
	else:
		for s in ["burn", "chill", "shock"]:
			if not status.get(s) is Dictionary:
				_err("balance.status.%s: missing" % s)
		if status.get("burn") is Dictionary:
			for key in ["max_stacks", "dps_per_stack_bp"]:
				_require_int(status["burn"], key, "balance.status.burn", 1)
			_require_number(status["burn"], "duration_s", "balance.status.burn")
		if status.get("chill") is Dictionary:
			for key in ["max_stacks", "aps_penalty_per_stack_bp"]:
				_require_int(status["chill"], key, "balance.status.chill", 1)
			for key in ["duration_s", "freeze_s", "freeze_immunity_s"]:
				_require_number(status["chill"], key, "balance.status.chill")
		if status.get("shock") is Dictionary:
			_require_int(status["shock"], "bonus_bp", "balance.status.shock", 0)
	var scaling: Variant = balance.get("enemy_scaling", null)
	if not scaling is Dictionary:
		_err("balance.enemy_scaling: missing")
	else:
		_require_int(scaling, "chapter_growth_bp", "balance.enemy_scaling", 10000)
		_require_int(scaling, "room_bonus_bp", "balance.enemy_scaling", 0)


func _validate_hero(hero: Dictionary, path: String) -> void:
	_validate_stats(hero.get("stats", null), ContentSchema.HERO_STATS, path)


func _validate_enemy(enemy: Dictionary, path: String) -> void:
	if not ContentSchema.ENEMY_ROLES.has(enemy.get("role", "")):
		_err("%s.role: must be one of %s" % [path, ", ".join(ContentSchema.ENEMY_ROLES)])
	_validate_stats(enemy.get("stats", null), ContentSchema.ENEMY_STATS, path)
	_validate_effects(enemy.get("effects", []), path)


func _validate_relic(relic: Dictionary, path: String) -> void:
	var tags: Variant = relic.get("tags", null)
	if not tags is Array or (tags as Array).is_empty():
		_err("%s.tags: must be a non-empty list" % path)
	else:
		for t: Variant in tags:
			if not _is_id(t):
				_err("%s.tags: '%s' is not a valid tag" % [path, str(t)])
	if not ContentSchema.RARITIES.has(relic.get("rarity", "")):
		_err("%s.rarity: must be one of %s" % [path, ", ".join(ContentSchema.RARITIES)])
	var effects: Variant = relic.get("effects", null)
	if not effects is Array or (effects as Array).is_empty():
		_err("%s.effects: a relic needs at least one effect" % path)
	_validate_effects(effects if effects is Array else [], path)


func _validate_resonance(res: Dictionary, path: String) -> void:
	var tags: Variant = res.get("requires_tags", null)
	if not tags is Array or (tags as Array).size() < 2:
		_err("%s.requires_tags: needs at least two tags" % path)
	var effects: Variant = res.get("effects", null)
	if not effects is Array or (effects as Array).is_empty():
		_err("%s.effects: a resonance needs at least one effect" % path)
	_validate_effects(effects if effects is Array else [], path)


func _validate_resonance_tags(data: Dictionary) -> void:
	var known: PackedStringArray = []
	if data.get("relics") is Array:
		for relic: Variant in data["relics"]:
			if relic is Dictionary and relic.get("tags") is Array:
				for t: Variant in relic["tags"]:
					known.append(str(t))
	if data.get("resonances") is Array:
		for res: Variant in data["resonances"]:
			if res is Dictionary and res.get("requires_tags") is Array:
				for t: Variant in res["requires_tags"]:
					if not known.has(str(t)):
						_err("resonances[%s].requires_tags: no relic has tag '%s'" % [str(res.get("id")), str(t)])


func _validate_stats(stats: Variant, required: PackedStringArray, path: String) -> void:
	if not stats is Dictionary:
		_err("%s.stats: missing" % path)
		return
	for key in required:
		_require_int(stats, key, path + ".stats", 0)
	if _is_int(stats.get("hp")) and int(stats["hp"]) < 1:
		_err("%s.stats.hp: must be >= 1" % path)
	if _is_int(stats.get("aps_milli")) and int(stats["aps_milli"]) < 1:
		_err("%s.stats.aps_milli: must be >= 1" % path)


func _validate_effects(effects: Variant, path: String) -> void:
	if not effects is Array:
		_err("%s.effects: must be a list" % path)
		return
	for i in (effects as Array).size():
		var e: Variant = effects[i]
		var p := "%s.effects[%d]" % [path, i]
		if not e is Dictionary:
			_err("%s: must be an object" % p)
			continue
		_validate_effect(e, p)


func _validate_effect(e: Dictionary, p: String) -> void:
	var trigger: Variant = e.get("trigger", null)
	if not ContentSchema.TRIGGERS.has(trigger):
		_err("%s.trigger: unknown trigger '%s'" % [p, str(trigger)])
	match trigger:
		"every_n_attacks":
			_require_int(e, "n", p, 1)
		"every_seconds":
			if not _is_number(e.get("seconds")) or float(e["seconds"]) <= 0.0:
				_err("%s.seconds: must be a number > 0" % p)
		"hp_below":
			_require_int(e, "threshold_bp", p, 1)
			if _is_int(e.get("threshold_bp")) and int(e["threshold_bp"]) >= 10000:
				_err("%s.threshold_bp: must be below 10000" % p)
		"on_status_applied":
			if not ContentSchema.STATUSES.has(e.get("status", "")):
				_err("%s.status: unknown status '%s'" % [p, str(e.get("status"))])
	if e.has("chance_bp"):
		_require_int(e, "chance_bp", p, 1)
	if e.has("target_has_status") and not ContentSchema.STATUSES.has(e["target_has_status"]):
		_err("%s.target_has_status: unknown status '%s'" % [p, str(e["target_has_status"])])
	var action: Variant = e.get("action", null)
	if not action is Dictionary:
		_err("%s.action: missing" % p)
		return
	_validate_action(action, p + ".action", str(trigger))


func _validate_action(a: Dictionary, p: String, trigger: String) -> void:
	var type: Variant = a.get("type", null)
	if not ContentSchema.ACTIONS.has(type):
		_err("%s.type: unknown action '%s'" % [p, str(type)])
		return
	var target: Variant = a.get("target", "target")
	if not ContentSchema.TARGETS.has(target):
		_err("%s.target: unknown target '%s'" % [p, str(target)])
	if trigger == "passive" and type != "modify_stat":
		_err("%s: passive effects may only use modify_stat" % p)
	match type:
		"apply_status":
			if not ContentSchema.STATUSES.has(a.get("status", "")):
				_err("%s.status: unknown status '%s'" % [p, str(a.get("status"))])
			_require_int(a, "stacks", p, 1)
		"damage":
			_require_int(a, "mult_bp", p, 1)
			if a.has("max_targets"):
				_require_int(a, "max_targets", p, 1)
		"heal", "shield":
			_require_int(a, "pct_max_hp_bp", p, 1)
		"modify_stat":
			if not ContentSchema.STATS.has(a.get("stat", "")):
				_err("%s.stat: unknown stat '%s'" % [p, str(a.get("stat"))])
			if not _is_int(a.get("add")):
				_err("%s.add: must be an integer" % p)
		"consume_burst":
			if a.get("status", "") != "burn":
				_err("%s.status: consume_burst currently supports only 'burn'" % p)
			_require_int(a, "mult_bp", p, 1)


func _require_int(d: Dictionary, key: String, path: String, minimum: int) -> void:
	var v: Variant = d.get(key, null)
	if not _is_int(v):
		_err("%s.%s: must be an integer" % [path, key])
	elif int(v) < minimum:
		_err("%s.%s: must be >= %d" % [path, key, minimum])


func _require_number(d: Dictionary, key: String, path: String) -> void:
	var v: Variant = d.get(key, null)
	if not _is_number(v) or float(v) < 0.0:
		_err("%s.%s: must be a number >= 0" % [path, key])


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _is_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and is_equal_approx(v, roundf(v))


static func _is_id(v: Variant) -> bool:
	if typeof(v) != TYPE_STRING or (v as String).is_empty():
		return false
	var re := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	return re.search(v) != null


func _err(message: String) -> void:
	errors.append(message)

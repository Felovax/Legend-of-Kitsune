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
	if data.has("progression"):
		_validate_progression(data["progression"])
	if data.has("gear"):
		_validate_gear(data["gear"])
	if data.has("chapters"):
		_validate_chapters(data["chapters"], data)
	if data.has("events"):
		_validate_list(data, "events", _validate_event)
	if data.has("shop"):
		_validate_shop(data["shop"], data)


func _validate_shop(shop: Variant, data: Dictionary) -> void:
	if not shop is Dictionary:
		_err("shop: must be an object")
		return
	_require_int(shop, "gems_per_usd", "shop", 1)
	var gear_ids := {}
	if data.get("gear") is Dictionary and data["gear"].get("items") is Array:
		for item: Variant in data["gear"]["items"]:
			if item is Dictionary:
				gear_ids[item.get("id")] = true
	var ids := {}
	var skus := {}
	for product: Variant in shop.get("products", []):
		if not product is Dictionary or not _is_id(product.get("id")):
			_err("shop.products: each product needs a lower_snake_case id")
			continue
		var path := "shop.products[%s]" % product["id"]
		if ids.has(product["id"]):
			_err("%s: duplicate id" % path)
		ids[product["id"]] = true
		var sku: Variant = product.get("store_sku")
		if not sku is String or (sku as String).is_empty():
			_err("%s.store_sku: required" % path)
		elif skus.has(sku):
			_err("%s.store_sku: duplicate '%s'" % [path, sku])
		else:
			skus[sku] = true
		if not ContentSchema.PRODUCT_TYPES.has(product.get("type")):
			_err("%s.type: must be one of %s" % [path, ", ".join(ContentSchema.PRODUCT_TYPES)])
		if not ContentSchema.PRODUCT_CATEGORIES.has(product.get("category")):
			_err("%s.category: unknown '%s'" % [path, str(product.get("category"))])
		if not _is_number(product.get("test_price_usd")) or float(product["test_price_usd"]) <= 0.0:
			_err("%s.test_price_usd: must be a number > 0" % path)
		_validate_contents(product.get("contents"), ContentSchema.PRODUCT_CONTENTS, path, gear_ids)
	for offer: Variant in shop.get("gem_offers", []):
		if not offer is Dictionary or not _is_id(offer.get("id")):
			_err("shop.gem_offers: each offer needs an id")
			continue
		var path := "shop.gem_offers[%s]" % offer["id"]
		var prices: Variant = offer.get("gem_prices")
		if not prices is Array or (prices as Array).is_empty():
			_err("%s.gem_prices: must be a non-empty list" % path)
		else:
			for price: Variant in prices:
				if not _is_int(price) or int(price) < 1:
					_err("%s.gem_prices: prices must be integers >= 1" % path)
		_validate_contents(offer.get("contents"), ContentSchema.OFFER_CONTENTS, path, gear_ids)
	var charter: Variant = shop.get("charter")
	if not charter is Dictionary:
		_err("shop.charter: missing")
	else:
		_require_int(charter, "gems_per_day", "shop.charter", 1)
		_require_int(charter, "max_banked_days", "shop.charter", 1)
	var last := 0
	for step: Variant in shop.get("ledger", []):
		if not step is Dictionary or not _is_int(step.get("chapter")):
			_err("shop.ledger: each step needs a chapter")
			continue
		if int(step["chapter"]) <= last:
			_err("shop.ledger: chapters must increase")
		last = int(step["chapter"])


func _validate_contents(contents: Variant, allowed: PackedStringArray, path: String, gear_ids: Dictionary) -> void:
	if not contents is Array or (contents as Array).is_empty():
		_err("%s.contents: must be a non-empty list" % path)
		return
	for c: Variant in contents:
		if not c is Dictionary or not allowed.has(c.get("type")):
			_err("%s.contents: unknown content '%s'" % [path, str(c.get("type") if c is Dictionary else c)])
			continue
		match c["type"]:
			"gear":
				if not gear_ids.has(c.get("item")):
					_err("%s.contents: unknown gear '%s'" % [path, str(c.get("item"))])
			"entitlement":
				if not ContentSchema.ENTITLEMENTS.has(c.get("id")):
					_err("%s.contents: unknown entitlement '%s'" % [path, str(c.get("id"))])
			_:
				_require_int(c, "amount", path + ".contents", 1)


# --- meta-game content ------------------------------------------------------

func _validate_cost(d: Variant, path: String) -> void:
	if not d is Dictionary:
		_err("%s: missing cost curve" % path)
		return
	_require_int(d, "base", path, 1)
	_require_int(d, "growth_bp", path, 10000)


func _validate_progression(p: Variant) -> void:
	if not p is Dictionary:
		_err("progression: must be an object")
		return
	var hero: Variant = p.get("hero")
	if not hero is Dictionary:
		_err("progression.hero: missing")
	else:
		_require_int(hero, "level_stat_growth_bp", "progression.hero", 10000)
		_validate_cost(hero.get("level_cost"), "progression.hero.level_cost")
		_require_int(hero, "max_level_base", "progression.hero", 1)
		_require_int(hero, "max_level_per_chapter", "progression.hero", 0)
	var training: Variant = p.get("training")
	if not training is Array or (training as Array).is_empty():
		_err("progression.training: must be a non-empty list")
	else:
		var ids: PackedStringArray = []
		for t: Variant in training:
			if not t is Dictionary or not _is_id(t.get("id")):
				_err("progression.training: each entry needs an id")
				continue
			var path := "progression.training[%s]" % t["id"]
			if ids.has(t["id"]):
				_err("%s: duplicate id" % path)
			ids.append(t["id"])
			_require_int(t, "max_rank", path, 1)
			_validate_cost(t.get("cost"), path + ".cost")
			var gives := false
			for key in ["atk_pct_bp", "hp_pct_bp", "crit_bp", "crit_dmg_bp"]:
				if t.has(key):
					_require_int(t, key, path, 0)
					gives = true
			if not gives:
				_err("%s: grants no stat" % path)
	var att: Variant = p.get("attunement")
	if not att is Dictionary:
		_err("progression.attunement: missing")
	else:
		_require_int(att, "potency_per_level_bp", "progression.attunement", 0)
		_require_int(att, "max_level", "progression.attunement", 1)
		_validate_cost(att.get("cost"), "progression.attunement.cost")
	var run: Variant = p.get("run")
	if not run is Dictionary:
		_err("progression.run: missing")
	else:
		for key in ["rooms", "elite_room", "draft_size", "max_tails", "minutes_per_full_run_x10"]:
			_require_int(run, key, "progression.run", 1)
		for key in ["heal_between_rooms_bp", "shrine_heal_bp", "free_rerolls", "tail_atk_bp"]:
			_require_int(run, key, "progression.run", 0)
		if _is_int(run.get("elite_room")) and _is_int(run.get("rooms")) and int(run["elite_room"]) >= int(run["rooms"]):
			_err("progression.run.elite_room: must be before the boss room")
		var doors: Variant = run.get("door_weights")
		if not doors is Dictionary:
			_err("progression.run.door_weights: missing")
		else:
			for kind: Variant in doors:
				if not ContentSchema.DOOR_KINDS.has(kind):
					_err("progression.run.door_weights: unknown door '%s'" % str(kind))
				_require_int(doors, str(kind), "progression.run.door_weights", 0)
		var rw: Variant = run.get("relic_rarity_weights")
		if not rw is Dictionary:
			_err("progression.run.relic_rarity_weights: missing")
		else:
			for r: Variant in rw:
				if not ContentSchema.RARITIES.has(r):
					_err("progression.run.relic_rarity_weights: unknown rarity '%s'" % str(r))
	var rewards: Variant = p.get("rewards")
	if not rewards is Dictionary:
		_err("progression.rewards: missing")
	else:
		for key in ["gold_per_room", "gold_growth_bp", "elite_gold_bp", "boss_gold_bp", "replay_gold_bp",
				"first_clear_bonus_bp", "first_clear_gems", "shards_per_room", "shards_win_bonus",
				"shards_chapter_bonus_bp", "event_gold_rooms", "relic_discovery_gems", "resonance_discovery_gems"]:
			_require_int(rewards, key, "progression.rewards", 0)
	var offline: Variant = p.get("offline")
	if not offline is Dictionary:
		_err("progression.offline: missing")
	else:
		_require_int(offline, "farm_rate_bp", "progression.offline", 0)
		_require_int(offline, "cap_minutes", "progression.offline", 1)
	var power: Variant = p.get("power")
	if not power is Dictionary:
		_err("progression.power: missing")
	else:
		_require_int(power, "chapter_growth_bp", "progression.power", 10000)


func _validate_gear(g: Variant) -> void:
	if not g is Dictionary:
		_err("gear: must be an object")
		return
	var slots: Variant = g.get("slots")
	if not slots is Array or (slots as Array).is_empty():
		_err("gear.slots: must be a non-empty list")
		slots = []
	var rarities: Variant = g.get("rarities")
	if not rarities is Array or (rarities as Array).is_empty():
		_err("gear.rarities: must be a non-empty list")
	else:
		for r: Variant in rarities:
			if not r is Dictionary or not _is_id(r.get("id")):
				_err("gear.rarities: each entry needs an id")
				continue
			var path := "gear.rarities[%s]" % r["id"]
			_require_int(r, "stat_mult_bp", path, 1)
			_require_int(r, "max_enhance", path, 0)
			_require_int(r, "drop_weight", path, 0)
	_require_int(g, "enhance_per_level_bp", "gear", 0)
	_require_int(g, "merge_count", "gear", 2)
	_validate_cost(g.get("enhance_cost"), "gear.enhance_cost")
	var drops: Variant = g.get("drops")
	if not drops is Dictionary:
		_err("gear.drops: missing")
	else:
		_require_int(drops, "boss_chance_bp", "gear.drops", 0)
		_require_int(drops, "elite_chance_bp", "gear.drops", 0)
	var items: Variant = g.get("items")
	if not items is Array or (items as Array).is_empty():
		_err("gear.items: must be a non-empty list")
		return
	var ids: PackedStringArray = []
	for item: Variant in items:
		if not item is Dictionary or not _is_id(item.get("id")):
			_err("gear.items: each item needs a lower_snake_case id")
			continue
		var path := "gear.items[%s]" % item["id"]
		if ids.has(item["id"]):
			_err("%s: duplicate id" % path)
		ids.append(item["id"])
		if not (slots as Array).has(item.get("slot")):
			_err("%s.slot: unknown slot '%s'" % [path, str(item.get("slot"))])
		var stats: Variant = item.get("stats")
		if not stats is Dictionary or (stats as Dictionary).is_empty():
			_err("%s.stats: must be a non-empty object" % path)
		else:
			for key: Variant in stats:
				if not ContentSchema.GEAR_STATS.has(key):
					_err("%s.stats: unknown stat '%s'" % [path, str(key)])
				_require_int(stats, str(key), path + ".stats", 1)


func _validate_chapters(c: Variant, data: Dictionary) -> void:
	if not c is Dictionary:
		_err("chapters: must be an object")
		return
	var enemy_roles := {}
	if data.get("enemies") is Array:
		for e: Variant in data["enemies"]:
			if e is Dictionary:
				enemy_roles[e.get("id")] = e.get("role")
	var sizes: Variant = c.get("group_sizes")
	if not sizes is Array:
		_err("chapters.group_sizes: must be a list of [min, max] per room")
	else:
		var rooms := 0
		if data.get("progression") is Dictionary and (data["progression"] as Dictionary).get("run") is Dictionary:
			rooms = int(data["progression"]["run"].get("rooms", 0))
		if rooms > 0 and (sizes as Array).size() != rooms:
			_err("chapters.group_sizes: needs one entry per room (%d)" % rooms)
		for pair: Variant in sizes:
			if not pair is Array or (pair as Array).size() != 2 or not _is_int(pair[0]) or not _is_int(pair[1]) \
					or int(pair[0]) < 1 or int(pair[1]) < int(pair[0]):
				_err("chapters.group_sizes: each entry must be [min, max] with 1 <= min <= max")
	var list: Variant = c.get("chapters")
	if not list is Array or (list as Array).is_empty():
		_err("chapters.chapters: must be a non-empty list")
		return
	for i in (list as Array).size():
		var ch: Variant = list[i]
		if not ch is Dictionary:
			_err("chapters.chapters[%d]: must be an object" % i)
			continue
		var path := "chapters[%s]" % str(ch.get("id", i))
		if not _is_id(ch.get("id")):
			_err("%s.id: must be a lower_snake_case string" % path)
		if not _is_int(ch.get("number")) or int(ch["number"]) != i + 1:
			_err("%s.number: chapters must be numbered 1, 2, 3... in order" % path)
		var normals: Variant = ch.get("normals")
		if not normals is Array or (normals as Array).is_empty():
			_err("%s.normals: must be a non-empty list" % path)
		else:
			for n: Variant in normals:
				if enemy_roles.get(n) != "normal":
					_err("%s.normals: '%s' is not a normal enemy" % [path, str(n)])
		if enemy_roles.get(ch.get("elite")) != "elite":
			_err("%s.elite: '%s' is not an elite enemy" % [path, str(ch.get("elite"))])
		if enemy_roles.get(ch.get("boss")) != "boss":
			_err("%s.boss: '%s' is not a boss enemy" % [path, str(ch.get("boss"))])


func _validate_event(ev: Dictionary, path: String) -> void:
	var options: Variant = ev.get("options")
	if not options is Array or (options as Array).is_empty():
		_err("%s.options: must be a non-empty list" % path)
		return
	for i in (options as Array).size():
		var opt: Variant = options[i]
		var p := "%s.options[%d]" % [path, i]
		if not opt is Dictionary or not _is_id(opt.get("id")):
			_err("%s: needs a lower_snake_case id" % p)
			continue
		var outcomes: Variant = opt.get("outcomes")
		if not outcomes is Array:
			_err("%s.outcomes: must be a list" % p)
			continue
		for o: Variant in outcomes:
			if not o is Dictionary or not ContentSchema.EVENT_OUTCOMES.has(o.get("type")):
				_err("%s.outcomes: unknown outcome '%s'" % [p, str(o.get("type") if o is Dictionary else o)])
				continue
			_require_int(o, "value", p, 0)


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

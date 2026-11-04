class_name AutoPilot
extends RefCounted
## Plays expeditions and spends resources automatically with simple, sensible
## choices. Used by simulations, softlock tests and the auto-repeat feature.

const DOOR_SCORE := {"treasure": 50, "fight": 40, "event": 30, "elite": 20, "shrine": 10}


static func play(exp: Expedition, random_choices: bool = false, rng_seed: int = 1) -> RunResult:
	var rng := Rng32.new(rng_seed)
	var guard := 0
	while not exp.is_finished() and guard < 500:
		guard += 1
		match exp.phase:
			Expedition.Phase.DOOR:
				exp.choose_door(rng.next_below(exp.doors.size()) if random_choices else best_door(exp))
			Expedition.Phase.BATTLE:
				exp.fight()
			Expedition.Phase.DRAFT:
				exp.pick_relic(rng.next_below(exp.draft_offer.size()) if random_choices else best_pick(exp))
			Expedition.Phase.EVENT:
				var count: int = (exp.db.events[exp.event_id]["options"] as Array).size()
				exp.choose_event_option(rng.next_below(count) if random_choices else best_event_option(exp))
	if not exp.is_finished():
		exp.abandon()
	return exp.result()


static func best_door(exp: Expedition) -> int:
	var hp_ratio := exp.hero_hp * 10000 / maxi(1, exp.hero_max_hp)
	var best := 0
	var best_score := -1
	for i in exp.doors.size():
		var kind := exp.doors[i]
		var score: int = DOOR_SCORE.get(kind, 0)
		if kind == "shrine" and hp_ratio < 5000:
			score = 100
		if kind == "elite" and hp_ratio > 8000:
			score = 45
		if score > best_score:
			best_score = score
			best = i
	return best


static func best_pick(exp: Expedition) -> int:
	var best := 0
	var best_score := -1
	for i in exp.draft_offer.size():
		var offer: Dictionary = exp.draft_offer[i]
		var score := 10
		if not (offer["completes"] as PackedStringArray).is_empty():
			score = 100
		elif offer["upgrade"]:
			score = 20 + int(offer["level"])
		if score > best_score:
			best_score = score
			best = i
	return best


static func best_event_option(exp: Expedition) -> int:
	var options: Array = exp.db.events[exp.event_id]["options"]
	var hp_ratio := exp.hero_hp * 10000 / maxi(1, exp.hero_max_hp)
	for i in options.size():
		var risky := false
		for o: Dictionary in options[i]["outcomes"]:
			if o["type"] == "hp_cost_bp" and hp_ratio < 6000:
				risky = true
		if not risky:
			return i
	return options.size() - 1


## Buys the upgrade with the best power gain per gold until nothing is
## affordable. Also merges gear, equips the strongest gear and attunes relics.
static func spend_greedily(prog: Progression, profile: PlayerProfile, max_purchases: int = 10000) -> int:
	var purchases := 0
	_merge_and_equip(prog, profile)
	while purchases < max_purchases:
		var base_power := prog.power(profile)
		var best_action := ""
		var best_value := 0.0
		var options: Array[Dictionary] = []
		if profile.hero_level < prog.max_level(profile):
			options.append({"action": "level", "cost": prog.level_cost(profile.hero_level)})
		for id in prog.training_ids():
			var rank := int(profile.training.get(id, 0))
			if rank < int(prog.training_def(id)["max_rank"]):
				options.append({"action": "train:" + id, "cost": prog.training_cost(id, rank)})
		for slot: String in profile.equipped:
			var g := profile.gear_by_uid(int(profile.equipped[slot]))
			if not g.is_empty() and int(g["enhance"]) < int(prog.db.gear_rarities[g["rarity"]]["max_enhance"]):
				options.append({"action": "enhance:%d" % int(g["uid"]), "cost": prog.enhance_cost(int(g["enhance"]))})
		for option in options:
			if int(option["cost"]) > profile.wallet.gold:
				continue
			var gain := float(_power_after(prog, profile, option["action"]) - base_power) / float(maxi(1, int(option["cost"])))
			if gain > best_value:
				best_value = gain
				best_action = option["action"]
		if best_action.is_empty():
			break
		if _apply(prog, profile, best_action) != Progression.OK:
			break
		purchases += 1
	# Shards: attune the relics the player knows, cheapest first.
	var attuned := true
	while attuned:
		attuned = false
		var cheapest := ""
		var cheapest_cost := 1 << 60
		for relic_id in profile.codex_relics:
			var cost := prog.attunement_cost(int(profile.attunement.get(relic_id, 0)))
			if cost < cheapest_cost:
				cheapest_cost = cost
				cheapest = relic_id
		if cheapest != "" and prog.attune(profile, cheapest) == Progression.OK:
			attuned = true
			purchases += 1
	return purchases


## Power if the action were taken, by applying it temporarily and undoing it.
static func _power_after(prog: Progression, profile: PlayerProfile, action: String) -> int:
	var result := 0
	if action == "level":
		profile.hero_level += 1
		result = prog.power(profile)
		profile.hero_level -= 1
	elif action.begins_with("train:"):
		var id := action.substr(6)
		profile.training[id] = int(profile.training.get(id, 0)) + 1
		result = prog.power(profile)
		profile.training[id] = int(profile.training[id]) - 1
	elif action.begins_with("enhance:"):
		var g := profile.gear_by_uid(int(action.substr(8)))
		g["enhance"] = int(g["enhance"]) + 1
		result = prog.power(profile)
		g["enhance"] = int(g["enhance"]) - 1
	return result


static func _apply(prog: Progression, profile: PlayerProfile, action: String) -> String:
	if action == "level":
		return prog.level_up(profile)
	if action.begins_with("train:"):
		return prog.train(profile, action.substr(6))
	if action.begins_with("enhance:"):
		return prog.enhance(profile, int(action.substr(8)))
	return Progression.ERR_UNKNOWN


static func _merge_and_equip(prog: Progression, profile: PlayerProfile) -> void:
	var merged := true
	while merged:
		merged = false
		for item_id: String in prog.db.gear_items:
			for rarity in prog.db.gear_rarity_order:
				if prog.merge(profile, item_id, rarity) == Progression.OK:
					merged = true
	for slot: String in prog.db.gear["slots"]:
		var best_uid := int(profile.equipped.get(slot, -1))
		var best_power := prog.power(profile) if best_uid >= 0 else -1
		for g in profile.gear:
			if prog.db.gear_items[g["item"]]["slot"] != slot:
				continue
			var previous: Variant = profile.equipped.get(slot, null)
			profile.equipped[slot] = int(g["uid"])
			var p := prog.power(profile)
			if previous == null:
				profile.equipped.erase(slot)
			else:
				profile.equipped[slot] = previous
			if p > best_power:
				best_power = p
				best_uid = int(g["uid"])
		if best_uid >= 0:
			profile.equipped[slot] = best_uid

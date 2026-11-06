class_name Expedition
extends RefCounted
## One delve: rooms of doors, fights, relic drafts and events, ending at the
## boss or at the hero's defeat. Deterministic for a profile snapshot + seed.
##
## UI flow by phase:
##   DOOR     -> doors, choose_door(i)       (fixed rooms offer a single door)
##   BATTLE   -> fight() returns the BattleResult to replay
##   DRAFT    -> draft_offer, pick_relic(i) / reroll() / skip_draft()
##   EVENT    -> event_id, choose_event_option(i)
##   FINISHED -> result(), then Progression.apply_run_result()

enum Phase { DOOR, BATTLE, DRAFT, EVENT, FINISHED }

## Emitted after every player action, so the game can save progress mid-run.
signal action_taken(action: Array)

const STREAM_DOORS := 1
const STREAM_ENCOUNTERS := 2
const STREAM_DRAFT := 3
const STREAM_EVENTS := 4
const STREAM_LOOT := 5
const STREAM_BATTLE := 100

var db: ContentDB
var prog: Progression
var factory: CombatFactory
var run_cfg: Dictionary
var chapter: int
var chapter_def: Dictionary
var run_id: String
var run_seed: int
var first_clear: bool

var phase: int = Phase.DOOR
var room: int = 0
var rooms: int
var hero_id: String
var base_stats: Dictionary
var attunement_bp: Dictionary = {}
var hero_max_hp: int
var hero_hp: int
## Ordered relic id -> in-run level
var relics: Dictionary = {}
var rerolls_left: int
## Door kinds offered in the current room.
var doors: PackedStringArray = []
var room_kind: String = ""
## Each offer: {relic, level, upgrade: bool, completes: PackedStringArray}
var draft_offer: Array[Dictionary] = []
var event_id: String = ""
var last_battle: BattleResult = null
## Run-level story for the UI and analytics.
var history: Array[Dictionary] = []
## Every player action in order, e.g. ["door", 1], ["fight"], ["pick", 0].
## Replaying them on a fresh Expedition with the same seed rebuilds this one.
var actions: Array = []
var _start_profile: Dictionary = {}
## First expedition ever: the first two drafts guarantee a Resonance pair.
var tutorial: bool = false
var _drafts_made: int = 0

var _result := RunResult.new()
var _rng_doors: Rng32
var _rng_encounters: Rng32
var _rng_draft: Rng32
var _rng_events: Rng32
var _rng_loot: Rng32


## Starts a new expedition and consumes one run number from the profile.
static func start(content: ContentDB, profile: PlayerProfile, chapter_number: int) -> Expedition:
	var counter := profile.run_counter
	profile.run_counter += 1
	return Expedition.new(content, profile, chapter_number, Rng32.derive_seed(profile.seed_base, counter), "r%d" % counter)


## Everything needed to rebuild this expedition later (after an app restart).
func to_snapshot() -> Dictionary:
	return {"chapter": chapter, "seed": run_seed, "run_id": run_id, "profile": _start_profile.duplicate(true),
		"actions": actions.duplicate(true), "tutorial": tutorial}


## Rebuilds an expedition from a snapshot by replaying its actions.
## Returns null if the snapshot is unusable.
static func restore(content: ContentDB, snapshot: Dictionary) -> Expedition:
	if not snapshot.get("profile") is Dictionary or not snapshot.get("actions") is Array:
		return null
	var profile := PlayerProfile.from_dict(snapshot["profile"])
	profile.counters["runs"] = 0 if snapshot.get("tutorial", false) else 1
	var exp := Expedition.new(content, profile, int(snapshot.get("chapter", 1)), int(snapshot.get("seed", 0)),
		str(snapshot.get("run_id", "")))
	for a: Variant in snapshot["actions"]:
		if not a is Array or (a as Array).is_empty() or not exp._replay(a):
			return null
	return exp


func _replay(a: Array) -> bool:
	var arg := int(a[1]) if a.size() > 1 else 0
	match str(a[0]):
		"door":
			return choose_door(arg) == Progression.OK
		"fight":
			return fight() != null
		"pick":
			return pick_relic(arg) == Progression.OK
		"reroll":
			return reroll() == Progression.OK
		"skip":
			return skip_draft() == Progression.OK
		"event":
			return choose_event_option(arg) == Progression.OK
		"abandon":
			abandon()
			return true
	return false


func _record(action: Array) -> void:
	actions.append(action)
	action_taken.emit(action)


func _init(content: ContentDB, profile: PlayerProfile, chapter_number: int, seed_value: int, id: String) -> void:
	db = content
	prog = Progression.new(db)
	factory = CombatFactory.new(db)
	run_cfg = db.progression["run"]
	chapter = maxi(1, chapter_number)
	chapter_def = db.chapter_def(chapter)
	run_id = id
	run_seed = seed_value
	_start_profile = profile.to_dict()
	for transient in ["wallet", "applied_runs", "active_run", "counters"]:
		_start_profile.erase(transient)
	rooms = int(run_cfg["rooms"])
	first_clear = chapter > profile.best_chapter
	tutorial = int(profile.counters.get("runs", 0)) == 0 and profile.best_chapter == 0
	hero_id = profile.hero_id
	base_stats = prog.hero_stats(profile)
	hero_max_hp = int(base_stats["hp"])
	hero_hp = hero_max_hp
	rerolls_left = int(run_cfg["free_rerolls"])
	for relic_id in db.relic_order:
		var bonus := prog.attunement_bonus_bp(profile, relic_id)
		if bonus > 0:
			attunement_bp[relic_id] = bonus
	_rng_doors = Rng32.new(Rng32.derive_seed(run_seed, STREAM_DOORS))
	_rng_encounters = Rng32.new(Rng32.derive_seed(run_seed, STREAM_ENCOUNTERS))
	_rng_draft = Rng32.new(Rng32.derive_seed(run_seed, STREAM_DRAFT))
	_rng_events = Rng32.new(Rng32.derive_seed(run_seed, STREAM_EVENTS))
	_rng_loot = Rng32.new(Rng32.derive_seed(run_seed, STREAM_LOOT))
	_result.run_id = run_id
	_result.chapter = chapter
	_result.first_clear = first_clear
	if profile.echo_relic != "" and db.relics.has(profile.echo_relic):
		relics[profile.echo_relic] = 1
		_result.echo_used = profile.echo_relic
		history.append({"type": "echo", "relic": profile.echo_relic})
	_enter_room(1)


# --- player actions ----------------------------------------------------------------

func choose_door(index: int) -> String:
	if phase != Phase.DOOR or index < 0 or index >= doors.size():
		return Progression.ERR_UNKNOWN
	room_kind = doors[index]
	actions.append(["door", index])
	history.append({"type": "door", "room": room, "kind": room_kind})
	match room_kind:
		"fight", "elite", "boss":
			phase = Phase.BATTLE
		"shrine":
			_heal(int(run_cfg["shrine_heal_bp"]))
			_advance()
		"treasure":
			_open_draft()
		"event":
			event_id = db.event_order[_rng_events.next_below(db.event_order.size())]
			phase = Phase.EVENT
	action_taken.emit(actions[-1])
	return Progression.OK


func fight() -> BattleResult:
	if phase != Phase.BATTLE:
		return null
	var hero := factory.make_hero(hero_id, relics, _stats_with_tails(), hero_hp, attunement_bp)
	var sim := BattleSim.new(factory.cfg, Rng32.derive_seed(run_seed, STREAM_BATTLE + room))
	sim.add_unit(hero)
	for enemy_id in _encounter():
		sim.add_unit(factory.make_enemy(enemy_id, chapter, room))
	var battle := sim.run()
	last_battle = battle
	actions.append(["fight"])
	_result.battles += 1
	_result.battle_ticks += battle.ticks
	hero_hp = battle.hero_hp
	history.append({"type": "battle", "room": room, "kind": room_kind, "outcome": battle.outcome, "ticks": battle.ticks})
	if not battle.hero_won():
		_finish(false)
		action_taken.emit(actions[-1])
		return battle
	_result.rooms_cleared = room
	_result.gold += prog.room_gold(chapter, room_kind, not first_clear)
	_result.shards += prog.shards_per_room(chapter)
	_roll_loot()
	if room_kind == "boss":
		var rewards: Dictionary = db.progression["rewards"]
		if first_clear:
			_result.gold += Fx.bp(prog.room_gold(chapter, "boss", false), int(rewards["first_clear_bonus_bp"]))
		_result.shards += int(rewards["shards_win_bonus"])
		_finish(true)
		action_taken.emit(actions[-1])
		return battle
	_heal(int(run_cfg["heal_between_rooms_bp"]))
	_open_draft()
	action_taken.emit(actions[-1])
	return battle


func pick_relic(index: int) -> String:
	if phase != Phase.DRAFT or index < 0 or index >= draft_offer.size():
		return Progression.ERR_UNKNOWN
	var relic_id: String = draft_offer[index]["relic"]
	_add_relic(relic_id, 1)
	history.append({"type": "pick", "room": room, "relic": relic_id, "level": relics[relic_id]})
	draft_offer.clear()
	_advance()
	_record(["pick", index])
	return Progression.OK


func reroll() -> String:
	if phase != Phase.DRAFT:
		return Progression.ERR_UNKNOWN
	if rerolls_left <= 0:
		return Progression.ERR_FUNDS
	rerolls_left -= 1
	draft_offer = _make_offer()
	_record(["reroll"])
	return Progression.OK


func skip_draft() -> String:
	if phase != Phase.DRAFT:
		return Progression.ERR_UNKNOWN
	draft_offer.clear()
	_advance()
	_record(["skip"])
	return Progression.OK


func choose_event_option(index: int) -> String:
	if phase != Phase.EVENT:
		return Progression.ERR_UNKNOWN
	var options: Array = db.events[event_id]["options"]
	if index < 0 or index >= options.size():
		return Progression.ERR_UNKNOWN
	var option: Dictionary = options[index]
	for outcome: Dictionary in option["outcomes"]:
		var value := int(outcome["value"])
		match outcome["type"]:
			"gold_rooms":
				_result.gold += prog.room_gold(chapter, "fight", not first_clear) * value
			"heal_bp":
				_heal(value)
			"hp_cost_bp":
				hero_hp = maxi(1, hero_hp - Fx.bp(hero_max_hp, value))
			"shards":
				_result.shards += value
			"upgrade_random_relic":
				if not relics.is_empty():
					var keys: Array = relics.keys()
					_add_relic(keys[_rng_events.next_below(keys.size())], value)
			"random_relic":
				_add_relic(_weighted_relic(_rng_events, []), value)
	history.append({"type": "event", "room": room, "event": event_id, "option": option["id"]})
	event_id = ""
	_advance()
	_record(["event", index])
	return Progression.OK


## Leaves the expedition early; counts as a defeat (rewards so far are kept).
func abandon() -> void:
	if phase != Phase.FINISHED:
		_finish(false)
		_record(["abandon"])


# --- queries -------------------------------------------------------------------------

func active_resonances() -> PackedStringArray:
	return db.active_resonances(PackedStringArray(relics.keys()))


func tails() -> int:
	return mini(int(run_cfg["max_tails"]), active_resonances().size())


func is_finished() -> bool:
	return phase == Phase.FINISHED


func result() -> RunResult:
	return _result


# --- internals -----------------------------------------------------------------------

func _enter_room(number: int) -> void:
	room = number
	room_kind = ""
	doors = _make_doors(number)
	phase = Phase.DOOR
	history.append({"type": "room", "room": room, "doors": Array(doors)})


func _advance() -> void:
	if room >= rooms:
		_finish(false)
		return
	_enter_room(room + 1)


func _make_doors(number: int) -> PackedStringArray:
	if number == 1:
		return PackedStringArray(["fight"])
	if number == int(run_cfg["elite_room"]):
		return PackedStringArray(["elite"])
	if number == rooms:
		return PackedStringArray(["boss"])
	var weights: Dictionary = run_cfg["door_weights"]
	var first := _weighted_key(weights, _rng_doors)
	var second := first
	for i in 20:
		second = _weighted_key(weights, _rng_doors)
		if second != first:
			break
	if second == first:
		second = "shrine" if first == "fight" else "fight"
	return PackedStringArray([first, second])


func _encounter() -> PackedStringArray:
	match room_kind:
		"boss":
			return PackedStringArray([chapter_def["boss"]])
		"elite":
			return PackedStringArray([chapter_def["elite"]])
	var pair: Array = db.group_sizes[mini(room, db.group_sizes.size()) - 1]
	var count := _rng_encounters.range_int(int(pair[0]), int(pair[1]))
	var pool: Array = chapter_def["normals"]
	var out: PackedStringArray = []
	for i in count:
		out.append(pool[_rng_encounters.next_below(pool.size())])
	return out


func _open_draft() -> void:
	draft_offer = _tutorial_offer() if tutorial and _drafts_made < 2 else _make_offer()
	_drafts_made += 1
	phase = Phase.DRAFT


## Onboarding: first draft offers three relics that each belong to a Resonance;
## the second offers the partner of whichever was taken.
func _tutorial_offer() -> Array[Dictionary]:
	var pairs := {"ember_stone": "frozen_core", "frozen_core": "ember_stone", "storm_crystal": "chain_relic",
		"chain_relic": "storm_crystal", "whetstone": "blood_chalice", "blood_chalice": "whetstone"}
	var ids: PackedStringArray = []
	if _drafts_made == 0:
		ids = PackedStringArray(["ember_stone", "frozen_core", "storm_crystal"])
	else:
		for relic_id: String in relics:
			if pairs.has(relic_id) and not relics.has(pairs[relic_id]):
				ids.append(pairs[relic_id])
				break
		for extra in ["hourglass", "ward_stone", "whetstone"]:
			if ids.size() < 3 and not ids.has(extra) and not relics.has(extra):
				ids.append(extra)
	var offer: Array[Dictionary] = []
	var now := active_resonances()
	for relic_id in ids:
		if not db.relics.has(relic_id):
			continue
		var with_it := PackedStringArray(relics.keys())
		if not with_it.has(relic_id):
			with_it.append(relic_id)
		var completes: PackedStringArray = []
		for res_id in db.active_resonances(with_it):
			if not now.has(res_id):
				completes.append(res_id)
		offer.append({"relic": relic_id, "level": int(relics.get(relic_id, 0)) + 1,
			"upgrade": relics.has(relic_id), "completes": completes})
	return offer if not offer.is_empty() else _make_offer()


func _make_offer() -> Array[Dictionary]:
	var offer: Array[Dictionary] = []
	var taken: PackedStringArray = []
	var size := mini(int(run_cfg["draft_size"]), db.relic_order.size())
	while offer.size() < size:
		var relic_id := _weighted_relic(_rng_draft, taken)
		if relic_id.is_empty():
			break
		taken.append(relic_id)
		var with_it := PackedStringArray(relics.keys())
		if not with_it.has(relic_id):
			with_it.append(relic_id)
		var completes: PackedStringArray = []
		var now := active_resonances()
		for res_id in db.active_resonances(with_it):
			if not now.has(res_id):
				completes.append(res_id)
		offer.append({"relic": relic_id, "level": int(relics.get(relic_id, 0)) + 1,
			"upgrade": relics.has(relic_id), "completes": completes})
	return offer


func _weighted_relic(rng: Rng32, exclude: PackedStringArray) -> String:
	var weights: Dictionary = run_cfg["relic_rarity_weights"]
	var total := 0
	for relic_id in db.relic_order:
		if not exclude.has(relic_id):
			total += int(weights.get(db.relics[relic_id]["rarity"], 0))
	if total <= 0:
		return ""
	var roll := rng.next_below(total)
	for relic_id in db.relic_order:
		if exclude.has(relic_id):
			continue
		roll -= int(weights.get(db.relics[relic_id]["rarity"], 0))
		if roll < 0:
			return relic_id
	return ""


static func _weighted_key(weights: Dictionary, rng: Rng32) -> String:
	var keys: Array = weights.keys()
	keys.sort()
	var total := 0
	for k: String in keys:
		total += int(weights[k])
	var roll := rng.next_below(maxi(1, total))
	for k: String in keys:
		roll -= int(weights[k])
		if roll < 0:
			return k
	return keys[0]


func _add_relic(relic_id: String, levels: int) -> void:
	if relic_id.is_empty() or not db.relics.has(relic_id):
		return
	var before := active_resonances()
	relics[relic_id] = int(relics.get(relic_id, 0)) + levels
	if not _result.relics_picked.has(relic_id):
		_result.relics_picked.append(relic_id)
	for res_id in active_resonances():
		if not before.has(res_id):
			history.append({"type": "resonance", "room": room, "resonance": res_id, "tails": tails()})
			if not _result.resonances.has(res_id):
				_result.resonances.append(res_id)
	_result.max_tails = maxi(_result.max_tails, tails())


func _stats_with_tails() -> Dictionary:
	var stats := base_stats.duplicate()
	stats["atk"] = Fx.bp(int(stats["atk"]), 10000 + tails() * int(run_cfg["tail_atk_bp"]))
	return stats


func _heal(amount_bp: int) -> void:
	hero_hp = mini(hero_max_hp, hero_hp + Fx.bp(hero_max_hp, amount_bp))


func _roll_loot() -> void:
	var drops: Dictionary = db.gear["drops"]
	var chance := 0
	if room_kind == "elite":
		chance = int(drops["elite_chance_bp"])
	elif room_kind == "boss":
		chance = 10000 if first_clear and drops.get("first_clear_guaranteed", false) else int(drops["boss_chance_bp"])
	if chance <= 0 or not _rng_loot.chance_bp(chance):
		return
	var weights := {}
	for r in db.gear_rarity_order:
		weights[r] = int(db.gear_rarities[r]["drop_weight"])
	var rarity := _weighted_key(weights, _rng_loot)
	var items: Array = db.gear_items.keys()
	items.sort()
	_result.gear_drops.append({"item": items[_rng_loot.next_below(items.size())], "rarity": rarity})


func _finish(won: bool) -> void:
	phase = Phase.FINISHED
	_result.won = won
	if not won:
		_result.death_room = room
	_result.relics = relics.duplicate()
	_result.hero_hp_end = hero_hp
	history.append({"type": "finished", "won": won, "room": room})

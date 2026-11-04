class_name Progression
extends RefCounted
## Permanent progression rules: hero stats, upgrade costs and purchases, gear,
## attunement, rewards, offline income and power rating. Pure functions over a
## PlayerProfile and ContentDB (data/progression.json, data/gear.json).

const OK := ""
const ERR_FUNDS := "insufficient_funds"
const ERR_MAX := "max_reached"
const ERR_UNKNOWN := "unknown"
const ERR_LOCKED := "locked"
const ERR_ALREADY := "already_applied"

var db: ContentDB
var cfg: Dictionary


func _init(content: ContentDB) -> void:
	db = content
	cfg = content.progression


static func curve_cost(curve: Dictionary, steps: int) -> int:
	return Fx.bp(int(curve["base"]), Fx.compound_bp(int(curve["growth_bp"]), steps))


# --- hero level ----------------------------------------------------------------

func max_level(profile: PlayerProfile) -> int:
	return int(cfg["hero"]["max_level_base"]) + int(cfg["hero"]["max_level_per_chapter"]) * profile.best_chapter


func level_cost(level: int) -> int:
	return curve_cost(cfg["hero"]["level_cost"], level - 1)


func level_up(profile: PlayerProfile) -> String:
	if profile.hero_level >= max_level(profile):
		return ERR_MAX
	if not profile.wallet.spend(Wallet.GOLD, level_cost(profile.hero_level), "hero_level"):
		return ERR_FUNDS
	profile.hero_level += 1
	return OK


# --- training ------------------------------------------------------------------

func training_def(id: String) -> Dictionary:
	for t: Dictionary in cfg["training"]:
		if t["id"] == id:
			return t
	return {}


func training_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for t: Dictionary in cfg["training"]:
		out.append(t["id"])
	return out


func training_cost(id: String, rank: int) -> int:
	var t := training_def(id)
	return curve_cost(t["cost"], rank) if not t.is_empty() else 0


func train(profile: PlayerProfile, id: String) -> String:
	var t := training_def(id)
	if t.is_empty():
		return ERR_UNKNOWN
	var rank := int(profile.training.get(id, 0))
	if rank >= int(t["max_rank"]):
		return ERR_MAX
	if not profile.wallet.spend(Wallet.GOLD, training_cost(id, rank), "training_" + id):
		return ERR_FUNDS
	profile.training[id] = rank + 1
	return OK


# --- relic attunement --------------------------------------------------------------

func attunement_cost(level: int) -> int:
	return curve_cost(cfg["attunement"]["cost"], level)


func attune(profile: PlayerProfile, relic_id: String) -> String:
	if not db.relics.has(relic_id):
		return ERR_UNKNOWN
	if not profile.codex_relics.has(relic_id):
		return ERR_LOCKED
	var level := int(profile.attunement.get(relic_id, 0))
	if level >= int(cfg["attunement"]["max_level"]):
		return ERR_MAX
	if not profile.wallet.spend(Wallet.SHARDS, attunement_cost(level), "attune_" + relic_id):
		return ERR_FUNDS
	profile.attunement[relic_id] = level + 1
	return OK


## Extra relic potency from attunement, in bp on top of 10000.
func attunement_bonus_bp(profile: PlayerProfile, relic_id: String) -> int:
	return int(profile.attunement.get(relic_id, 0)) * int(cfg["attunement"]["potency_per_level_bp"])


# --- gear ----------------------------------------------------------------------------

func add_gear(profile: PlayerProfile, item_id: String, rarity: String) -> int:
	if not db.gear_items.has(item_id) or not db.gear_rarities.has(rarity):
		return -1
	var uid := profile.next_gear_uid
	profile.next_gear_uid += 1
	profile.gear.append({"uid": uid, "item": item_id, "rarity": rarity, "enhance": 0})
	var slot: String = db.gear_items[item_id]["slot"]
	if not profile.equipped.has(slot):
		profile.equipped[slot] = uid
	return uid


func equip(profile: PlayerProfile, uid: int) -> String:
	var g := profile.gear_by_uid(uid)
	if g.is_empty():
		return ERR_UNKNOWN
	profile.equipped[db.gear_items[g["item"]]["slot"]] = uid
	return OK


func enhance_cost(level: int) -> int:
	return curve_cost(db.gear["enhance_cost"], level)


func enhance(profile: PlayerProfile, uid: int) -> String:
	var g := profile.gear_by_uid(uid)
	if g.is_empty():
		return ERR_UNKNOWN
	if int(g["enhance"]) >= int(db.gear_rarities[g["rarity"]]["max_enhance"]):
		return ERR_MAX
	if not profile.wallet.spend(Wallet.GOLD, enhance_cost(int(g["enhance"])), "gear_enhance"):
		return ERR_FUNDS
	g["enhance"] = int(g["enhance"]) + 1
	return OK


## Merges `merge_count` copies of the same item and rarity into one item of the
## next rarity. Keeps the highest enhancement (capped) and equips the result if
## any input was equipped.
func merge(profile: PlayerProfile, item_id: String, rarity: String) -> String:
	var order := db.gear_rarity_order
	var idx := order.find(rarity)
	if idx < 0 or not db.gear_items.has(item_id):
		return ERR_UNKNOWN
	if idx == order.size() - 1:
		return ERR_MAX
	var need := int(db.gear["merge_count"])
	var picks: Array[Dictionary] = []
	for g in profile.gear:
		if g["item"] == item_id and g["rarity"] == rarity and picks.size() < need:
			picks.append(g)
	if picks.size() < need:
		return ERR_FUNDS
	var next_rarity := order[idx + 1]
	var best_enhance := 0
	var was_equipped := false
	var slot: String = db.gear_items[item_id]["slot"]
	for g in picks:
		best_enhance = maxi(best_enhance, int(g["enhance"]))
		if int(profile.equipped.get(slot, -1)) == int(g["uid"]):
			was_equipped = true
		profile.gear.erase(g)
	if was_equipped:
		profile.equipped.erase(slot)
	var uid := add_gear(profile, item_id, next_rarity)
	profile.gear_by_uid(uid)["enhance"] = mini(best_enhance, int(db.gear_rarities[next_rarity]["max_enhance"]))
	if was_equipped:
		profile.equipped[slot] = uid
	return OK


func gear_stats(g: Dictionary) -> Dictionary:
	var item: Dictionary = db.gear_items[g["item"]]
	var mult := int(db.gear_rarities[g["rarity"]]["stat_mult_bp"])
	var enhance_bp := 10000 + int(g["enhance"]) * int(db.gear["enhance_per_level_bp"])
	var out := {}
	for key: String in item["stats"]:
		out[key] = Fx.bp(Fx.bp(int(item["stats"][key]), mult), enhance_bp)
	return out


# --- hero stats & power ----------------------------------------------------------------

## Final permanent stats for combat (before in-run tails and relics).
func hero_stats(profile: PlayerProfile) -> Dictionary:
	var base: Dictionary = db.heroes[profile.hero_id]["stats"]
	var level_mult := Fx.compound_bp(int(cfg["hero"]["level_stat_growth_bp"]), profile.hero_level - 1)
	var bonus := {"atk_pct_bp": 0, "hp_pct_bp": 0, "crit_bp": 0, "crit_dmg_bp": 0, "aps_bonus_bp": 0, "armor_bp": 0}
	for t: Dictionary in cfg["training"]:
		var rank := int(profile.training.get(t["id"], 0))
		for key in ["atk_pct_bp", "hp_pct_bp", "crit_bp", "crit_dmg_bp"]:
			if t.has(key):
				bonus[key] += rank * int(t[key])
	for slot: String in profile.equipped:
		var g := profile.gear_by_uid(int(profile.equipped[slot]))
		if g.is_empty():
			continue
		var gs := gear_stats(g)
		for key: String in gs:
			bonus[key] += int(gs[key])
	return {
		"hp": Fx.bp(Fx.bp(int(base["hp"]), level_mult), 10000 + bonus["hp_pct_bp"]),
		"atk": Fx.bp(Fx.bp(int(base["atk"]), level_mult), 10000 + bonus["atk_pct_bp"]),
		"aps_milli": Fx.bp(int(base["aps_milli"]), 10000 + bonus["aps_bonus_bp"]),
		"crit_bp": int(base["crit_bp"]) + bonus["crit_bp"],
		"crit_dmg_bp": int(base["crit_dmg_bp"]) + bonus["crit_dmg_bp"],
		"armor_bp": int(base["armor_bp"]) + bonus["armor_bp"],
	}


## Single number shown to players: sqrt(effective damage per second x effective hp) x 10.
static func power_of(stats: Dictionary) -> int:
	var crit := mini(int(stats["crit_bp"]), 7500)
	var dps_x1000 := Fx.bp(int(stats["atk"]) * int(stats["aps_milli"]), 10000 + Fx.bp(crit, int(stats["crit_dmg_bp"]) - 10000))
	var ehp := int(stats["hp"]) * 10000 / maxi(1, 10000 - clampi(int(stats["armor_bp"]), 0, 6000))
	return int(sqrt(float(dps_x1000) * float(ehp) / 1000.0) * 10.0)


func power(profile: PlayerProfile) -> int:
	return power_of(hero_stats(profile))


## Power at which a chapter is comfortable without lucky drafts.
func recommended_power(chapter: int) -> int:
	var base_stats: Dictionary = db.heroes[db.heroes.keys()[0]]["stats"]
	return Fx.bp(power_of(base_stats), Fx.compound_bp(int(cfg["power"]["chapter_growth_bp"]), chapter - 1))


func can_start(profile: PlayerProfile, chapter: int) -> bool:
	return chapter >= 1 and chapter <= profile.best_chapter + 1


# --- rewards ------------------------------------------------------------------------

## Gold for clearing one room. kind: fight | elite | boss. replay pays less.
func room_gold(chapter: int, kind: String, replay: bool) -> int:
	var r: Dictionary = cfg["rewards"]
	var gold := Fx.bp(int(r["gold_per_room"]) * 100, Fx.compound_bp(int(r["gold_growth_bp"]), chapter - 1))
	match kind:
		"elite":
			gold = Fx.bp(gold, int(r["elite_gold_bp"]))
		"boss":
			gold = Fx.bp(gold, int(r["boss_gold_bp"]))
	if replay:
		gold = Fx.bp(gold, int(r["replay_gold_bp"]))
	@warning_ignore("integer_division")
	return maxi(1, gold / 100)


func shards_per_room(chapter: int) -> int:
	var r: Dictionary = cfg["rewards"]
	return maxi(1, Fx.bp(int(r["shards_per_room"]), 10000 + (chapter - 1) * int(r["shards_chapter_bonus_bp"])))


## Gold of one full replay of the best cleared chapter (chapter 1 if none).
func farm_gold_per_run(profile: PlayerProfile) -> int:
	var ch := maxi(1, profile.best_chapter)
	var rooms := int(cfg["run"]["rooms"])
	var total := room_gold(ch, "elite", true) + room_gold(ch, "boss", true)
	total += room_gold(ch, "fight", true) * (rooms - 2)
	return total


func farm_gold_per_minute(profile: PlayerProfile) -> int:
	@warning_ignore("integer_division")
	return farm_gold_per_run(profile) * 10 / int(cfg["run"]["minutes_per_full_run_x10"])


## Offline income since last_seen. Clock going backwards grants nothing.
## Returns {minutes, gold}; the caller then sets last_seen_unix = now.
func offline_reward(profile: PlayerProfile, now_unix: int) -> Dictionary:
	if profile.last_seen_unix <= 0 or now_unix <= profile.last_seen_unix:
		return {"minutes": 0, "gold": 0}
	@warning_ignore("integer_division")
	var minutes := mini((now_unix - profile.last_seen_unix) / 60, int(cfg["offline"]["cap_minutes"]))
	var gold := Fx.bp(farm_gold_per_minute(profile) * minutes, int(cfg["offline"]["farm_rate_bp"]))
	return {"minutes": minutes, "gold": gold}


func claim_offline(profile: PlayerProfile, now_unix: int) -> Dictionary:
	var reward := offline_reward(profile, now_unix)
	if int(reward["gold"]) > 0:
		profile.wallet.add(Wallet.GOLD, reward["gold"], "offline")
	profile.last_seen_unix = now_unix
	return reward


## Gold bought by a Gold Cache: one hour of farming at the best chapter.
func gold_cache_amount(profile: PlayerProfile) -> int:
	return farm_gold_per_minute(profile) * 60


## Applies an expedition's rewards exactly once.
func apply_run_result(profile: PlayerProfile, result: RunResult) -> String:
	if result.run_id.is_empty() or profile.applied_runs.has(result.run_id):
		return ERR_ALREADY
	profile.applied_runs.append(result.run_id)
	if profile.applied_runs.size() > PlayerProfile.APPLIED_RUNS_CAP:
		profile.applied_runs = profile.applied_runs.slice(profile.applied_runs.size() - PlayerProfile.APPLIED_RUNS_CAP)
	var r: Dictionary = cfg["rewards"]
	profile.bump("runs")
	if result.gold > 0:
		profile.wallet.add(Wallet.GOLD, result.gold, "run_gold")
	if result.shards > 0:
		profile.wallet.add(Wallet.SHARDS, result.shards, "run_shards")
	for drop in result.gear_drops:
		add_gear(profile, drop["item"], drop["rarity"])
	for relic_id in result.relics_picked:
		if db.relics.has(relic_id) and not profile.codex_relics.has(relic_id):
			profile.codex_relics.append(relic_id)
			profile.wallet.add(Wallet.GEMS, int(r["relic_discovery_gems"]), "codex_relic")
	for res_id in result.resonances:
		if db.resonances.has(res_id) and not profile.codex_resonances.has(res_id):
			profile.codex_resonances.append(res_id)
			profile.wallet.add(Wallet.GEMS, int(r["resonance_discovery_gems"]), "codex_resonance")
	if result.echo_used != "" and profile.echo_relic == result.echo_used:
		profile.echo_relic = ""
	if result.won:
		profile.bump("wins")
		var key := str(result.chapter)
		profile.chapter_clears[key] = int(profile.chapter_clears.get(key, 0)) + 1
		if result.chapter > profile.best_chapter:
			profile.best_chapter = result.chapter
			profile.wallet.add(Wallet.GEMS, int(r["first_clear_gems"]), "first_clear")
		profile.echo_options = PackedStringArray()
	else:
		profile.bump("losses")
		profile.echo_options = PackedStringArray(result.relics.keys())
	return OK


## After a defeat the player may keep one relic of that run for the next one.
func choose_echo(profile: PlayerProfile, relic_id: String) -> String:
	if not profile.echo_options.has(relic_id):
		return ERR_UNKNOWN
	profile.echo_relic = relic_id
	profile.echo_options = PackedStringArray()
	return OK

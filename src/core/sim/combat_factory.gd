class_name CombatFactory
extends RefCounted
## Builds Combatants from content definitions. The single place where relic
## levels, resonances and enemy scaling are turned into runtime numbers.

## Action fields scaled by potency (relic level / attunement).
const SCALED_FIELDS: PackedStringArray = ["mult_bp", "pct_max_hp_bp"]

var db: ContentDB
var cfg: SimConfig


func _init(content: ContentDB) -> void:
	db = content
	cfg = SimConfig.from_balance(content.balance)


## relic_levels: ordered {relic_id: level}. stats_override replaces base stats
## (used by permanent progression). current_hp < 0 means full health.
## attunement_bp: {relic_id: extra potency in bp} from permanent attunement.
func make_hero(hero_id: String, relic_levels: Dictionary = {}, stats_override: Dictionary = {},
		current_hp: int = -1, attunement_bp: Dictionary = {}) -> Combatant:
	var def: Dictionary = db.heroes[hero_id]
	var stats: Dictionary = (def["stats"] as Dictionary).duplicate()
	stats.merge(stats_override, true)
	var c := Combatant.new()
	c.team = Combatant.TEAM_HERO
	c.def_id = hero_id
	_apply_stats(c, stats)
	if current_hp >= 0:
		c.hp = clampi(current_hp, 1, c.max_hp)
	var relic_ids: PackedStringArray = []
	for relic_id: String in relic_levels:
		if not db.relics.has(relic_id):
			push_error("unknown relic '%s'" % relic_id)
			continue
		relic_ids.append(relic_id)
		var potency := 10000 + (maxi(1, int(relic_levels[relic_id])) - 1) * cfg.relic_level_bonus_bp
		potency = Fx.bp(potency, 10000 + int(attunement_bp.get(relic_id, 0)))
		for raw: Dictionary in db.relics[relic_id]["effects"]:
			c.effects.append(compile_effect(raw, potency, relic_id, "relic", c.effects.size()))
	c.resonances = db.active_resonances(relic_ids)
	for res_id in c.resonances:
		for raw: Dictionary in db.resonances[res_id]["effects"]:
			c.effects.append(compile_effect(raw, 10000, res_id, "resonance", c.effects.size()))
	return c


func make_enemy(enemy_id: String, chapter: int = 1, room: int = 1) -> Combatant:
	var def: Dictionary = db.enemies[enemy_id]
	var stats: Dictionary = (def["stats"] as Dictionary).duplicate()
	var scale := enemy_scale_bp(chapter, room)
	stats["hp"] = maxi(1, Fx.bp(stats["hp"], scale))
	stats["atk"] = maxi(1, Fx.bp(stats["atk"], scale))
	var c := Combatant.new()
	c.team = Combatant.TEAM_ENEMY
	c.def_id = enemy_id
	_apply_stats(c, stats)
	for raw: Dictionary in def.get("effects", []):
		c.effects.append(compile_effect(raw, 10000, enemy_id, "ability", c.effects.size()))
	return c


## Stat multiplier for an enemy in a chapter and room, in basis points.
func enemy_scale_bp(chapter: int, room: int) -> int:
	var chapter_scale := Fx.compound_bp(cfg.chapter_growth_bp, chapter - 1)
	return Fx.bp(chapter_scale, 10000 + cfg.room_bonus_bp * (maxi(room, 1) - 1))


func compile_effect(raw: Dictionary, potency_bp: int, source_id: String, source_kind: String, index: int) -> Dictionary:
	var eff: Dictionary = raw.duplicate(true)
	eff["source_id"] = source_id
	eff["source_kind"] = source_kind
	eff["index"] = index
	if eff["trigger"] == "every_seconds":
		eff["every_ticks"] = cfg.sec_to_ticks(float(eff["seconds"]))
	var action: Dictionary = eff["action"]
	if not action.has("target"):
		action["target"] = "target"
	if potency_bp != 10000:
		for field in SCALED_FIELDS:
			if action.has(field):
				action[field] = Fx.bp(action[field], potency_bp)
		if action["type"] == "modify_stat" and action.get("scales", true):
			action["add"] = Fx.bp(action["add"], potency_bp)
	return eff


static func _apply_stats(c: Combatant, stats: Dictionary) -> void:
	c.max_hp = maxi(1, int(stats["hp"]))
	c.hp = c.max_hp
	c.atk = int(stats["atk"])
	c.aps_milli = int(stats["aps_milli"])
	c.armor_bp = int(stats.get("armor_bp", 0))
	c.crit_bp = int(stats.get("crit_bp", 0))
	c.crit_dmg_bp = int(stats.get("crit_dmg_bp", 15000))

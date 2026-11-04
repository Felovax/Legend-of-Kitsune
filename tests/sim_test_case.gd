class_name SimTestCase
extends TestCase
## Helpers for battle tests: hand-built units with exact stats, plus the real content.

static var _db: ContentDB = null

var db: ContentDB
var factory: CombatFactory


func before_each() -> void:
	if _db == null:
		_db = ContentDB.load_from_dir()
	db = _db
	factory = CombatFactory.new(db)


## A fighter with exact stats and no effects.
func unit(team: int, hp: int, atk: int, aps_milli: int = 1000, extra: Dictionary = {}) -> Combatant:
	var c := Combatant.new()
	c.team = team
	c.def_id = "test_%d" % team
	c.max_hp = hp
	c.hp = hp
	c.atk = atk
	c.aps_milli = aps_milli
	c.crit_bp = 0
	for key: String in extra:
		c.set(key, extra[key])
	return c


func hero(hp: int = 1000, atk: int = 10, aps_milli: int = 1000, extra: Dictionary = {}) -> Combatant:
	return unit(Combatant.TEAM_HERO, hp, atk, aps_milli, extra)


## An enemy that never hurts anyone (atk 0 deals no damage).
func dummy(hp: int = 100000, extra: Dictionary = {}) -> Combatant:
	return unit(Combatant.TEAM_ENEMY, hp, 0, 1000, extra)


func add_effect(c: Combatant, raw: Dictionary, potency_bp: int = 10000, source_id: String = "test") -> void:
	c.effects.append(factory.compile_effect(raw, potency_bp, source_id, "relic", c.effects.size()))


func battle(units_list: Array, seed_value: int = 1, max_seconds: int = -1) -> BattleResult:
	var cfg := SimConfig.from_balance(db.balance)
	if max_seconds > 0:
		cfg.max_ticks = max_seconds * cfg.tps
	var sim := BattleSim.new(cfg, seed_value)
	for u: Combatant in units_list:
		sim.add_unit(u)
	return sim.run()


func damage_events(result: BattleResult, where: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in result.events:
		if e["type"] == "damage" and BattleResult._matches(e, where):
			out.append(e)
	return out

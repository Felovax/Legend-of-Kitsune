class_name SimConfig
extends RefCounted
## Typed, integer view of data/balance.json used by the battle simulation.

var tps: int = 20
var max_ticks: int = 1200
var gauge_full: int = 20000
var start_gauge: int = 10000
var armor_cap_bp: int = 6000
var crit_cap_bp: int = 7500
var relic_level_bonus_bp: int = 5000
var max_trigger_depth: int = 3

var burn_max_stacks: int = 5
var burn_ticks: int = 60
var burn_dps_per_stack_bp: int = 2000

var chill_max_stacks: int = 5
var chill_ticks: int = 80
var chill_penalty_bp: int = 1000
var freeze_ticks: int = 30
var freeze_immunity_ticks: int = 60

var shock_bonus_bp: int = 3000

var chapter_growth_bp: int = 14000
var room_bonus_bp: int = 600


static func from_balance(balance: Dictionary) -> SimConfig:
	var c := SimConfig.new()
	var sim: Dictionary = balance["sim"]
	c.tps = sim["ticks_per_second"]
	c.max_ticks = int(sim["max_battle_seconds"]) * c.tps
	c.gauge_full = c.tps * 1000
	c.start_gauge = Fx.bp(c.gauge_full, sim["start_gauge_bp"])
	c.armor_cap_bp = sim["armor_cap_bp"]
	c.crit_cap_bp = sim["crit_cap_bp"]
	c.relic_level_bonus_bp = sim["relic_level_bonus_bp"]
	c.max_trigger_depth = sim["max_trigger_depth"]
	var burn: Dictionary = balance["status"]["burn"]
	c.burn_max_stacks = burn["max_stacks"]
	c.burn_ticks = c.sec_to_ticks(burn["duration_s"])
	c.burn_dps_per_stack_bp = burn["dps_per_stack_bp"]
	var chill: Dictionary = balance["status"]["chill"]
	c.chill_max_stacks = chill["max_stacks"]
	c.chill_ticks = c.sec_to_ticks(chill["duration_s"])
	c.chill_penalty_bp = chill["aps_penalty_per_stack_bp"]
	c.freeze_ticks = c.sec_to_ticks(chill["freeze_s"])
	c.freeze_immunity_ticks = c.sec_to_ticks(chill["freeze_immunity_s"])
	c.shock_bonus_bp = balance["status"]["shock"]["bonus_bp"]
	c.chapter_growth_bp = balance["enemy_scaling"]["chapter_growth_bp"]
	c.room_bonus_bp = balance["enemy_scaling"]["room_bonus_bp"]
	return c


func sec_to_ticks(seconds: float) -> int:
	return maxi(1, int(roundf(seconds * tps)))

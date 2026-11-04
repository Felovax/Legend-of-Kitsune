class_name Combatant
extends RefCounted
## One fighter in a battle. Pure data; all rules live in BattleSim.

const TEAM_HERO := 0
const TEAM_ENEMY := 1

var uid: int = -1
var team: int = TEAM_HERO
var def_id: String = ""

var max_hp: int = 1
var hp: int = 1
var atk: int = 0
var armor_bp: int = 0
var crit_bp: int = 0
var crit_dmg_bp: int = 15000
var aps_milli: int = 1000
var aps_bonus_bp: int = 0
var lifesteal_bp: int = 0
var chain_targets: int = 0
var chain_ratio_bp: int = 0
var shield: int = 0

var gauge: int = 0
var attack_count: int = 0

var burn_stacks: int = 0
var burn_ticks: int = 0
var burn_dps_per_stack: int = 0
var burn_source: int = -1
var chill_stacks: int = 0
var chill_ticks: int = 0
var frozen_ticks: int = 0
var freeze_immune_ticks: int = 0
var shocked: bool = false
## Tick a status was last (re)applied; timers do not count down on that tick,
## so a status lasts exactly its full duration.
var burn_applied_tick: int = -1
var chill_applied_tick: int = -1
var frozen_applied_tick: int = -1

## Compiled effects (see CombatFactory.compile_effect).
var effects: Array[Dictionary] = []
## Indices of once-per-fight effects that already fired.
var fired_once: Dictionary = {}
## Active resonance ids (hero only), for UI and analytics.
var resonances: PackedStringArray = []


func is_alive() -> bool:
	return hp > 0


func is_frozen() -> bool:
	return frozen_ticks > 0


func has_status(status: String) -> bool:
	match status:
		"burn":
			return burn_stacks > 0
		"chill":
			return chill_stacks > 0
		"freeze":
			return frozen_ticks > 0
		"shock":
			return shocked
	return false

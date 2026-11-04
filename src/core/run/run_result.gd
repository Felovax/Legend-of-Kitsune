class_name RunResult
extends RefCounted
## What an expedition produced. Applied to the profile exactly once
## (Progression.apply_run_result checks run_id).

var run_id: String = ""
var chapter: int = 1
var won: bool = false
var rooms_cleared: int = 0
var first_clear: bool = false
var gold: int = 0
var shards: int = 0
## Gear drops: {item: String, rarity: String}
var gear_drops: Array[Dictionary] = []
## Final relics of the run, ordered: id -> level
var relics: Dictionary = {}
## Every relic picked during the run (for the Codex).
var relics_picked: PackedStringArray = []
## Resonances that were active at any point.
var resonances: PackedStringArray = []
var max_tails: int = 0
var echo_used: String = ""
var battle_ticks: int = 0
var battles: int = 0
var hero_hp_end: int = 0
var death_room: int = 0


## Approximate real play time in seconds at the given battle speed, plus
## menu time per room. Used by simulations.
func play_seconds(tps: int, speed: int = 2, seconds_per_room: int = 6) -> int:
	@warning_ignore("integer_division")
	return battle_ticks / maxi(1, tps * speed) + (rooms_cleared + (0 if won else 1)) * seconds_per_room


func to_dict() -> Dictionary:
	return {"run_id": run_id, "chapter": chapter, "won": won, "rooms_cleared": rooms_cleared,
		"first_clear": first_clear, "gold": gold, "shards": shards, "gear_drops": gear_drops.duplicate(true),
		"relics": relics.duplicate(), "resonances": Array(resonances), "max_tails": max_tails,
		"echo_used": echo_used, "battles": battles, "battle_ticks": battle_ticks, "death_room": death_room}

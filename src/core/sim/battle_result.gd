class_name BattleResult
extends RefCounted
## Outcome of one battle plus the full event log the UI replays.

const WIN := 0
const LOSS := 1
const TIMEOUT := 2

var outcome: int = LOSS
var ticks: int = 0
var hero_hp: int = 0
var hero_max_hp: int = 0
var hero_shield: int = 0
var events: Array[Dictionary] = []


func hero_won() -> bool:
	return outcome == WIN


## Stable fingerprint of the whole fight, used by determinism tests.
func log_hash() -> String:
	return JSON.stringify(events).md5_text()


## Number of events of a type whose fields match every entry in where.
func count(type: String, where: Dictionary = {}) -> int:
	var n := 0
	for e in events:
		if e["type"] == type and _matches(e, where):
			n += 1
	return n


## Sum of a numeric field over matching events.
func total(type: String, field: String, where: Dictionary = {}) -> int:
	var sum := 0
	for e in events:
		if e["type"] == type and _matches(e, where):
			sum += int(e.get(field, 0))
	return sum


func first(type: String, where: Dictionary = {}) -> Dictionary:
	for e in events:
		if e["type"] == type and _matches(e, where):
			return e
	return {}


static func _matches(e: Dictionary, where: Dictionary) -> bool:
	for k: Variant in where:
		if not e.has(k) or e[k] != where[k]:
			return false
	return true

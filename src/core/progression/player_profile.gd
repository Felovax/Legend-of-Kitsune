class_name PlayerProfile
extends RefCounted
## All persistent player progress. Plain data plus (de)serialization; the rules
## that change it live in Progression.

const APPLIED_RUNS_CAP := 50

var hero_id: String = "kitsune"
var hero_level: int = 1
## training id -> rank
var training: Dictionary = {}
## relic id -> attunement level (absent = 0)
var attunement: Dictionary = {}
var wallet: Wallet = Wallet.new()
## Owned gear: {uid: int, item: String, rarity: String, enhance: int}
var gear: Array[Dictionary] = []
## slot -> gear uid
var equipped: Dictionary = {}
var next_gear_uid: int = 1
## Highest chapter cleared (0 = none).
var best_chapter: int = 0
## chapter number as String -> clear count
var chapter_clears: Dictionary = {}
var codex_relics: PackedStringArray = []
var codex_resonances: PackedStringArray = []
## Echo Keepsake: relic to start the next expedition with ("" = none).
var echo_relic: String = ""
## Relics the player may choose as Echo after a defeat.
var echo_options: PackedStringArray = []
## Ids of run results already applied (prevents double rewards).
var applied_runs: PackedStringArray = []
## Per-install random base for run seeds; set once by the game service.
var seed_base: int = 0
var run_counter: int = 0
## Unix time of the last offline-reward claim / session end (set by services).
var last_seen_unix: int = 0
## Simple counters (runs, wins, losses, ...).
var counters: Dictionary = {}


func gear_by_uid(uid: int) -> Dictionary:
	for g in gear:
		if int(g["uid"]) == uid:
			return g
	return {}


func bump(counter: String, amount: int = 1) -> void:
	counters[counter] = int(counters.get(counter, 0)) + amount


func to_dict() -> Dictionary:
	return {
		"hero_id": hero_id,
		"hero_level": hero_level,
		"training": training.duplicate(),
		"attunement": attunement.duplicate(),
		"wallet": wallet.to_dict(),
		"gear": gear.duplicate(true),
		"equipped": equipped.duplicate(),
		"next_gear_uid": next_gear_uid,
		"best_chapter": best_chapter,
		"chapter_clears": chapter_clears.duplicate(),
		"codex_relics": Array(codex_relics),
		"codex_resonances": Array(codex_resonances),
		"echo_relic": echo_relic,
		"echo_options": Array(echo_options),
		"applied_runs": Array(applied_runs),
		"seed_base": seed_base,
		"run_counter": run_counter,
		"last_seen_unix": last_seen_unix,
		"counters": counters.duplicate(),
	}


static func from_dict(d: Dictionary) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.hero_id = str(d.get("hero_id", "kitsune"))
	p.hero_level = maxi(1, int(d.get("hero_level", 1)))
	p.training = _int_values(d.get("training", {}))
	p.attunement = _int_values(d.get("attunement", {}))
	p.wallet = Wallet.from_dict(d.get("wallet", {}))
	for g: Variant in d.get("gear", []):
		if g is Dictionary:
			p.gear.append({"uid": int(g["uid"]), "item": str(g["item"]), "rarity": str(g["rarity"]),
				"enhance": int(g.get("enhance", 0))})
	for slot: Variant in d.get("equipped", {}):
		p.equipped[str(slot)] = int(d["equipped"][slot])
	p.next_gear_uid = maxi(1, int(d.get("next_gear_uid", 1)))
	p.best_chapter = maxi(0, int(d.get("best_chapter", 0)))
	p.chapter_clears = _int_values(d.get("chapter_clears", {}))
	p.codex_relics = PackedStringArray(d.get("codex_relics", []))
	p.codex_resonances = PackedStringArray(d.get("codex_resonances", []))
	p.echo_relic = str(d.get("echo_relic", ""))
	p.echo_options = PackedStringArray(d.get("echo_options", []))
	p.applied_runs = PackedStringArray(d.get("applied_runs", []))
	p.seed_base = int(d.get("seed_base", 0))
	p.run_counter = maxi(0, int(d.get("run_counter", 0)))
	p.last_seen_unix = int(d.get("last_seen_unix", 0))
	p.counters = _int_values(d.get("counters", {}))
	return p


static func _int_values(v: Variant) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k: Variant in v:
			out[str(k)] = int(v[k])
	return out

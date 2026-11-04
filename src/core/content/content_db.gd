class_name ContentDB
extends RefCounted
## Loads, validates and indexes game content from res://data/*.json.
## Integral JSON numbers are converted to int so game logic stays in integer math.

const DATA_DIR := "res://data"
const FILES: PackedStringArray = ["balance", "heroes", "enemies", "relics", "resonances"]

var balance: Dictionary = {}
var heroes: Dictionary = {}
var enemies: Dictionary = {}
var relics: Dictionary = {}
var resonances: Dictionary = {}
## Resonance ids in file order, so activation order is stable.
var resonance_order: PackedStringArray = []
var errors: PackedStringArray = []


static func load_from_dir(dir: String = DATA_DIR) -> ContentDB:
	var data := {}
	var load_errors: PackedStringArray = []
	for name in FILES:
		var path := dir.path_join(name + ".json")
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			load_errors.append("%s: missing or empty" % path)
			continue
		var json := JSON.new()
		if json.parse(text) != OK:
			load_errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
			continue
		var parsed: Variant = json.data
		if name == "balance":
			data["balance"] = parsed
		elif parsed is Dictionary:
			data[name] = (parsed as Dictionary).get(name, null)
	var db := from_data(data)
	load_errors.append_array(db.errors)
	db.errors = load_errors
	return db


## Builds a database from already-parsed data:
## { balance: {...}, heroes: [...], enemies: [...], relics: [...], resonances: [...] }
static func from_data(raw: Dictionary) -> ContentDB:
	var db := ContentDB.new()
	var data: Dictionary = normalize(raw)
	db.errors = ContentValidator.validate(data)
	if not db.errors.is_empty():
		return db
	db.balance = data["balance"]
	for h: Dictionary in data["heroes"]:
		db.heroes[h["id"]] = h
	for e: Dictionary in data["enemies"]:
		db.enemies[e["id"]] = e
	for r: Dictionary in data["relics"]:
		db.relics[r["id"]] = r
	for r: Dictionary in data["resonances"]:
		db.resonances[r["id"]] = r
		db.resonance_order.append(r["id"])
	return db


func is_valid() -> bool:
	return errors.is_empty()


## Union of tags carried by the given relics.
func tags_of(relic_ids: PackedStringArray) -> PackedStringArray:
	var tags: PackedStringArray = []
	for id in relic_ids:
		if not relics.has(id):
			continue
		for t: String in relics[id]["tags"]:
			if not tags.has(t):
				tags.append(t)
	return tags


## Resonances whose required tags are all present among the relics.
func active_resonances(relic_ids: PackedStringArray) -> PackedStringArray:
	var tags := tags_of(relic_ids)
	var out: PackedStringArray = []
	for id in resonance_order:
		var ok := true
		for t: String in resonances[id]["requires_tags"]:
			if not tags.has(t):
				ok = false
				break
		if ok:
			out.append(id)
	return out


## Deep copy with integral floats turned into ints (JSON has no int type).
static func normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for k: Variant in value:
			out[k] = normalize(value[k])
		return out
	if value is Array:
		var arr := []
		for item: Variant in value:
			arr.append(normalize(item))
		return arr
	if typeof(value) == TYPE_FLOAT and is_equal_approx(value, roundf(value)) and absf(value) < 9.0e15:
		return int(roundf(value))
	return value

class_name ContentDB
extends RefCounted
## Loads, validates and indexes game content from res://data/*.json.
## Integral JSON numbers are converted to int so game logic stays in integer math.

const DATA_DIR := "res://data"
## Combat content: always required.
const FILES: PackedStringArray = ["balance", "heroes", "enemies", "relics", "resonances"]
## Meta-game content: validated when present (the game needs all of them;
## combat-only fixtures may omit them).
const META_FILES: PackedStringArray = ["progression", "gear", "chapters", "events", "shop"]
## Files whose top level is the object itself (others wrap a list under their name).
const WHOLE_FILES: PackedStringArray = ["balance", "progression", "gear", "chapters", "shop"]

var balance: Dictionary = {}
var heroes: Dictionary = {}
var enemies: Dictionary = {}
var relics: Dictionary = {}
var resonances: Dictionary = {}
## Resonance ids in file order, so activation order is stable.
var resonance_order: PackedStringArray = []
## Relic ids sorted, for stable draft pools.
var relic_order: PackedStringArray = []

var progression: Dictionary = {}
var gear: Dictionary = {}
var gear_items: Dictionary = {}
var gear_rarities: Dictionary = {}
var gear_rarity_order: PackedStringArray = []
## chapter number (int) -> chapter definition
var chapters: Dictionary = {}
var group_sizes: Array = []
var events: Dictionary = {}
var event_order: PackedStringArray = []
## data/shop.json (products, gem offers, charter, ledger)
var shop: Dictionary = {}

var errors: PackedStringArray = []


static func load_from_dir(dir: String = DATA_DIR) -> ContentDB:
	var data := {}
	var load_errors: PackedStringArray = []
	for name in FILES + META_FILES:
		var path := dir.path_join(name + ".json")
		if not FileAccess.file_exists(path):
			if FILES.has(name):
				load_errors.append("%s: missing" % path)
			continue
		var text := FileAccess.get_file_as_string(path)
		var json := JSON.new()
		if text.is_empty() or json.parse(text) != OK:
			load_errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
			continue
		var parsed: Variant = json.data
		if WHOLE_FILES.has(name):
			data[name] = parsed
		elif parsed is Dictionary:
			data[name] = (parsed as Dictionary).get(name, null)
	var db := from_data(data)
	load_errors.append_array(db.errors)
	db.errors = load_errors
	return db


## True when every meta-game file was present and loaded.
func has_meta_content() -> bool:
	return not progression.is_empty() and not gear.is_empty() and not chapters.is_empty() and not events.is_empty() \
		and not shop.is_empty()


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
	db.relic_order = PackedStringArray(db.relics.keys())
	db.relic_order.sort()
	if data.get("progression") is Dictionary:
		db.progression = data["progression"]
	if data.get("gear") is Dictionary:
		db.gear = data["gear"]
		for item: Dictionary in db.gear["items"]:
			db.gear_items[item["id"]] = item
		for rarity: Dictionary in db.gear["rarities"]:
			db.gear_rarities[rarity["id"]] = rarity
			db.gear_rarity_order.append(rarity["id"])
	if data.get("chapters") is Dictionary:
		db.group_sizes = data["chapters"]["group_sizes"]
		for ch: Dictionary in data["chapters"]["chapters"]:
			db.chapters[int(ch["number"])] = ch
	if data.get("shop") is Dictionary:
		db.shop = data["shop"]
	if data.get("events") is Array:
		for ev: Dictionary in data["events"]:
			db.events[ev["id"]] = ev
			db.event_order.append(ev["id"])
	return db


## Chapter definition; numbers beyond the last defined chapter reuse the last
## one (stats still scale by number), so simulations can probe deep chapters.
func chapter_def(number: int) -> Dictionary:
	if chapters.has(number):
		return chapters[number]
	var last := 0
	for n: int in chapters:
		last = maxi(last, n)
	return chapters.get(last, {})


func max_chapter() -> int:
	var last := 0
	for n: int in chapters:
		last = maxi(last, n)
	return last


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

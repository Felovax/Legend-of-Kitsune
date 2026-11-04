extends TestCase
## Every text key referenced by content data has an English string.


func _keys() -> Dictionary:
	var keys := {}
	var f := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
	var header := f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 2 and row[0] != "":
			keys[row[0]] = row[1]
	assert_eq(Array(header), ["keys", "en"])
	return keys


func test_content_names_and_descriptions_exist() -> void:
	var keys := _keys()
	var db := ContentDB.load_from_dir()
	var missing: PackedStringArray = []
	var need: PackedStringArray = []
	for d: Dictionary in db.heroes.values() + db.enemies.values() + db.gear_items.values():
		need.append(d["name_key"])
	for d: Dictionary in db.relics.values() + db.resonances.values():
		need.append(d["name_key"])
		need.append(d["name_key"] + "_DESC")
	for d: Dictionary in db.chapters.values():
		need.append(d["name_key"])
	for t: Dictionary in db.progression["training"]:
		need.append(t["name_key"])
	for ev: Dictionary in db.events.values():
		need.append(ev["name_key"])
		need.append(ev["name_key"] + "_DESC")
		for o: Dictionary in ev["options"]:
			need.append(o["text_key"])
	for k in need:
		if not keys.has(k) or String(keys[k]).is_empty():
			missing.append(k)
	assert_true(missing.is_empty(), "missing strings: " + ", ".join(missing))


func test_translation_is_registered() -> void:
	assert_eq(TranslationServer.translate("RELIC_EMBER_STONE"), "Ember Stone")
	assert_eq(TranslationServer.translate("EVENT_CURSED_ALTAR_ACCEPT"), "Accept (lose 20% HP, upgrade a relic)")

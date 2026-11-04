extends TestCase


func _data() -> Dictionary:
	var data := {}
	for name in ContentDB.FILES:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % name))
		data[name] = parsed if name == "balance" else parsed[name]
	return data


func _errors_for(data: Dictionary) -> String:
	return " | ".join(ContentDB.from_data(data).errors)


func test_shipped_content_is_valid() -> void:
	var db := ContentDB.load_from_dir()
	assert_true(db.is_valid(), " | ".join(db.errors))


func test_json_numbers_become_ints() -> void:
	var db := ContentDB.load_from_dir()
	assert_eq(typeof(db.heroes["kitsune"]["stats"]["hp"]), TYPE_INT)
	assert_eq(typeof(db.balance["status"]["chill"]["freeze_s"]), TYPE_FLOAT, "1.5 stays a float")


func test_duplicate_id_is_rejected() -> void:
	var data := _data()
	(data["relics"] as Array).append((data["relics"] as Array)[0].duplicate(true))
	assert_has(_errors_for(data), "duplicate id")


func test_bad_id_format_is_rejected() -> void:
	var data := _data()
	data["relics"][0]["id"] = "Ember Stone"
	assert_has(_errors_for(data), "lower_snake_case")


func test_unknown_trigger_is_rejected() -> void:
	var data := _data()
	data["relics"][0]["effects"][0]["trigger"] = "on_sneeze"
	assert_has(_errors_for(data), "unknown trigger 'on_sneeze'")


func test_unknown_status_is_rejected() -> void:
	var data := _data()
	data["relics"][0]["effects"][0]["action"]["status"] = "brn"
	assert_has(_errors_for(data), "unknown status 'brn'")


func test_unknown_action_is_rejected() -> void:
	var data := _data()
	data["relics"][0]["effects"][0]["action"]["type"] = "explode"
	assert_has(_errors_for(data), "unknown action 'explode'")


func test_relic_without_tags_is_rejected() -> void:
	var data := _data()
	data["relics"][0]["tags"] = []
	assert_has(_errors_for(data), "tags: must be a non-empty list")


func test_resonance_needs_tags_that_exist() -> void:
	var data := _data()
	data["resonances"][0]["requires_tags"] = ["ember", "plasma"]
	assert_has(_errors_for(data), "no relic has tag 'plasma'")


func test_passive_must_be_stat_change() -> void:
	var data := _data()
	data["relics"][3]["effects"][0]["action"] = {"type": "damage", "target": "target", "mult_bp": 100}
	assert_has(_errors_for(data), "passive effects may only use modify_stat")


func test_every_n_attacks_needs_n() -> void:
	var data := _data()
	(data["relics"][2]["effects"][0] as Dictionary).erase("n")
	assert_has(_errors_for(data), ".n: must be an integer")


func test_enemy_needs_positive_hp() -> void:
	var data := _data()
	data["enemies"][0]["stats"]["hp"] = 0
	assert_has(_errors_for(data), "stats.hp: must be >= 1")


func test_missing_balance_section_is_rejected() -> void:
	var data := _data()
	(data["balance"] as Dictionary).erase("status")
	assert_has(_errors_for(data), "balance.status: missing")


func test_invalid_content_produces_no_lookup_tables() -> void:
	var data := _data()
	data["relics"][0]["rarity"] = "mythic"
	var db := ContentDB.from_data(data)
	assert_false(db.is_valid())
	assert_eq(db.relics.size(), 0)

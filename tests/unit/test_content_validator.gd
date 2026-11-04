extends TestCase


func _data() -> Dictionary:
	var data := {}
	for name in ContentDB.FILES + ContentDB.META_FILES:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % name))
		data[name] = parsed if ContentDB.WHOLE_FILES.has(name) else parsed[name]
	return data


func test_shipped_content_includes_meta_files() -> void:
	assert_true(ContentDB.load_from_dir().has_meta_content())


func test_unknown_door_kind_is_rejected() -> void:
	var data := _data()
	data["progression"]["run"]["door_weights"]["casino"] = 5
	assert_has(_errors_for(data), "unknown door 'casino'")


func test_elite_room_must_come_before_boss() -> void:
	var data := _data()
	data["progression"]["run"]["elite_room"] = 10
	assert_has(_errors_for(data), "elite_room: must be before the boss room")


func test_chapter_boss_must_be_a_boss() -> void:
	var data := _data()
	data["chapters"]["chapters"][0]["boss"] = "moss_slime"
	assert_has(_errors_for(data), "is not a boss enemy")


func test_chapters_must_be_numbered_in_order() -> void:
	var data := _data()
	data["chapters"]["chapters"][1]["number"] = 7
	assert_has(_errors_for(data), "numbered 1, 2, 3")


func test_group_sizes_need_one_entry_per_room() -> void:
	var data := _data()
	(data["chapters"]["group_sizes"] as Array).pop_back()
	assert_has(_errors_for(data), "one entry per room")


func test_gear_item_slot_and_stats_are_checked() -> void:
	var data := _data()
	data["gear"]["items"][0]["slot"] = "hat"
	data["gear"]["items"][1]["stats"] = {"luck": 5}
	var errors := _errors_for(data)
	assert_has(errors, "unknown slot 'hat'")
	assert_has(errors, "unknown stat 'luck'")


func test_event_outcome_is_checked() -> void:
	var data := _data()
	data["events"][0]["options"][0]["outcomes"][0]["type"] = "free_money"
	assert_has(_errors_for(data), "unknown outcome 'free_money'")


func test_training_must_grant_a_stat() -> void:
	var data := _data()
	(data["progression"]["training"][0] as Dictionary).erase("atk_pct_bp")
	assert_has(_errors_for(data), "grants no stat")


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

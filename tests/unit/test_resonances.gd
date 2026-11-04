extends SimTestCase


func _hero_with(relics: Dictionary, extra_stats: Dictionary = {}) -> Combatant:
	var stats := {"hp": 100000, "atk": 100, "crit_bp": 0}
	stats.merge(extra_stats, true)
	return factory.make_hero("kitsune", relics, stats)


func test_resonance_activation_by_tags() -> void:
	assert_eq(db.active_resonances(["ember_stone", "frozen_core"]), PackedStringArray(["thermal_shock"]))
	assert_eq(db.active_resonances(["storm_crystal", "chain_relic"]), PackedStringArray(["arc_storm"]))
	assert_eq(db.active_resonances(["whetstone", "blood_chalice"]), PackedStringArray(["crimson_edge"]))
	assert_eq(db.active_resonances(["ember_stone", "storm_crystal"]), PackedStringArray([]))
	assert_eq(db.active_resonances([]), PackedStringArray([]))


func test_multiple_resonances_can_be_active() -> void:
	var active := db.active_resonances(["ember_stone", "frozen_core", "whetstone", "blood_chalice"])
	assert_eq(active, PackedStringArray(["thermal_shock", "crimson_edge"]))


func test_new_relic_with_existing_tag_joins_resonance_without_code() -> void:
	var data := _default_data()
	(data["relics"] as Array).append({"id": "magma_heart", "name_key": "X", "tags": ["ember"], "rarity": "rare",
		"effects": [{"trigger": "on_hit", "action": {"type": "apply_status", "target": "target", "status": "burn", "stacks": 2}}]})
	var custom := ContentDB.from_data(data)
	assert_true(custom.is_valid(), "; ".join(custom.errors))
	assert_eq(custom.active_resonances(["magma_heart", "frozen_core"]), PackedStringArray(["thermal_shock"]))


func test_thermal_shock_shatters_burning_enemy_on_freeze() -> void:
	var h := _hero_with({"ember_stone": 1, "frozen_core": 1})
	assert_has(h.resonances, "thermal_shock")
	var r := battle([h, dummy()], 1, 10)
	var shatter := damage_events(r, {"kind": "shatter", "dst": 1})
	assert_gt(shatter.size(), 0, "freeze on a burning enemy must shatter")
	assert_gt(r.count("proc", {"source": "thermal_shock", "source_kind": "resonance"}), 0)
	var freeze := r.first("status", {"status": "freeze", "dst": 1})
	assert_eq(shatter[0]["t"], freeze["t"], "shatter happens at the moment of freezing")


func test_thermal_shock_needs_both_relics() -> void:
	var r := battle([_hero_with({"frozen_core": 1}), dummy()], 1, 10)
	assert_eq(damage_events(r, {"kind": "shatter"}).size(), 0)


func test_thermal_shock_beats_either_relic_alone() -> void:
	var both := battle([_hero_with({"ember_stone": 1, "frozen_core": 1}), dummy()], 1, 20)
	var ember := battle([_hero_with({"ember_stone": 1}), dummy()], 1, 20)
	var frost := battle([_hero_with({"frozen_core": 1}), dummy()], 1, 20)
	var dmg_both := both.total("damage", "amount", {"src": 0})
	assert_gt(dmg_both, ember.total("damage", "amount", {"src": 0}))
	assert_gt(dmg_both, frost.total("damage", "amount", {"src": 0}))


func test_arc_storm_hits_and_shocks_other_enemies() -> void:
	var h := _hero_with({"storm_crystal": 1, "chain_relic": 1})
	assert_has(h.resonances, "arc_storm")
	var r := battle([h, dummy(), dummy(), dummy()], 1, 5)
	assert_gt(damage_events(r, {"kind": "arc", "dst": 2}).size(), 0)
	assert_gt(damage_events(r, {"kind": "arc", "dst": 3}).size(), 0)
	assert_eq(damage_events(r, {"kind": "arc", "dst": 1}).size(), 0, "arcs skip the main target")
	assert_gt(r.count("status", {"status": "shock", "dst": 3}), 0)


func test_crimson_edge_heals_on_crit_and_overheals_into_shield() -> void:
	var h := _hero_with({"whetstone": 1, "blood_chalice": 1}, {"crit_bp": 10000})
	assert_has(h.resonances, "crimson_edge")
	var r := battle([h, dummy()], 1, 5)
	assert_gt(r.count("proc", {"source": "crimson_edge"}), 0)
	var shield_total := r.total("shield", "amount", {"dst": 0})
	assert_gt(shield_total, 0, "full-hp hero converts crit heals into shield")
	assert_lte(r.hero_shield, 20000, "shield capped at 20% of max hp")


func _default_data() -> Dictionary:
	var data := {}
	for name in ContentDB.FILES:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % name))
		data[name] = parsed if name == "balance" else parsed[name]
	return data

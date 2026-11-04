extends SimTestCase
## Every relic in data/relics.json does what its card says.


func _hero_with(relics: Dictionary, atk: int = 100) -> Combatant:
	return factory.make_hero("kitsune", relics, {"hp": 100000, "atk": atk, "crit_bp": 0})


func test_all_relics_have_effects_and_tags() -> void:
	assert_eq(db.relics.size(), 8)
	for id: String in db.relics:
		assert_gt((db.relics[id]["effects"] as Array).size(), 0, id)
		assert_gt((db.relics[id]["tags"] as Array).size(), 0, id)


func test_ember_stone_burns() -> void:
	var r := battle([_hero_with({"ember_stone": 1}), dummy()], 1, 3)
	assert_gt(r.count("status", {"status": "burn", "dst": 1}), 0)
	assert_gt(damage_events(r, {"kind": "burn"}).size(), 0)


func test_frozen_core_chills_and_freezes() -> void:
	var r := battle([_hero_with({"frozen_core": 1}), dummy()], 1, 8)
	assert_gt(r.count("status", {"status": "chill", "dst": 1}), 0)
	assert_gt(r.count("status", {"status": "freeze", "dst": 1}), 0)


func test_storm_crystal_bolts_every_fourth_attack() -> void:
	var r := battle([_hero_with({"storm_crystal": 1}), dummy()], 1, 9)
	var bolts := damage_events(r, {"kind": "bolt"})
	assert_eq(bolts.size(), r.count("attack", {"src": 0}) / 4)
	assert_eq(bolts[0]["amount"], 120)


func test_relic_level_two_is_stronger() -> void:
	var r := battle([_hero_with({"storm_crystal": 2}), dummy()], 1, 5)
	assert_eq(damage_events(r, {"kind": "bolt"})[0]["amount"], 180, "+50% potency at level 2")


func test_chain_relic_spreads_on_hit_status() -> void:
	var r := battle([_hero_with({"chain_relic": 1, "ember_stone": 1}), dummy(), dummy()], 1, 2)
	assert_gt(r.count("status", {"status": "burn", "dst": 1}), 0)
	assert_gt(r.count("status", {"status": "burn", "dst": 2}), 0, "second enemy burns via chain")


func test_chain_relic_spreads_bolt_at_half_damage() -> void:
	var r := battle([_hero_with({"chain_relic": 1, "storm_crystal": 1}), dummy(), dummy()], 1, 5)
	assert_eq(damage_events(r, {"kind": "bolt", "dst": 1})[0]["amount"], 120)
	assert_eq(damage_events(r, {"kind": "bolt", "dst": 2})[0]["amount"], 60)


func test_whetstone_raises_crits() -> void:
	var plain := battle([_hero_with({}), dummy()], 4, 60)
	var sharp := battle([_hero_with({"whetstone": 1}), dummy()], 4, 60)
	assert_eq(plain.count("attack", {"src": 0, "crit": true}), 0)
	assert_gt(sharp.count("attack", {"src": 0, "crit": true}), 0)
	var crit_hit := damage_events(sharp, {"src": 0, "kind": "hit", "crit": true})[0]
	assert_eq(crit_hit["amount"], 180, "150% base + 30% crit damage")


func test_blood_chalice_lifesteals() -> void:
	var h := _hero_with({"blood_chalice": 1})
	h.hp = 50000
	var r := battle([h, dummy()], 1, 2)
	assert_eq(r.first("heal", {"dst": 0})["amount"], 4, "4% of 100")


func test_ward_stone_shields_at_fight_start() -> void:
	var r := battle([_hero_with({"ward_stone": 1}), dummy()], 1, 1)
	var shield := r.first("shield", {"dst": 0})
	assert_eq(shield["t"], 0)
	assert_eq(shield["amount"], 25000, "25% of 100000 max hp")


func test_hourglass_speeds_attacks() -> void:
	var plain := battle([_hero_with({}), dummy()], 1, 20)
	var fast := battle([_hero_with({"hourglass": 1}), dummy()], 1, 20)
	assert_gt(fast.count("attack", {"src": 0}), plain.count("attack", {"src": 0}))


func test_relic_procs_are_announced_for_the_ui() -> void:
	var r := battle([_hero_with({"storm_crystal": 1}), dummy()], 1, 5)
	assert_gt(r.count("proc", {"source": "storm_crystal", "source_kind": "relic"}), 0)

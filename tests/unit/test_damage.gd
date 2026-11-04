extends SimTestCase


func test_basic_hit_deals_attack_value() -> void:
	var r := battle([hero(1000, 10), dummy()], 1, 3)
	var hits := damage_events(r, {"src": 0, "kind": "hit"})
	assert_gt(hits.size(), 0)
	assert_eq(hits[0]["amount"], 10)


func test_attack_timing_follows_gauge() -> void:
	# 1 attack/s at 20 ticks/s with a 50% starting gauge: ticks 10, 30, 50...
	var r := battle([hero(1000, 10, 1000), dummy()], 1, 3)
	var ticks: Array[int] = []
	for e in r.events:
		if e["type"] == "attack" and e["src"] == 0:
			ticks.append(e["t"])
	assert_eq(ticks, [10, 30, 50] as Array[int])


func test_attack_speed_bonus_attacks_more_often() -> void:
	var slow := battle([hero(1000, 10, 1000), dummy()], 1, 10)
	var fast := battle([hero(1000, 10, 1000, {"aps_bonus_bp": 10000}), dummy()], 1, 10)
	assert_eq(fast.count("attack", {"src": 0}), slow.count("attack", {"src": 0}) * 2)


func test_guaranteed_crit_uses_crit_damage() -> void:
	var r := battle([hero(1000, 10, 1000, {"crit_bp": 10000, "crit_dmg_bp": 20000}), dummy()], 1, 2)
	var hits := damage_events(r, {"src": 0, "kind": "hit"})
	assert_eq(hits[0]["amount"], 20)
	assert_true(hits[0]["crit"])


func test_crit_chance_is_capped() -> void:
	var r := battle([hero(1000000, 1, 10000, {"crit_bp": 10000}), dummy()], 3, 60)
	var attacks := r.count("attack", {"src": 0})
	var crits := r.count("attack", {"src": 0, "crit": true})
	assert_gt(attacks, 500)
	assert_between(crits * 10000 / attacks, 7000, 8000, "crit rate should sit near the 75% cap")


func test_armor_reduces_damage() -> void:
	var r := battle([hero(1000, 100), dummy(100000, {"armor_bp": 3000})], 1, 2)
	assert_eq(damage_events(r, {"src": 0, "kind": "hit"})[0]["amount"], 70)


func test_armor_is_capped() -> void:
	var r := battle([hero(1000, 100), dummy(100000, {"armor_bp": 9500})], 1, 2)
	assert_eq(damage_events(r, {"src": 0, "kind": "hit"})[0]["amount"], 40)


func test_minimum_damage_is_one() -> void:
	var r := battle([hero(1000, 1), dummy(100000, {"armor_bp": 6000})], 1, 2)
	assert_eq(damage_events(r, {"src": 0, "kind": "hit"})[0]["amount"], 1)


func test_shield_absorbs_before_hp() -> void:
	var r := battle([hero(1000, 10), dummy(100, {"shield": 15})], 1, 3)
	var hits := damage_events(r, {"src": 0, "kind": "hit"})
	assert_eq(hits[0]["absorbed"], 10)
	assert_eq(hits[0]["hp"], 100)
	assert_eq(hits[1]["absorbed"], 5)
	assert_eq(hits[1]["hp"], 95)


func test_lifesteal_heals_attacker() -> void:
	var h := hero(100, 10, 1000, {"lifesteal_bp": 5000})
	h.hp = 50
	var r := battle([h, dummy()], 1, 2)
	var heal := r.first("heal", {"dst": 0})
	assert_eq(heal["amount"], 5)


func test_hero_wins_when_enemies_die() -> void:
	var r := battle([hero(1000, 50), unit(Combatant.TEAM_ENEMY, 100, 1)], 1)
	assert_eq(r.outcome, BattleResult.WIN)
	assert_eq(r.count("death", {"dst": 1}), 1)


func test_hero_loses_when_killed() -> void:
	var r := battle([hero(30, 1), unit(Combatant.TEAM_ENEMY, 100000, 10)], 1)
	assert_eq(r.outcome, BattleResult.LOSS)
	assert_eq(r.hero_hp, 0)


func test_stalemate_times_out() -> void:
	var r := battle([hero(1000, 0), dummy()], 1, 5)
	assert_eq(r.outcome, BattleResult.TIMEOUT)
	assert_eq(r.ticks, 100)


func test_hero_targets_front_enemy_first() -> void:
	var r := battle([hero(1000, 10), dummy(20), dummy(20)], 1)
	var deaths: Array[int] = []
	for e in r.events:
		if e["type"] == "death":
			deaths.append(e["dst"])
	assert_eq(deaths, [1, 2] as Array[int])

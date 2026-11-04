extends SimTestCase

const BURN_ON_HIT := {"trigger": "on_hit", "action": {"type": "apply_status", "target": "target", "status": "burn", "stacks": 1}}
const CHILL_ON_HIT := {"trigger": "on_hit", "action": {"type": "apply_status", "target": "target", "status": "chill", "stacks": 1}}
const SHOCK_ON_HIT := {"trigger": "on_hit", "action": {"type": "apply_status", "target": "target", "status": "shock", "stacks": 1}}


func test_burn_ticks_every_second_for_stacks_times_dps() -> void:
	var h := hero(1000, 100)
	add_effect(h, BURN_ON_HIT)
	var r := battle([h, dummy()], 1, 2)
	# Hit at tick 10 applies 1 stack (20% of 100 atk = 20/s); burn ticks at tick 20.
	var burns := damage_events(r, {"kind": "burn", "dst": 1})
	assert_gt(burns.size(), 0)
	assert_eq(burns[0]["t"], 20)
	assert_eq(burns[0]["amount"], 20)


func test_burn_stacks_cap_at_max() -> void:
	var h := hero(1000, 100, 5000)
	add_effect(h, BURN_ON_HIT)
	var r := battle([h, dummy()], 1, 4)
	var max_stacks := 0
	for e in r.events:
		if e["type"] == "status" and e["status"] == "burn":
			max_stacks = maxi(max_stacks, e["stacks"])
	assert_eq(max_stacks, 5)
	var burns := damage_events(r, {"kind": "burn", "dst": 1})
	assert_eq(burns[burns.size() - 1]["amount"], 100, "5 stacks x 20 dps")


func test_burn_ignores_armor() -> void:
	var h := hero(1000, 100)
	add_effect(h, BURN_ON_HIT)
	var r := battle([h, dummy(100000, {"armor_bp": 5000})], 1, 2)
	assert_eq(damage_events(r, {"kind": "burn"})[0]["amount"], 20)


func test_burn_expires_without_refresh() -> void:
	var h := hero(1000, 100)
	add_effect(h, {"trigger": "fight_start", "action": {"type": "apply_status", "target": "target", "status": "burn", "stacks": 1}})
	var r := battle([h, dummy()], 1, 6)
	assert_eq(damage_events(r, {"kind": "burn"}).size(), 3, "3 second duration => 3 ticks")
	assert_eq(r.count("status_end", {"status": "burn"}), 1)


func test_chill_slows_attacks() -> void:
	var enemy := unit(Combatant.TEAM_ENEMY, 100000, 1, 1000)
	var h := hero(100000, 1, 1000)
	add_effect(h, {"trigger": "fight_start", "action": {"type": "apply_status", "target": "target", "status": "chill", "stacks": 4}})
	var r := battle([h, enemy], 1, 4)
	var baseline := battle([hero(100000, 1, 1000), unit(Combatant.TEAM_ENEMY, 100000, 1, 1000)], 1, 4)
	assert_lt(r.count("attack", {"src": 1}), baseline.count("attack", {"src": 1}))


func test_five_chill_stacks_freeze_then_grant_immunity() -> void:
	var h := hero(100000, 1, 5000)
	add_effect(h, CHILL_ON_HIT)
	var r := battle([h, unit(Combatant.TEAM_ENEMY, 100000, 1, 1000)], 1, 10)
	var freeze := r.first("status", {"status": "freeze", "dst": 1})
	assert_false(freeze.is_empty(), "enemy should freeze")
	var ended := r.first("status_end", {"status": "freeze", "dst": 1})
	assert_eq(int(ended["t"]) - int(freeze["t"]), 30, "freeze lasts 1.5s")
	# No enemy attacks while frozen.
	var attacked_while_frozen := false
	for e in r.events:
		if e["type"] == "attack" and e["src"] == 1 and e["t"] > freeze["t"] and e["t"] < ended["t"]:
			attacked_while_frozen = true
	assert_false(attacked_while_frozen)
	# Immunity: no second freeze within 3s after the first ends.
	var refreeze_too_soon := false
	for e in r.events:
		if e["type"] == "status" and e["status"] == "freeze" and e["t"] > ended["t"] and e["t"] <= int(ended["t"]) + 60:
			refreeze_too_soon = true
	assert_false(refreeze_too_soon)


func test_shock_boosts_next_hit_once() -> void:
	var h := hero(1000, 100)
	add_effect(h, {"trigger": "fight_start", "action": {"type": "apply_status", "target": "target", "status": "shock", "stacks": 1}})
	var r := battle([h, dummy()], 1, 3)
	var hits := damage_events(r, {"src": 0, "kind": "hit"})
	assert_eq(hits[0]["amount"], 130)
	assert_eq(hits[1]["amount"], 100)


func test_on_hit_shock_applies_after_damage() -> void:
	var h := hero(1000, 100)
	add_effect(h, SHOCK_ON_HIT)
	var r := battle([h, dummy()], 1, 3)
	var hits := damage_events(r, {"src": 0, "kind": "hit"})
	assert_eq(hits[0]["amount"], 100)
	assert_eq(hits[1]["amount"], 130)

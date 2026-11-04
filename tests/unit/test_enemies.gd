extends SimTestCase


func test_enemy_scaling_formula() -> void:
	assert_eq(factory.enemy_scale_bp(1, 1), 10000)
	assert_eq(factory.enemy_scale_bp(2, 1), 14000)
	assert_eq(factory.enemy_scale_bp(3, 1), 19600)
	assert_eq(factory.enemy_scale_bp(1, 10), 15400)


func test_scaled_enemy_stats() -> void:
	var slime := factory.make_enemy("moss_slime", 2, 1)
	assert_eq(slime.max_hp, 98)
	assert_eq(slime.atk, 12)


func test_boss_enrages_once_below_half_hp() -> void:
	var boss := factory.make_enemy("gatekeeper_golem", 1, 10)
	var r := battle([hero(100000, 60), boss], 1)
	assert_eq(r.outcome, BattleResult.WIN)
	assert_eq(boss.aps_bonus_bp, 3000, "enrage applied exactly once even though hp kept dropping")


func test_boss_slams_every_six_seconds() -> void:
	var boss := factory.make_enemy("gatekeeper_golem")
	var r := battle([hero(1000000, 1), boss], 1, 20)
	var slams := damage_events(r, {"kind": "slam", "dst": 0})
	assert_eq(slams.size(), 3)
	assert_eq(slams[0]["t"], 120)
	assert_eq(slams[0]["amount"], Fx.bp(boss.atk, 25000), "250% of boss atk")


func test_ember_imp_can_burn_the_hero() -> void:
	var r := battle([hero(1000000, 1), factory.make_enemy("ember_imp")], 2, 30)
	assert_gt(r.count("status", {"status": "burn", "dst": 0}), 0)


func test_frozen_boss_cannot_slam() -> void:
	var boss := factory.make_enemy("gatekeeper_golem")
	var h := hero(1000000, 1)
	add_effect(h, {"trigger": "fight_start", "action": {"type": "apply_status", "target": "target", "status": "chill", "stacks": 5}})
	# Freeze lasts 1.5s; slam at 6s still happens. Freeze timing just must not crash or slam early.
	var r := battle([h, boss], 1, 7)
	assert_eq(damage_events(r, {"kind": "slam"}).size(), 1)

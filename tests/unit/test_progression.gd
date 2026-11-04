extends SimTestCase

var prog: Progression


func before_each() -> void:
	super.before_each()
	prog = Progression.new(db)


func _rich_profile() -> PlayerProfile:
	var p := PlayerProfile.new()
	p.wallet.add(Wallet.GOLD, 1_000_000_000, "test")
	p.wallet.add(Wallet.SHARDS, 1_000_000, "test")
	return p


func test_level_cost_curve() -> void:
	assert_eq(prog.level_cost(1), 60)
	assert_eq(prog.level_cost(2), 67)
	assert_gt(prog.level_cost(30), prog.level_cost(29))


func test_level_up_spends_gold_and_grows_stats() -> void:
	var p := _rich_profile()
	var before := prog.hero_stats(p)
	assert_eq(prog.level_up(p), Progression.OK)
	assert_eq(p.hero_level, 2)
	assert_eq(p.wallet.gold, 1_000_000_000 - 60)
	var after := prog.hero_stats(p)
	assert_gt(after["atk"], before["atk"])
	assert_gt(after["hp"], before["hp"])


func test_level_is_capped_by_progress() -> void:
	var p := _rich_profile()
	for i in 50:
		prog.level_up(p)
	assert_eq(p.hero_level, 10, "max level 10 before clearing any chapter")
	assert_eq(prog.level_up(p), Progression.ERR_MAX)
	p.best_chapter = 2
	assert_eq(prog.max_level(p), 18)


func test_level_up_without_gold_fails_cleanly() -> void:
	var p := PlayerProfile.new()
	assert_eq(prog.level_up(p), Progression.ERR_FUNDS)
	assert_eq(p.hero_level, 1)


func test_training_increases_matching_stat() -> void:
	var p := _rich_profile()
	var base := prog.hero_stats(p)
	assert_eq(prog.train(p, "might"), Progression.OK)
	assert_eq(prog.hero_stats(p)["atk"], Fx.bp(base["atk"], 10300))
	assert_eq(prog.train(p, "finesse"), Progression.OK)
	assert_eq(prog.hero_stats(p)["crit_bp"], int(base["crit_bp"]) + 40)
	assert_eq(prog.train(p, "nonsense"), Progression.ERR_UNKNOWN)


func test_attunement_requires_discovery_and_boosts_relic() -> void:
	var p := _rich_profile()
	assert_eq(prog.attune(p, "storm_crystal"), Progression.ERR_LOCKED)
	p.codex_relics.append("storm_crystal")
	assert_eq(prog.attune(p, "storm_crystal"), Progression.OK)
	assert_eq(prog.attunement_bonus_bp(p, "storm_crystal"), 800)
	var plain := factory.make_hero("kitsune", {"storm_crystal": 1}, {"atk": 100, "hp": 100000, "crit_bp": 0})
	var tuned := factory.make_hero("kitsune", {"storm_crystal": 1}, {"atk": 100, "hp": 100000, "crit_bp": 0}, -1, {"storm_crystal": 800})
	var r1 := battle([plain, dummy()], 1, 5)
	var r2 := battle([tuned, dummy()], 1, 5)
	assert_eq(damage_events(r1, {"kind": "bolt"})[0]["amount"], 120)
	assert_eq(damage_events(r2, {"kind": "bolt"})[0]["amount"], 129, "+8% potency")


func test_new_gear_is_auto_equipped_into_empty_slot() -> void:
	var p := PlayerProfile.new()
	var uid := prog.add_gear(p, "fox_fang_blade", "common")
	assert_eq(p.equipped["weapon"], uid)
	var second := prog.add_gear(p, "ember_fan", "common")
	assert_eq(p.equipped["weapon"], uid, "existing equipment is not replaced automatically")
	assert_eq(prog.equip(p, second), Progression.OK)
	assert_eq(p.equipped["weapon"], second)


func test_gear_stats_scale_with_rarity_and_enhance() -> void:
	var p := _rich_profile()
	var uid := prog.add_gear(p, "fox_fang_blade", "common")
	assert_eq(prog.gear_stats(p.gear_by_uid(uid))["atk_pct_bp"], 1000)
	assert_eq(prog.enhance(p, uid), Progression.OK)
	assert_eq(prog.gear_stats(p.gear_by_uid(uid))["atk_pct_bp"], 1060)
	var base_atk: int = db.heroes["kitsune"]["stats"]["atk"]
	assert_eq(prog.hero_stats(p)["atk"], Fx.bp(base_atk, 11060))


func test_enhance_is_capped_by_rarity() -> void:
	var p := _rich_profile()
	var uid := prog.add_gear(p, "spirit_robe", "common")
	for i in 15:
		prog.enhance(p, uid)
	assert_eq(int(p.gear_by_uid(uid)["enhance"]), 10)
	assert_eq(prog.enhance(p, uid), Progression.ERR_MAX)


func test_merge_three_into_next_rarity() -> void:
	var p := _rich_profile()
	var a := prog.add_gear(p, "lucky_charm", "common")
	prog.add_gear(p, "lucky_charm", "common")
	var c := prog.add_gear(p, "lucky_charm", "common")
	p.gear_by_uid(c)["enhance"] = 7
	assert_eq(p.equipped["charm"], a)
	assert_eq(prog.merge(p, "lucky_charm", "common"), Progression.OK)
	assert_eq(p.gear.size(), 1)
	var merged: Dictionary = p.gear[0]
	assert_eq(merged["rarity"], "rare")
	assert_eq(merged["enhance"], 7, "keeps the best enhancement")
	assert_eq(p.equipped["charm"], merged["uid"], "stays equipped")


func test_merge_needs_enough_copies() -> void:
	var p := _rich_profile()
	prog.add_gear(p, "lucky_charm", "common")
	prog.add_gear(p, "lucky_charm", "common")
	assert_eq(prog.merge(p, "lucky_charm", "common"), Progression.ERR_FUNDS)
	assert_eq(p.gear.size(), 2)


func test_power_grows_and_recommended_power_matches_base_hero() -> void:
	var p := _rich_profile()
	assert_eq(prog.recommended_power(1), prog.power(p))
	var start := prog.power(p)
	prog.level_up(p)
	assert_gt(prog.power(p), start)
	assert_eq(prog.recommended_power(2), Fx.bp(prog.recommended_power(1), 14000))


func test_room_gold_kinds_and_replay() -> void:
	assert_eq(prog.room_gold(1, "fight", false), 6)
	assert_eq(prog.room_gold(1, "elite", false), 15)
	assert_eq(prog.room_gold(1, "boss", false), 72)
	assert_eq(prog.room_gold(1, "boss", true), 43)
	assert_gt(prog.room_gold(5, "fight", false), prog.room_gold(4, "fight", false))


func test_offline_reward_and_cap() -> void:
	var p := PlayerProfile.new()
	p.best_chapter = 3
	p.last_seen_unix = 1_000_000
	var per_minute := prog.farm_gold_per_minute(p)
	var two_hours := prog.offline_reward(p, 1_000_000 + 7200)
	assert_eq(two_hours["minutes"], 120)
	assert_eq(two_hours["gold"], Fx.bp(per_minute * 120, 300))
	var week := prog.offline_reward(p, 1_000_000 + 7 * 86400)
	assert_eq(week["minutes"], 720, "capped at 12 hours")


func test_offline_clock_rollback_grants_nothing() -> void:
	var p := PlayerProfile.new()
	p.last_seen_unix = 2_000_000
	assert_eq(prog.offline_reward(p, 1_000_000)["gold"], 0)
	var claimed := prog.claim_offline(p, 1_000_000)
	assert_eq(claimed["gold"], 0)
	assert_eq(p.last_seen_unix, 1_000_000, "baseline resets so the rollback cannot be exploited later")
	assert_eq(prog.offline_reward(PlayerProfile.new(), 5_000_000)["gold"], 0, "first launch grants nothing")


func test_offline_never_grants_gems() -> void:
	var p := PlayerProfile.new()
	p.last_seen_unix = 1
	prog.claim_offline(p, 100_000)
	assert_eq(p.wallet.balance(Wallet.GEMS), 0)
	assert_gt(p.wallet.gold, 0)


func test_chapter_unlocking() -> void:
	var p := PlayerProfile.new()
	assert_true(prog.can_start(p, 1))
	assert_false(prog.can_start(p, 2))
	p.best_chapter = 1
	assert_true(prog.can_start(p, 2))
	assert_false(prog.can_start(p, 0))

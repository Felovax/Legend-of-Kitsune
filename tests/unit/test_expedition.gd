extends SimTestCase

var prog: Progression


func before_each() -> void:
	super.before_each()
	prog = Progression.new(db)


func _profile(seed_base: int = 42) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.seed_base = seed_base
	return p


## A hero strong enough to clear early chapters reliably.
func _strong_profile() -> PlayerProfile:
	var p := _profile()
	p.wallet.add(Wallet.GOLD, 1_000_000_000, "test")
	p.best_chapter = 5
	for i in 20:
		prog.level_up(p)
	for i in 30:
		prog.train(p, "might")
		prog.train(p, "vitality")
	p.best_chapter = 0
	return p


func test_start_consumes_a_run_number() -> void:
	var p := _profile()
	var a := Expedition.start(db, p, 1)
	var b := Expedition.start(db, p, 1)
	assert_eq(p.run_counter, 2)
	assert_ne(a.run_id, b.run_id)
	assert_ne(a.run_seed, b.run_seed)


func test_first_room_is_a_single_fight_door() -> void:
	var e := Expedition.start(db, _profile(), 1)
	assert_eq(e.phase, Expedition.Phase.DOOR)
	assert_eq(e.room, 1)
	assert_eq(e.doors, PackedStringArray(["fight"]))


func test_room_layout_fixed_elite_and_boss() -> void:
	var e := Expedition.start(db, _strong_profile(), 1)
	var seen := {}
	var guard := 0
	while not e.is_finished() and guard < 200:
		guard += 1
		if e.phase == Expedition.Phase.DOOR:
			seen[e.room] = e.doors
			e.choose_door(AutoPilot.best_door(e))
		elif e.phase == Expedition.Phase.BATTLE:
			e.fight()
		elif e.phase == Expedition.Phase.DRAFT:
			e.pick_relic(0)
		elif e.phase == Expedition.Phase.EVENT:
			e.choose_event_option(0)
	assert_true(e.result().won, "strong hero clears chapter 1")
	assert_eq(seen[5], PackedStringArray(["elite"]))
	assert_eq(seen[10], PackedStringArray(["boss"]))
	for r in [2, 3, 4, 6, 7, 8, 9]:
		var doors: PackedStringArray = seen[r]
		assert_eq(doors.size(), 2, "room %d offers two doors" % r)
		assert_ne(doors[0], doors[1])


func test_same_seed_same_expedition() -> void:
	var a := AutoPilot.play(Expedition.start(db, _profile(7), 2))
	var b := AutoPilot.play(Expedition.start(db, _profile(7), 2))
	assert_eq(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()))


func test_draft_offers_distinct_relics_and_rerolls_once() -> void:
	var e := Expedition.start(db, _strong_profile(), 1)
	e.choose_door(0)
	e.fight()
	assert_eq(e.phase, Expedition.Phase.DRAFT)
	assert_eq(e.draft_offer.size(), 3)
	var ids := {}
	for o in e.draft_offer:
		ids[o["relic"]] = true
	assert_eq(ids.size(), 3)
	assert_eq(e.reroll(), Progression.OK)
	assert_eq(e.reroll(), Progression.ERR_FUNDS, "only one free reroll")
	var chosen: String = e.draft_offer[0]["relic"]
	assert_eq(e.pick_relic(0), Progression.OK)
	assert_eq(e.relics[chosen], 1)
	assert_eq(e.room, 2)


func test_picking_owned_relic_levels_it_up() -> void:
	var e := Expedition.start(db, _strong_profile(), 1)
	e.relics["storm_crystal"] = 1
	e.draft_offer = [{"relic": "storm_crystal", "level": 2, "upgrade": true, "completes": PackedStringArray()}]
	e.phase = Expedition.Phase.DRAFT
	e.pick_relic(0)
	assert_eq(e.relics["storm_crystal"], 2)


func test_resonance_awakens_tail_and_boosts_attack() -> void:
	var e := Expedition.start(db, _strong_profile(), 1)
	var atk_before: int = e._stats_with_tails()["atk"]
	e.relics["ember_stone"] = 1
	e.draft_offer = [{"relic": "frozen_core", "level": 1, "upgrade": false, "completes": PackedStringArray(["thermal_shock"])}]
	e.phase = Expedition.Phase.DRAFT
	e.pick_relic(0)
	assert_eq(e.tails(), 1)
	assert_eq(e._stats_with_tails()["atk"], Fx.bp(atk_before, 10500))
	assert_has(e.result().resonances, "thermal_shock")
	var awakened := false
	for h in e.history:
		if h["type"] == "resonance" and h["resonance"] == "thermal_shock":
			awakened = true
	assert_true(awakened)


func test_draft_marks_resonance_completing_offers() -> void:
	var e := Expedition.start(db, _strong_profile(), 1)
	e.relics["ember_stone"] = 1
	var found := false
	for attempt in 30:
		var offer := e._make_offer()
		for o in offer:
			if o["relic"] == "frozen_core":
				found = true
				assert_has(o["completes"], "thermal_shock")
	assert_true(found, "frozen core should appear within 30 offers")


func test_shrine_heals() -> void:
	var e := Expedition.start(db, _strong_profile(), 1)
	e.hero_hp = 10
	e.doors = PackedStringArray(["shrine", "fight"])
	e.choose_door(0)
	assert_eq(e.hero_hp, 10 + Fx.bp(e.hero_max_hp, 3000))
	assert_eq(e.phase, Expedition.Phase.DOOR)
	assert_eq(e.room, 2)


func test_event_outcomes_apply() -> void:
	var e := Expedition.start(db, _strong_profile(), 1)
	e.relics["whetstone"] = 1
	e.phase = Expedition.Phase.EVENT
	e.event_id = "cursed_altar"
	var hp := e.hero_hp
	assert_eq(e.choose_event_option(0), Progression.OK)
	assert_eq(e.hero_hp, hp - Fx.bp(e.hero_max_hp, 2000))
	assert_eq(e.relics["whetstone"], 2)
	e.phase = Expedition.Phase.EVENT
	e.event_id = "lost_traveler"
	var shards_before := e.result().shards
	e.choose_event_option(0)
	assert_eq(e.result().shards, shards_before + 10)


func test_hp_cost_never_kills() -> void:
	var e := Expedition.start(db, _strong_profile(), 1)
	e.hero_hp = 1
	e.phase = Expedition.Phase.EVENT
	e.event_id = "cursed_altar"
	e.choose_event_option(0)
	assert_eq(e.hero_hp, 1)


func test_weak_hero_loses_deep_chapter_and_gets_echo_options() -> void:
	var p := _profile()
	p.best_chapter = 4
	var e := Expedition.start(db, p, 5)
	var r := AutoPilot.play(e)
	assert_false(r.won)
	assert_gt(r.death_room, 0)
	assert_eq(prog.apply_run_result(p, r), Progression.OK)
	assert_eq(p.counters["losses"], 1)
	assert_eq(p.best_chapter, 4)
	assert_eq(p.echo_options, PackedStringArray(r.relics.keys()))


func test_echo_keepsake_starts_next_run_with_relic() -> void:
	var p := _profile()
	p.echo_options = PackedStringArray(["storm_crystal"])
	assert_eq(prog.choose_echo(p, "hourglass"), Progression.ERR_UNKNOWN)
	assert_eq(prog.choose_echo(p, "storm_crystal"), Progression.OK)
	var e := Expedition.start(db, p, 1)
	assert_eq(e.relics.get("storm_crystal", 0), 1)
	var r := AutoPilot.play(e)
	assert_eq(r.echo_used, "storm_crystal")
	prog.apply_run_result(p, r)
	assert_eq(p.echo_relic, "", "echo is consumed")


func test_first_clear_rewards_and_idempotent_apply() -> void:
	var p := _strong_profile()
	var gold_before := p.wallet.gold
	var r := AutoPilot.play(Expedition.start(db, p, 1))
	assert_true(r.won)
	assert_true(r.first_clear)
	assert_eq(r.gear_drops.size() >= 1, true, "first boss clear guarantees gear")
	assert_eq(prog.apply_run_result(p, r), Progression.OK)
	assert_eq(p.best_chapter, 1)
	assert_eq(p.wallet.gold, gold_before + r.gold)
	var gems := p.wallet.balance(Wallet.GEMS)
	assert_gte(gems, 30, "first clear gems")
	assert_eq(prog.apply_run_result(p, r), Progression.ERR_ALREADY)
	assert_eq(p.wallet.gold, gold_before + r.gold, "no double reward")
	assert_eq(p.wallet.balance(Wallet.GEMS), gems)


func test_replay_pays_less_than_first_clear() -> void:
	var fresh := _strong_profile()
	var first := AutoPilot.play(Expedition.start(db, fresh, 1))
	var veteran := _strong_profile()
	veteran.best_chapter = 1
	var replay := AutoPilot.play(Expedition.start(db, veteran, 1))
	assert_true(first.won and replay.won)
	assert_gt(first.gold, replay.gold)


func test_codex_discoveries_pay_gems_once() -> void:
	var p := _profile()
	var r := RunResult.new()
	r.run_id = "x1"
	r.relics_picked = PackedStringArray(["ember_stone", "frozen_core"])
	r.resonances = PackedStringArray(["thermal_shock"])
	prog.apply_run_result(p, r)
	assert_eq(p.wallet.balance(Wallet.GEMS), 20 + 20 + 50)
	var r2 := RunResult.new()
	r2.run_id = "x2"
	r2.relics_picked = PackedStringArray(["ember_stone"])
	r2.resonances = PackedStringArray(["thermal_shock"])
	prog.apply_run_result(p, r2)
	assert_eq(p.wallet.balance(Wallet.GEMS), 90, "already discovered: no new gems")


func test_abandon_counts_as_defeat() -> void:
	var e := Expedition.start(db, _profile(), 1)
	e.abandon()
	assert_true(e.is_finished())
	assert_false(e.result().won)


func test_actions_in_wrong_phase_are_rejected() -> void:
	var e := Expedition.start(db, _profile(), 1)
	assert_eq(e.pick_relic(0), Progression.ERR_UNKNOWN)
	assert_eq(e.choose_event_option(0), Progression.ERR_UNKNOWN)
	assert_eq(e.fight(), null)
	assert_eq(e.choose_door(5), Progression.ERR_UNKNOWN)


func test_random_free_player_never_softlocks() -> void:
	# A free player making random choices, spending everything on upgrades,
	# must keep progressing: clear chapter 3 within a bounded number of runs.
	var p := _profile(99)
	var runs := 0
	while p.best_chapter < 3 and runs < 120:
		runs += 1
		var target := mini(p.best_chapter + 1, 5)
		var r := AutoPilot.play(Expedition.start(db, p, target), true, runs)
		prog.apply_run_result(p, r)
		AutoPilot.spend_greedily(prog, p)
	assert_gte(p.best_chapter, 3, "cleared chapter %d after %d runs" % [p.best_chapter, runs])
	assert_lt(runs, 120)


func test_first_expedition_guarantees_a_resonance_pair() -> void:
	var p := _profile()
	var e := Expedition.start(db, p, 1)
	assert_true(e.tutorial)
	e.choose_door(0)
	e.fight()
	var first: Array = e.draft_offer.map(func(o: Dictionary) -> String: return o["relic"])
	assert_eq(first, ["ember_stone", "frozen_core", "storm_crystal"])
	e.pick_relic(0)
	while e.phase != Expedition.Phase.DRAFT and not e.is_finished():
		if e.phase == Expedition.Phase.DOOR:
			e.choose_door(e.doors.find("fight") if e.doors.has("fight") else 0)
		elif e.phase == Expedition.Phase.BATTLE:
			e.fight()
		elif e.phase == Expedition.Phase.EVENT:
			e.choose_event_option(0)
	if e.phase == Expedition.Phase.DRAFT:
		var second: Dictionary = e.draft_offer[0]
		assert_eq(second["relic"], "frozen_core")
		assert_has(second["completes"], "thermal_shock")
	var restored := Expedition.restore(db, e.to_snapshot())
	assert_eq(JSON.stringify(restored.draft_offer), JSON.stringify(e.draft_offer), "tutorial survives restore")


func test_later_expeditions_are_not_tutorials() -> void:
	var p := _profile()
	p.counters["runs"] = 1
	assert_false(Expedition.start(db, p, 1).tutorial)

extends SimTestCase
## An unfinished expedition survives an app restart: it is rebuilt from its
## seed and recorded actions and must match the original exactly.


func _profile() -> PlayerProfile:
	var p := PlayerProfile.new()
	p.seed_base = 31337
	p.wallet.add(Wallet.GOLD, 1_000_000, "test")
	var prog := Progression.new(db)
	for i in 8:
		prog.level_up(p)
	return p


func _advance(e: Expedition, steps: int) -> void:
	for i in steps:
		if e.is_finished():
			return
		match e.phase:
			Expedition.Phase.DOOR:
				e.choose_door(e.doors.size() - 1)
			Expedition.Phase.BATTLE:
				e.fight()
			Expedition.Phase.DRAFT:
				if e.rerolls_left > 0 and i % 3 == 0:
					e.reroll()
				else:
					e.pick_relic(i % e.draft_offer.size())
			Expedition.Phase.EVENT:
				e.choose_event_option(0)


func _state(e: Expedition) -> String:
	return JSON.stringify({"room": e.room, "phase": e.phase, "hp": e.hero_hp, "relics": e.relics, "doors": Array(e.doors),
		"offer": e.draft_offer, "rerolls": e.rerolls_left, "event": e.event_id, "result": e.result().to_dict()})


func test_restore_matches_original_mid_run() -> void:
	var original := Expedition.start(db, _profile(), 1)
	_advance(original, 9)
	var restored := Expedition.restore(db, original.to_snapshot())
	assert_ne(restored, null)
	assert_eq(_state(restored), _state(original))


func test_restored_run_finishes_identically() -> void:
	var original := Expedition.start(db, _profile(), 1)
	_advance(original, 7)
	var restored := Expedition.restore(db, original.to_snapshot())
	_advance(original, 200)
	_advance(restored, 200)
	assert_true(original.is_finished())
	assert_eq(JSON.stringify(restored.result().to_dict()), JSON.stringify(original.result().to_dict()))


func test_snapshot_survives_save_file_round_trip() -> void:
	var p := _profile()
	var original := Expedition.start(db, p, 1)
	_advance(original, 6)
	p.active_run = original.to_snapshot()
	var json := JSON.stringify(SaveCodec.encode(p))
	var back := SaveCodec.decode(ContentDB.normalize(JSON.parse_string(json)))
	var restored := Expedition.restore(db, (back["profile"] as PlayerProfile).active_run)
	assert_ne(restored, null)
	assert_eq(_state(restored), _state(original))


func test_actions_are_recorded_and_announced() -> void:
	var e := Expedition.start(db, _profile(), 1)
	var seen: Array = []
	e.action_taken.connect(func(a: Array) -> void: seen.append(a))
	e.choose_door(0)
	e.fight()
	assert_eq(e.actions, [["door", 0], ["fight"]])
	assert_eq(seen.size(), 2)


func test_unusable_snapshot_is_rejected() -> void:
	assert_eq(Expedition.restore(db, {}), null)
	var e := Expedition.start(db, _profile(), 1)
	var snap := e.to_snapshot()
	snap["actions"] = [["pick", 0]]
	assert_eq(Expedition.restore(db, snap), null, "picking in the door phase is invalid")


func test_game_resumes_expedition_after_restart() -> void:
	var game: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Game")
	var dir := "user://test_resume/%d" % Time.get_ticks_usec()
	game.boot(dir, dir + "/settings.cfg")
	var exp: Expedition = game.start_expedition(1)
	exp.choose_door(0)
	exp.fight()
	var before := _state(exp)
	game.boot(dir, dir + "/settings.cfg")
	assert_true(game.has_resumable_expedition())
	assert_eq(_state(game.expedition), before)
	game.finish_expedition()
	assert_true(game.profile.active_run.is_empty())
	game.boot(dir, dir + "/settings.cfg")
	assert_false(game.has_resumable_expedition())
	SaveService.new(dir).delete_all()

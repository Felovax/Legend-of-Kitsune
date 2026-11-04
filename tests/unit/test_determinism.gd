extends SimTestCase
## The same inputs must always give the same fight, on every platform. This is
## what makes replays, battle skipping and future server-verified PvP possible.

## Recorded fingerprint of the reference battle below. It uses a frozen copy
## of the content (tests/fixtures/golden) so balance tuning in data/ never
## changes it; only a change to combat RULES does. If that is intentional,
## update this value in the same commit and say so in the commit message.
const GOLDEN_HASH := "f8d727028d41bb62bb691e183deff806"
const GOLDEN_CONTENT := "res://tests/fixtures/golden"

static var _golden_db: ContentDB = null


func _reference_battle(seed_value: int) -> BattleResult:
	if _golden_db == null:
		_golden_db = ContentDB.load_from_dir(GOLDEN_CONTENT)
	var f := CombatFactory.new(_golden_db)
	var h := f.make_hero("kitsune", {"ember_stone": 1, "frozen_core": 1, "storm_crystal": 2, "chain_relic": 1, "whetstone": 1})
	var sim := BattleSim.new(f.cfg, seed_value)
	sim.add_unit(h)
	sim.add_unit(f.make_enemy("moss_slime", 2, 3))
	sim.add_unit(f.make_enemy("ember_imp", 2, 3))
	sim.add_unit(f.make_enemy("stone_sentinel", 2, 3))
	return sim.run()


func test_same_seed_same_fight() -> void:
	var a := _reference_battle(424242)
	var b := _reference_battle(424242)
	assert_eq(a.log_hash(), b.log_hash())
	assert_eq(a.events.size(), b.events.size())


func test_different_seeds_change_the_fight() -> void:
	var hashes := {}
	for s in 20:
		hashes[_reference_battle(s).log_hash()] = true
	assert_gt(hashes.size(), 15, "crit rolls should vary between seeds")


func test_many_seeds_replay_identically() -> void:
	var ok := true
	for s in 50:
		if _reference_battle(1000 + s).log_hash() != _reference_battle(1000 + s).log_hash():
			ok = false
	assert_true(ok)


func test_golden_reference_battle() -> void:
	var h := _reference_battle(424242).log_hash()
	if GOLDEN_HASH == "REPLACE_ME":
		fail("record golden hash: %s" % h)
	else:
		assert_eq(h, GOLDEN_HASH, "combat rules changed; if intended, update GOLDEN_HASH")


func test_sim_does_not_use_global_randomness() -> void:
	seed(1)
	var a := _reference_battle(77).log_hash()
	seed(999)
	randi()
	var b := _reference_battle(77).log_hash()
	assert_eq(a, b)

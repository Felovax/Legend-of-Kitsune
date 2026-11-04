extends TestCase


func test_add_and_spend_with_reasons() -> void:
	var w := Wallet.new()
	assert_true(w.add(Wallet.GOLD, 100, "test_reward"))
	assert_true(w.spend(Wallet.GOLD, 30, "test_cost"))
	assert_eq(w.gold, 70)
	assert_eq(w.ledger.size(), 2)
	assert_eq(w.ledger[1], {"c": "gold", "d": -30, "r": "test_cost", "b": 70})
	assert_eq(w.earned["gold"], 100)
	assert_eq(w.spent["gold"], 30)


func test_insufficient_funds_changes_nothing() -> void:
	var w := Wallet.new()
	w.add(Wallet.GOLD, 10, "seed")
	assert_false(w.spend(Wallet.GOLD, 11, "too_much"))
	assert_eq(w.gold, 10)
	assert_eq(w.ledger.size(), 1)


func test_invalid_amounts_and_reasons_are_rejected() -> void:
	var w := Wallet.new()
	assert_false(w.add(Wallet.GOLD, 0, "zero"))
	assert_false(w.add(Wallet.GOLD, -5, "negative"))
	assert_false(w.add(Wallet.GOLD, 5, ""))
	assert_false(w.add("rubies", 5, "unknown"))
	assert_false(w.spend(Wallet.GOLD, -1, "negative"))
	assert_eq(w.gold, 0)


func test_free_gems_are_spent_before_paid() -> void:
	var w := Wallet.new()
	w.add(Wallet.GEMS, 50, "reward")
	w.add(Wallet.GEMS, 100, "purchase", true)
	assert_eq(w.balance(Wallet.GEMS), 150)
	assert_true(w.spend(Wallet.GEMS, 70, "cache"))
	assert_eq(w.gems_free, 0)
	assert_eq(w.gems_paid, 80)


func test_ledger_is_capped() -> void:
	var w := Wallet.new()
	for i in Wallet.LEDGER_CAP + 25:
		w.add(Wallet.GOLD, 1, "tick")
	assert_eq(w.ledger.size(), Wallet.LEDGER_CAP)
	assert_eq(w.gold, Wallet.LEDGER_CAP + 25)


func test_profile_round_trip() -> void:
	var p := PlayerProfile.new()
	p.hero_level = 7
	p.training = {"might": 3}
	p.attunement = {"ember_stone": 2}
	p.wallet.add(Wallet.GOLD, 500, "x")
	p.wallet.add(Wallet.GEMS, 40, "y", true)
	p.gear.append({"uid": 1, "item": "fox_fang_blade", "rarity": "rare", "enhance": 4})
	p.equipped = {"weapon": 1}
	p.next_gear_uid = 2
	p.best_chapter = 3
	p.chapter_clears = {"1": 2, "3": 1}
	p.codex_relics = PackedStringArray(["ember_stone"])
	p.codex_resonances = PackedStringArray(["thermal_shock"])
	p.echo_relic = "frozen_core"
	p.applied_runs = PackedStringArray(["r1", "r2"])
	p.seed_base = 123456789
	p.run_counter = 9
	p.last_seen_unix = 1_800_000_000
	p.counters = {"runs": 9}
	var json := JSON.stringify(p.to_dict())
	var back := PlayerProfile.from_dict(ContentDB.normalize(JSON.parse_string(json)))
	assert_eq(JSON.stringify(back.to_dict()), json)


func test_profile_from_garbage_is_safe() -> void:
	var p := PlayerProfile.from_dict({"hero_level": -4, "wallet": {"gold": -100}, "best_chapter": -1})
	assert_eq(p.hero_level, 1)
	assert_eq(p.wallet.gold, 0)
	assert_eq(p.best_chapter, 0)

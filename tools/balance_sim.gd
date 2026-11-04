extends SceneTree
## Balance probe: plays many simplified 10-room expeditions with random relic
## drafts and reports win rates. Uses the real BattleSim and content.
##   godot --headless --path . --script res://tools/balance_sim.gd -- --chapter=3 --runs=300 --power=15000
## --power scales hero hp and atk in basis points (10000 = base hero).
## The full expedition rules (doors, events, rewards) arrive in milestone M2.

const ROOMS := 10
const HEAL_BETWEEN_ROOMS_BP := 1500
const NORMALS: PackedStringArray = ["moss_slime", "ember_imp", "stone_sentinel", "lantern_wisp"]


func _initialize() -> void:
	var args := _parse_args()
	var chapter: int = args.get("chapter", 1)
	var runs: int = args.get("runs", 200)
	var power: int = args.get("power", 10000)
	var db := ContentDB.load_from_dir()
	if not db.is_valid():
		printerr("content invalid: " + " | ".join(db.errors))
		quit(1)
		return
	var factory := CombatFactory.new(db)
	var relic_ids: PackedStringArray = db.relics.keys()
	relic_ids.sort()

	var wins := 0
	var rooms_reached := 0
	var died_at := {}
	var resonance_runs := 0
	var battle_ticks := 0
	var battles := 0
	var started := Time.get_ticks_msec()

	for run_index in runs:
		var rng := Rng32.new(Rng32.derive_seed(run_index, chapter))
		var relics := {}
		var base: Dictionary = db.heroes["kitsune"]["stats"]
		var stats := {"hp": Fx.bp(base["hp"], power), "atk": Fx.bp(base["atk"], power)}
		var hp := -1
		var cleared := 0
		for room in range(1, ROOMS + 1):
			var hero := factory.make_hero("kitsune", relics, stats, hp)
			var sim := BattleSim.new(factory.cfg, Rng32.derive_seed(run_index * 100 + room, chapter))
			sim.add_unit(hero)
			for enemy_id in _encounter(room, rng):
				sim.add_unit(factory.make_enemy(enemy_id, chapter, room))
			var result := sim.run()
			battles += 1
			battle_ticks += result.ticks
			if not result.hero_won():
				died_at[room] = int(died_at.get(room, 0)) + 1
				break
			cleared = room
			hp = mini(result.hero_max_hp, result.hero_hp + Fx.bp(result.hero_max_hp, HEAL_BETWEEN_ROOMS_BP))
			# Draft: pick 1 of 3 random relics; prefer one that completes a resonance.
			var offer: PackedStringArray = []
			while offer.size() < 3:
				var pick := relic_ids[rng.next_below(relic_ids.size())]
				if not offer.has(pick):
					offer.append(pick)
			var chosen := offer[0]
			for candidate in offer:
				var trial := relics.keys()
				trial.append(candidate)
				if db.active_resonances(PackedStringArray(trial)).size() > db.active_resonances(PackedStringArray(relics.keys())).size():
					chosen = candidate
					break
			relics[chosen] = int(relics.get(chosen, 0)) + 1
		rooms_reached += cleared
		if cleared == ROOMS:
			wins += 1
		if not db.active_resonances(PackedStringArray(relics.keys())).is_empty():
			resonance_runs += 1

	print("chapter %d, power %d bp, %d runs (%d ms)" % [chapter, power, runs, Time.get_ticks_msec() - started])
	print("  full clears: %.1f%%" % (100.0 * wins / runs))
	print("  avg rooms cleared: %.2f / %d" % [float(rooms_reached) / runs, ROOMS])
	print("  runs with a resonance: %.1f%%" % (100.0 * resonance_runs / runs))
	print("  avg battle length: %.1f s" % (float(battle_ticks) / battles / factory.cfg.tps))
	var deaths: PackedStringArray = []
	for room in range(1, ROOMS + 1):
		if died_at.has(room):
			deaths.append("r%d:%d" % [room, died_at[room]])
	print("  deaths by room: " + (", ".join(deaths) if not deaths.is_empty() else "none"))
	quit(0)


func _encounter(room: int, rng: Rng32) -> PackedStringArray:
	if room == ROOMS:
		return ["gatekeeper_golem"]
	if room == 5:
		return ["ruin_brute"]
	var count := 1 + rng.next_below(mini(3, 1 + room / 3))
	var out: PackedStringArray = []
	for i in count:
		out.append(NORMALS[rng.next_below(NORMALS.size())])
	return out


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts := arg.substr(2).split("=", true, 1)
			out[parts[0]] = int(parts[1])
	return out

extends SceneTree
## Economy and pacing simulation using the real game code.
## Simulates player archetypes day by day: offline claims, purchases, gem
## spending, greedy upgrades and AutoPilot expeditions within a daily time budget.
##   godot --headless --path . --script res://tools/economy_sim.gd -- --days=60 --seeds=2
## Chapters beyond those defined in data reuse the last chapter's enemies
## (stats still scale with the chapter number).

const GEMS_PER_DOLLAR := 88
const CACHE_GEMS := 100
const STARTER_GEMS := 600
const STARTER_SHARDS := 200
const MILESTONES: Array[int] = [3, 5, 10, 15, 20, 25, 30]

const ARCHETYPES := [
	{"name": "Casual free", "minutes": 15, "claims": 2, "usd_month": 0, "starter": false},
	{"name": "Active free", "minutes": 50, "claims": 3, "usd_month": 0, "starter": false},
	{"name": "Occasional spender", "minutes": 20, "claims": 2, "usd_month": 5, "starter": true},
	{"name": "Regular spender", "minutes": 45, "claims": 3, "usd_month": 30, "starter": true},
	{"name": "High spender", "minutes": 75, "claims": 3, "usd_month": 150, "starter": true},
]


func _initialize() -> void:
	var args := _parse_args()
	var days: int = args.get("days", 60)
	var seeds: int = args.get("seeds", 1)
	var only: int = args.get("only", -1)
	var db := ContentDB.load_from_dir()
	if not db.is_valid():
		printerr(" | ".join(db.errors))
		quit(1)
		return
	var started := Time.get_ticks_msec()
	print("Days to first clear (median of %d seed(s)), %d simulated days" % [seeds, days])
	var header := "Archetype | " + " | ".join(MILESTONES.map(func(m: int) -> String: return "Ch%d" % m))
	header += " | Ch@d7 | Ch@d30 | Ch@d%d | runs/day | gold/day@d30" % days
	print(header)
	for i in ARCHETYPES.size():
		if only >= 0 and i != only:
			continue
		var a: Dictionary = ARCHETYPES[i]
		var per_seed: Array[Dictionary] = []
		for s in seeds:
			per_seed.append(_simulate(db, a, days, 1000 + s))
		var cells: PackedStringArray = [a["name"]]
		for m in MILESTONES:
			var vals: Array = per_seed.map(func(r: Dictionary) -> int: return int(r["reach"].get(m, 9999)))
			vals.sort()
			var med: int = vals[vals.size() / 2]
			cells.append(str(med) if med < 9999 else ">%d" % days)
		for d in [7, 30, days]:
			var vals: Array = per_seed.map(func(r: Dictionary) -> int: return int(r["by_day"].get(mini(d, days), 0)))
			vals.sort()
			cells.append(str(vals[vals.size() / 2]))
		cells.append("%.1f" % (float(per_seed[0]["runs"]) / days))
		cells.append(str(per_seed[0]["gold_day30"]))
		print(" | ".join(cells))
	print("(%d ms)" % (Time.get_ticks_msec() - started))
	quit(0)


func _simulate(db: ContentDB, a: Dictionary, days: int, seed_base: int) -> Dictionary:
	var prog := Progression.new(db)
	var p := PlayerProfile.new()
	p.seed_base = seed_base
	var now := 1_800_000_000
	p.last_seen_unix = now
	var reach := {}
	var by_day := {}
	var runs := 0
	var gold_day30 := 0
	var failed_pushes := 0
	if a["starter"]:
		p.wallet.add(Wallet.GEMS, STARTER_GEMS, "starter_pack", true)
		p.wallet.add(Wallet.SHARDS, STARTER_SHARDS, "starter_pack")
		prog.add_gear(p, "fox_fang_blade", "epic")
	var gem_carry := 0.0
	for day in range(1, days + 1):
		var gold_start := int(p.wallet.earned.get("gold", 0))
		# Offline claims spread over the day.
		var claims: int = a["claims"]
		for c in claims:
			now += 86400 / claims
			prog.claim_offline(p, now)
		# Purchases arrive as paid gems.
		gem_carry += float(a["usd_month"]) * GEMS_PER_DOLLAR / 30.0
		if gem_carry >= 1.0:
			p.wallet.add(Wallet.GEMS, int(gem_carry), "purchase", true)
			gem_carry -= int(gem_carry)
		_spend_gems(prog, p)
		AutoPilot.spend_greedily(prog, p)
		var budget := int(a["minutes"]) * 60
		while budget > 0:
			# Push the next chapter; after two failed pushes, farm one run of the best chapter.
			var target := p.best_chapter + 1
			var farming := failed_pushes >= 2 and p.best_chapter > 0
			if farming:
				target = p.best_chapter
				failed_pushes = 0
			var r := AutoPilot.play(Expedition.start(db, p, target), false, runs)
			runs += 1
			prog.apply_run_result(p, r)
			if not farming:
				failed_pushes = 0 if r.won else failed_pushes + 1
			if p.echo_options.size() > 0:
				prog.choose_echo(p, p.echo_options[0])
			_spend_gems(prog, p)
			AutoPilot.spend_greedily(prog, p)
			# Real time: battles at 2x speed, ~12 s of choices/animation per room,
			# ~20 s for start and results screens.
			budget -= r.play_seconds(20, 2, 12) + 20
			for m in MILESTONES:
				if p.best_chapter >= m and not reach.has(m):
					reach[m] = day
		by_day[day] = p.best_chapter
		if day == 30:
			gold_day30 = int(p.wallet.earned.get("gold", 0)) - gold_start
	return {"reach": reach, "by_day": by_day, "runs": runs, "gold_day30": gold_day30}


## Gems go 60% to Gold Caches and 40% to Shard Caches (alternating by value).
func _spend_gems(prog: Progression, p: PlayerProfile) -> void:
	var toggle := 0
	while p.wallet.balance(Wallet.GEMS) >= CACHE_GEMS:
		p.wallet.spend(Wallet.GEMS, CACHE_GEMS, "cache")
		if toggle % 5 < 3:
			p.wallet.add(Wallet.GOLD, prog.gold_cache_amount(p), "gold_cache")
		else:
			p.wallet.add(Wallet.SHARDS, prog.shard_cache_amount(p), "shard_cache")
		toggle += 1


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts := arg.substr(2).split("=", true, 1)
			out[parts[0]] = int(parts[1])
	return out

class_name BattleSim
extends RefCounted
## Deterministic auto-battle simulation.
##
## Same config + seed + units => identical BattleResult, on every platform.
## It never touches nodes, time or global randomness; the UI only replays
## the event log it produces. Rules per tick, in order:
##   1. burn damage (once per second)
##   2. timed effects (every_seconds)
##   3. attack gauges fill; full gauge => basic attack (+ on_hit, on_crit, every_n_attacks)
##   4. status timers count down

var cfg: SimConfig
var rng: Rng32
var units: Array[Combatant] = []
var tick: int = 0
var events: Array[Dictionary] = []


func _init(config: SimConfig, seed_value: int) -> void:
	cfg = config
	rng = Rng32.new(seed_value)


func add_unit(unit: Combatant) -> Combatant:
	unit.uid = units.size()
	units.append(unit)
	return unit


func run() -> BattleResult:
	for u in units:
		u.gauge = cfg.start_gauge
		for eff in u.effects:
			if eff["trigger"] == "passive":
				_execute(u, eff, {}, 0, false)
	_emit("battle_start", {"units": _unit_summaries()})
	for u in units:
		_fire(u, "fight_start", {}, 0)

	while tick < cfg.max_ticks and not _is_over():
		tick += 1
		if tick % cfg.tps == 0:
			_tick_burn()
		_tick_timed_effects()
		_tick_attacks()
		_tick_status_timers()

	var result := BattleResult.new()
	result.ticks = tick
	var hero := _first_of_team(Combatant.TEAM_HERO)
	if hero != null:
		result.hero_hp = hero.hp
		result.hero_max_hp = hero.max_hp
		result.hero_shield = hero.shield
	if not _team_alive(Combatant.TEAM_HERO):
		result.outcome = BattleResult.LOSS
	elif not _team_alive(Combatant.TEAM_ENEMY):
		result.outcome = BattleResult.WIN
	else:
		result.outcome = BattleResult.TIMEOUT
	_emit("battle_end", {"outcome": result.outcome})
	result.events = events
	return result


# --- tick phases -----------------------------------------------------------

func _tick_burn() -> void:
	for u in units:
		if u.is_alive() and u.burn_stacks > 0:
			var source := units[u.burn_source] if u.burn_source >= 0 else u
			_deal(source, u, u.burn_stacks * u.burn_dps_per_stack, "burn", false, false, 1, true)


func _tick_timed_effects() -> void:
	for u in units:
		if not u.is_alive() or u.is_frozen():
			continue
		for eff in u.effects:
			if eff["trigger"] == "every_seconds" and tick % int(eff["every_ticks"]) == 0:
				if _roll(eff):
					_execute(u, eff, {"target": _front_enemy(u)}, 1, true)


func _tick_attacks() -> void:
	for u in units:
		if not u.is_alive() or u.is_frozen():
			continue
		u.gauge += _effective_aps(u)
		if u.gauge >= cfg.gauge_full:
			u.gauge -= cfg.gauge_full
			_basic_attack(u)


func _tick_status_timers() -> void:
	for u in units:
		if not u.is_alive():
			continue
		if u.burn_ticks > 0 and u.burn_applied_tick != tick:
			u.burn_ticks -= 1
			if u.burn_ticks == 0:
				u.burn_stacks = 0
				u.burn_dps_per_stack = 0
				_emit("status_end", {"dst": u.uid, "status": "burn"})
		if u.chill_ticks > 0 and u.chill_applied_tick != tick:
			u.chill_ticks -= 1
			if u.chill_ticks == 0:
				u.chill_stacks = 0
				_emit("status_end", {"dst": u.uid, "status": "chill"})
		if u.frozen_ticks > 0:
			if u.frozen_applied_tick == tick:
				continue
			u.frozen_ticks -= 1
			if u.frozen_ticks == 0:
				u.freeze_immune_ticks = cfg.freeze_immunity_ticks
				_emit("status_end", {"dst": u.uid, "status": "freeze"})
		elif u.freeze_immune_ticks > 0:
			u.freeze_immune_ticks -= 1


# --- core actions ------------------------------------------------------------

func _basic_attack(u: Combatant) -> void:
	var target := _front_enemy(u)
	if target == null:
		return
	u.attack_count += 1
	var crit := rng.chance_bp(mini(u.crit_bp, cfg.crit_cap_bp))
	var raw := Fx.bp(u.atk, u.crit_dmg_bp) if crit else u.atk
	_emit("attack", {"src": u.uid, "dst": target.uid, "crit": crit})
	var dealt := _deal(u, target, raw, "hit", crit, true, 1)
	if dealt > 0 and u.lifesteal_bp > 0 and u.is_alive():
		_heal(u, maxi(1, Fx.bp(dealt, u.lifesteal_bp)), 0)
	var ctx := {"target": target}
	_fire(u, "on_hit", ctx, 1)
	if crit:
		_fire(u, "on_crit", ctx, 1)
	_fire(u, "every_n_attacks", ctx, 1)


## Applies damage and returns the amount dealt (including what a shield absorbed).
func _deal(src: Combatant, dst: Combatant, raw: int, kind: String, crit: bool,
		can_shock: bool, depth: int, ignore_armor: bool = false) -> int:
	if dst == null or not dst.is_alive() or raw <= 0:
		return 0
	var amount := raw
	if can_shock and dst.shocked:
		amount = Fx.bp(amount, 10000 + cfg.shock_bonus_bp)
		dst.shocked = false
	if not ignore_armor:
		amount = Fx.bp(amount, 10000 - clampi(dst.armor_bp, 0, cfg.armor_cap_bp))
	amount = maxi(1, amount)
	var absorbed := mini(dst.shield, amount)
	dst.shield -= absorbed
	dst.hp = maxi(0, dst.hp - (amount - absorbed))
	_emit("damage", {"src": src.uid, "dst": dst.uid, "amount": amount, "absorbed": absorbed,
		"kind": kind, "crit": crit, "hp": dst.hp})
	if dst.is_alive():
		_check_hp_thresholds(dst, depth)
		_fire(dst, "on_damage_taken", {"target": src}, depth + 1)
	else:
		_emit("death", {"dst": dst.uid, "src": src.uid})
		_fire(src, "on_kill", {"target": dst}, depth + 1)
	return amount


func _heal(u: Combatant, amount: int, overheal_shield_cap_bp: int) -> void:
	if not u.is_alive() or amount <= 0:
		return
	var healed := mini(amount, u.max_hp - u.hp)
	u.hp += healed
	if healed > 0:
		_emit("heal", {"dst": u.uid, "amount": healed, "hp": u.hp})
	var overheal := amount - healed
	if overheal > 0 and overheal_shield_cap_bp > 0:
		var room := maxi(0, Fx.bp(u.max_hp, overheal_shield_cap_bp) - u.shield)
		_add_shield(u, mini(overheal, room))


func _add_shield(u: Combatant, amount: int) -> void:
	if amount <= 0 or not u.is_alive():
		return
	u.shield += amount
	_emit("shield", {"dst": u.uid, "amount": amount, "shield": u.shield})


func _apply_status(src: Combatant, dst: Combatant, status: String, stacks: int, depth: int) -> void:
	if dst == null or not dst.is_alive():
		return
	match status:
		"burn":
			dst.burn_stacks = mini(cfg.burn_max_stacks, dst.burn_stacks + stacks)
			dst.burn_ticks = cfg.burn_ticks
			dst.burn_applied_tick = tick
			dst.burn_dps_per_stack = maxi(dst.burn_dps_per_stack, maxi(1, Fx.bp(src.atk, cfg.burn_dps_per_stack_bp)))
			dst.burn_source = src.uid
			_emit("status", {"src": src.uid, "dst": dst.uid, "status": "burn", "stacks": dst.burn_stacks})
			_fire(src, "on_status_applied", {"target": dst, "status": "burn"}, depth + 1)
		"chill":
			if dst.is_frozen():
				return
			var cap := cfg.chill_max_stacks if dst.freeze_immune_ticks == 0 else cfg.chill_max_stacks - 1
			dst.chill_stacks = mini(cap, dst.chill_stacks + stacks)
			dst.chill_ticks = cfg.chill_ticks
			dst.chill_applied_tick = tick
			_emit("status", {"src": src.uid, "dst": dst.uid, "status": "chill", "stacks": dst.chill_stacks})
			_fire(src, "on_status_applied", {"target": dst, "status": "chill"}, depth + 1)
			if dst.chill_stacks >= cfg.chill_max_stacks:
				_freeze(src, dst, depth)
		"freeze":
			if not dst.is_frozen() and dst.freeze_immune_ticks == 0:
				_freeze(src, dst, depth)
		"shock":
			dst.shocked = true
			_emit("status", {"src": src.uid, "dst": dst.uid, "status": "shock", "stacks": 1})
			_fire(src, "on_status_applied", {"target": dst, "status": "shock"}, depth + 1)


func _freeze(src: Combatant, dst: Combatant, depth: int) -> void:
	dst.frozen_ticks = cfg.freeze_ticks
	dst.frozen_applied_tick = tick
	dst.chill_stacks = 0
	dst.chill_ticks = 0
	_emit("status", {"src": src.uid, "dst": dst.uid, "status": "freeze", "stacks": 1})
	_fire(src, "on_status_applied", {"target": dst, "status": "freeze"}, depth + 1)


func _modify_stat(u: Combatant, stat: String, add: int) -> void:
	match stat:
		"atk_bp":
			u.atk = maxi(0, Fx.bp(u.atk, 10000 + add))
		"crit_bp":
			u.crit_bp += add
		"crit_dmg_bp":
			u.crit_dmg_bp += add
		"aps_bonus_bp":
			u.aps_bonus_bp += add
		"lifesteal_bp":
			u.lifesteal_bp += add
		"armor_bp":
			u.armor_bp += add
		"chain_targets":
			u.chain_targets += add
		"chain_ratio_bp":
			u.chain_ratio_bp += add


# --- effects -----------------------------------------------------------------

func _fire(owner: Combatant, trigger: String, ctx: Dictionary, depth: int) -> void:
	if depth > cfg.max_trigger_depth or not owner.is_alive():
		return
	for eff in owner.effects:
		if eff["trigger"] != trigger:
			continue
		if trigger == "every_n_attacks" and owner.attack_count % int(eff["n"]) != 0:
			continue
		if trigger == "on_status_applied" and ctx.get("status", "") != eff["status"]:
			continue
		if eff.has("target_has_status"):
			var t: Combatant = ctx.get("target", null)
			if t == null or not t.has_status(eff["target_has_status"]):
				continue
		if not _roll(eff):
			continue
		_execute(owner, eff, ctx, depth, true)


func _check_hp_thresholds(u: Combatant, depth: int) -> void:
	for eff in u.effects:
		if eff["trigger"] != "hp_below" or u.fired_once.has(eff["index"]):
			continue
		if u.hp * 10000 < u.max_hp * int(eff["threshold_bp"]):
			u.fired_once[eff["index"]] = true
			_execute(u, eff, {"target": _front_enemy(u)}, depth + 1, true)


func _roll(eff: Dictionary) -> bool:
	return not eff.has("chance_bp") or rng.chance_bp(eff["chance_bp"])


func _execute(owner: Combatant, eff: Dictionary, ctx: Dictionary, depth: int, announce: bool) -> void:
	if depth > cfg.max_trigger_depth:
		return
	var a: Dictionary = eff["action"]
	if announce:
		_emit("proc", {"src": owner.uid, "source": eff["source_id"], "source_kind": eff["source_kind"]})
	var targets := _select_targets(owner, a, ctx)
	var extra := _chain_targets(owner, a, targets)
	match a["type"]:
		"apply_status":
			for t in targets + extra:
				_apply_status(owner, t, a["status"], a["stacks"], depth)
		"damage":
			var raw := Fx.bp(owner.atk, a["mult_bp"])
			var kind: String = a.get("kind", "effect")
			for t in targets:
				_deal(owner, t, raw, kind, false, true, depth + 1)
			for t in extra:
				_deal(owner, t, Fx.bp(raw, owner.chain_ratio_bp), kind, false, true, depth + 1)
		"heal":
			for t in targets:
				_heal(t, Fx.bp(t.max_hp, a["pct_max_hp_bp"]), a.get("overheal_shield_cap_bp", 0))
		"shield":
			for t in targets:
				_add_shield(t, Fx.bp(t.max_hp, a["pct_max_hp_bp"]))
		"modify_stat":
			for t in targets:
				_modify_stat(t, a["stat"], a["add"])
		"consume_burst":
			for t in targets:
				if t.burn_stacks <= 0:
					continue
				@warning_ignore("integer_division")
				var remaining := t.burn_stacks * t.burn_dps_per_stack * t.burn_ticks / cfg.tps
				t.burn_stacks = 0
				t.burn_ticks = 0
				t.burn_dps_per_stack = 0
				_emit("status_end", {"dst": t.uid, "status": "burn"})
				_deal(owner, t, Fx.bp(remaining, a["mult_bp"]), a.get("kind", "burst"), false, false, depth + 1, true)


func _select_targets(owner: Combatant, a: Dictionary, ctx: Dictionary) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var primary: Combatant = ctx.get("target", null)
	if primary != null and not primary.is_alive():
		primary = null
	match a.get("target", "target"):
		"self":
			out.append(owner)
		"target":
			var t := primary if primary != null else _front_enemy(owner)
			if t != null:
				out.append(t)
		"all_enemies":
			out = _alive_enemies(owner)
		"other_enemies":
			var limit: int = a.get("max_targets", 99)
			for e in _alive_enemies(owner):
				if e != primary and out.size() < limit:
					out.append(e)
		"random_enemy":
			var pool := _alive_enemies(owner)
			if not pool.is_empty():
				out.append(pool[rng.next_below(pool.size())])
	return out


## Chain Relic: effects aimed at "target" also hit extra enemies.
func _chain_targets(owner: Combatant, a: Dictionary, primary: Array[Combatant]) -> Array[Combatant]:
	var out: Array[Combatant] = []
	if owner.chain_targets <= 0 or a.get("target", "target") != "target" or not a.get("chainable", true):
		return out
	if a["type"] != "damage" and a["type"] != "apply_status":
		return out
	for e in _alive_enemies(owner):
		if not primary.has(e) and out.size() < owner.chain_targets:
			out.append(e)
	return out


# --- queries -----------------------------------------------------------------

func _effective_aps(u: Combatant) -> int:
	var aps := Fx.bp(u.aps_milli, 10000 + u.aps_bonus_bp)
	if u.chill_stacks > 0:
		aps = Fx.bp(aps, maxi(1000, 10000 - u.chill_stacks * cfg.chill_penalty_bp))
	return maxi(1, aps)


func _alive_enemies(u: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for other in units:
		if other.team != u.team and other.is_alive():
			out.append(other)
	return out


func _front_enemy(u: Combatant) -> Combatant:
	for other in units:
		if other.team != u.team and other.is_alive():
			return other
	return null


func _first_of_team(team: int) -> Combatant:
	for u in units:
		if u.team == team:
			return u
	return null


func _team_alive(team: int) -> bool:
	for u in units:
		if u.team == team and u.is_alive():
			return true
	return false


func _is_over() -> bool:
	return not _team_alive(Combatant.TEAM_HERO) or not _team_alive(Combatant.TEAM_ENEMY)


func _unit_summaries() -> Array:
	var out := []
	for u in units:
		out.append({"uid": u.uid, "team": u.team, "id": u.def_id, "hp": u.hp, "max_hp": u.max_hp,
			"atk": u.atk, "resonances": Array(u.resonances)})
	return out


func _emit(type: String, data: Dictionary) -> void:
	data["t"] = tick
	data["type"] = type
	events.append(data)

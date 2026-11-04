class_name HeroScreen
extends Control
## Permanent upgrades: hero level, training, gear (equip, enhance, merge) and
## relic attunement. Every button shows its cost and is disabled when unaffordable.

const SLOT_NAMES := {"weapon": "Weapon", "charm": "Charm", "robe": "Robe"}
const STAT_TEXT := {"atk_pct_bp": "%s%% ATK", "hp_pct_bp": "%s%% HP", "crit_bp": "%s%% crit", "crit_dmg_bp": "%s%% crit dmg",
	"aps_bonus_bp": "%s%% speed", "armor_bp": "%s%% armor"}

var _list: VBoxContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = UiKit.vbox([], 18)
	UiKit.expand(_list)
	scroll.add_child(_list)
	_rebuild()
	Game.profile_changed.connect(_rebuild)


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var p := Game.profile
	var prog := Game.prog
	_list.add_child(UiKit.label(tr("Hero"), "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_list.add_child(_stats_panel())

	# Level
	var level_rows := UiKit.vbox([UiKit.label(tr("Level %d / %d") % [p.hero_level, prog.max_level(p)], "HeadingLabel")], 8)
	if p.hero_level >= prog.max_level(p):
		level_rows.add_child(UiKit.wrap_label(tr("Clear a new chapter to raise the level cap."), "SmallLabel"))
	else:
		level_rows.add_child(_cost_row(tr("+6% ATK and HP"), Wallet.GOLD, prog.level_cost(p.hero_level), tr("Level up"),
			func() -> void: Game.level_up()))
	_list.add_child(UiKit.panel(level_rows))

	# Training
	var training := UiKit.vbox([UiKit.label(tr("Training"), "HeadingLabel")], 8)
	for id in prog.training_ids():
		var t := prog.training_def(id)
		var rank := int(p.training.get(id, 0))
		var effect := ""
		if t.has("atk_pct_bp"):
			effect = tr("+%s%% ATK per rank") % _pct(int(t["atk_pct_bp"]))
		elif t.has("hp_pct_bp"):
			effect = tr("+%s%% HP per rank") % _pct(int(t["hp_pct_bp"]))
		else:
			effect = tr("+%s%% crit, +%s%% crit dmg per rank") % [_pct(int(t["crit_bp"])), _pct(int(t["crit_dmg_bp"]))]
		var title := "%s  %d" % [tr(t["name_key"]), rank]
		if rank >= int(t["max_rank"]):
			training.add_child(UiKit.label(title + "  " + tr("(max)")))
		else:
			training.add_child(_cost_row(title + "\n" + effect, Wallet.GOLD, prog.training_cost(id, rank), tr("Train"),
				func() -> void: Game.train(id)))
	_list.add_child(UiKit.panel(training))

	_list.add_child(_gear_panel())
	_list.add_child(_attunement_panel())


func _stats_panel() -> Control:
	var s := Game.prog.hero_stats(Game.profile)
	var creature := CreatureDraw.new()
	creature.creature_id = "kitsune"
	creature.tails = 1 + Game.profile.codex_resonances.size()
	creature.custom_minimum_size = Vector2(220, 220)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	var entries := [
		[tr("Power"), UiKit.format_number(Game.prog.power(Game.profile))],
		[tr("HP"), UiKit.format_number(int(s["hp"]))],
		[tr("ATK"), UiKit.format_number(int(s["atk"]))],
		[tr("Crit"), "%s%%" % _pct(mini(int(s["crit_bp"]), 7500))],
		[tr("Crit damage"), "%s%%" % _pct(int(s["crit_dmg_bp"]))],
		[tr("Attacks/s"), "%.2f" % (int(s["aps_milli"]) / 1000.0)],
		[tr("Armor"), "%s%%" % _pct(int(s["armor_bp"]))],
	]
	for e: Array in entries:
		grid.add_child(UiKit.label(e[0], "SmallLabel"))
		grid.add_child(UiKit.label(e[1]))
	return UiKit.panel(UiKit.hbox([creature, grid], 24))


func _gear_panel() -> Control:
	var p := Game.profile
	var prog := Game.prog
	var box := UiKit.vbox([UiKit.label(tr("Gear"), "HeadingLabel")], 8)
	for slot: String in Game.db.gear["slots"]:
		var uid := int(p.equipped.get(slot, -1))
		var g := p.gear_by_uid(uid)
		if g.is_empty():
			box.add_child(UiKit.label("%s: %s" % [tr(SLOT_NAMES.get(slot, slot)), tr("empty")], "SmallLabel"))
			continue
		var title := "%s: %s +%d\n%s" % [tr(SLOT_NAMES.get(slot, slot)), _gear_name(g), int(g["enhance"]), _gear_stats_text(g)]
		if int(g["enhance"]) >= int(Game.db.gear_rarities[g["rarity"]]["max_enhance"]):
			box.add_child(UiKit.label(title + "  " + tr("(max)")))
		else:
			box.add_child(_cost_row(title, Wallet.GOLD, prog.enhance_cost(int(g["enhance"])), tr("Enhance"),
				func() -> void: Game.enhance(uid)))
	# Inventory grouped by item + rarity.
	var groups := {}
	for g in p.gear:
		var key := "%s|%s" % [g["item"], g["rarity"]]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(g)
	if not groups.is_empty():
		box.add_child(UiKit.label(tr("Bag"), "SmallLabel"))
	var merge_count := int(Game.db.gear["merge_count"])
	for key: String in groups:
		var items: Array = groups[key]
		var first: Dictionary = items[0]
		var equipped := false
		for g: Dictionary in items:
			if p.equipped.values().has(int(g["uid"])):
				equipped = true
		var row := UiKit.hbox([UiKit.expand(UiKit.label("%s x%d%s" % [_gear_name(first), items.size(), "  " + tr("(worn)") if equipped else ""]))], 8)
		if not equipped:
			var uid := int(first["uid"])
			row.add_child(UiKit.button(tr("Equip"), func() -> void: Game.equip(uid), "BlueButton"))
		if items.size() >= merge_count and Game.db.gear_rarity_order.find(first["rarity"]) < Game.db.gear_rarity_order.size() - 1:
			var item_id: String = first["item"]
			var rarity: String = first["rarity"]
			row.add_child(UiKit.button(tr("Merge %d") % merge_count, func() -> void: Game.merge(item_id, rarity), "GreenButton"))
		box.add_child(row)
	if p.gear.is_empty():
		box.add_child(UiKit.wrap_label(tr("Beat elites and bosses to find gear."), "SmallLabel"))
	return UiKit.panel(box)


func _attunement_panel() -> Control:
	var p := Game.profile
	var box := UiKit.vbox([UiKit.label(tr("Relic Attunement"), "HeadingLabel"),
		UiKit.wrap_label(tr("Shards make a relic permanently stronger every time you draft it."), "SmallLabel")], 8)
	if p.codex_relics.is_empty():
		box.add_child(UiKit.wrap_label(tr("Discover relics on expeditions first."), "SmallLabel"))
	for relic_id in p.codex_relics:
		var level := int(p.attunement.get(relic_id, 0))
		var title := "%s  %d\n%s" % [tr(Game.db.relics[relic_id]["name_key"]), level,
			tr("+%s%% potency") % _pct(Game.prog.attunement_bonus_bp(p, relic_id))]
		if level >= int(Game.db.progression["attunement"]["max_level"]):
			box.add_child(UiKit.label(title + "  " + tr("(max)")))
		else:
			box.add_child(_cost_row(title, Wallet.SHARDS, Game.prog.attunement_cost(level), tr("Attune"),
				func() -> void: Game.attune(relic_id)))
	return UiKit.panel(box)


## [description][currency icon][cost button]
func _cost_row(text: String, currency: String, cost: int, action: String, on_press: Callable) -> Control:
	var info := UiKit.wrap_label(text)
	var button := UiKit.button("%s %s" % [action, UiKit.format_number(cost)], on_press, "GreenButton", 280)
	button.disabled = not Game.profile.wallet.can_afford(currency, cost)
	var icon_kind := "gold" if currency == Wallet.GOLD else ("shard" if currency == Wallet.SHARDS else "gem")
	return UiKit.hbox([info, UiKit.icon(icon_kind, 40), button], 10)


func _gear_name(g: Dictionary) -> String:
	return "%s (%s)" % [tr(Game.db.gear_items[g["item"]]["name_key"]), tr(String(g["rarity"]).capitalize())]


func _gear_stats_text(g: Dictionary) -> String:
	var parts: PackedStringArray = []
	var stats := Game.prog.gear_stats(g)
	for key: String in stats:
		parts.append(tr(STAT_TEXT.get(key, key + " %s")) % ("+" + _pct(int(stats[key]))))
	return ", ".join(parts)


static func _pct(bp: int) -> String:
	var whole := bp / 100
	var frac := bp % 100
	return str(whole) if frac == 0 else "%d.%02d" % [whole, frac]

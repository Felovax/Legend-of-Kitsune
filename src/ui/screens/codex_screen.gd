class_name CodexScreen
extends Control
## Collection of discovered relics and Resonances. Undiscovered Resonances show
## which tags combine, to encourage experimenting.


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := UiKit.vbox([], 16)
	UiKit.expand(list)
	scroll.add_child(list)
	var p := Game.profile
	var db := Game.db
	list.add_child(UiKit.label(tr("Codex"), "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	list.add_child(UiKit.label(tr("Relics %d/%d   Resonances %d/%d") % [p.codex_relics.size(), db.relics.size(),
		p.codex_resonances.size(), db.resonances.size()], "ValueLabel", HORIZONTAL_ALIGNMENT_CENTER))

	list.add_child(UiKit.label(tr("Resonances"), "HeadingLabel"))
	for res_id in db.resonance_order:
		var def: Dictionary = db.resonances[res_id]
		var tags: PackedStringArray = []
		for t: String in def["requires_tags"]:
			tags.append(tr(t.capitalize()))
		var known := p.codex_resonances.has(res_id)
		var title := UiKit.label(tr(def["name_key"]) if known else "???", "HeadingLabel")
		var body := UiKit.wrap_label(tr(def["name_key"] + "_DESC") if known else tr("Combine: %s") % " + ".join(tags))
		var card := UiKit.panel(UiKit.hbox([UiKit.icon("star", 80, Palette.GOLD if known else Color("#b0a090")),
			UiKit.expand(UiKit.vbox([title, body, UiKit.label(" + ".join(tags), "SmallLabel")], 2))], 16), "CardPanel")
		list.add_child(card)

	list.add_child(UiKit.label(tr("Relics"), "HeadingLabel"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for relic_id in db.relic_order:
		var def: Dictionary = db.relics[relic_id]
		var known := p.codex_relics.has(relic_id)
		var color := Palette.element_of(def["tags"]) if known else Color("#b0a090")
		var name_label := UiKit.label(tr(def["name_key"]) if known else "???", "HeadingLabel")
		var info := UiKit.vbox([name_label], 2)
		if known:
			info.add_child(UiKit.wrap_label(tr(def["name_key"] + "_DESC"), "SmallLabel"))
			var level := int(p.attunement.get(relic_id, 0))
			if level > 0:
				info.add_child(UiKit.label(tr("Attunement %d") % level, "SmallLabel"))
		else:
			info.add_child(UiKit.label(tr(String(def["rarity"]).capitalize()), "SmallLabel"))
		var card := UiKit.panel(UiKit.hbox([UiKit.icon("gem", 64, color), UiKit.expand(info)], 10), "CardPanel")
		UiKit.expand(card)
		grid.add_child(card)
	list.add_child(grid)

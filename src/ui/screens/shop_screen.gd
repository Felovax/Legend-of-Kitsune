class_name ShopScreen
extends Control
## The shop: special offers, Fox Charter, Tail Ledger, gem offers (caches) and
## gem packs. Rules shown here follow docs/ECONOMY.md: contents are listed
## plainly, value labels are computed, prices come from the store adapter.

var _list: VBoxContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = UiKit.vbox([], 16)
	UiKit.expand(_list)
	scroll.add_child(_list)
	_rebuild()
	Game.profile_changed.connect(_rebuild)
	Game.purchase_finished.connect(_on_purchase_finished)


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var p := Game.profile
	var shop := Game.shop
	var day := Game.today()
	_list.add_child(UiKit.label(tr("Shop"), "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	if Game.store.is_test_store():
		var banner := UiKit.wrap_label(tr("TEST STORE: no real money is charged."), "ValueLabel", HORIZONTAL_ALIGNMENT_CENTER)
		_list.add_child(UiKit.panel(banner, "DarkPanel"))

	# Fox Charter status.
	if shop.charter_active(p, day) or shop.charter_claimable(p, day) > 0:
		var gems := shop.charter_claimable(p, day)
		var row := UiKit.hbox([UiKit.expand(UiKit.wrap_label(tr("Fox Charter: %d days left") % shop.charter_days_left(p, day), "HeadingLabel"))], 10)
		var claim := UiKit.button(tr("Claim %d") % gems, func() -> void: Game.claim_charter(), "GreenButton", 240)
		claim.disabled = gems <= 0
		row.add_child(UiKit.icon("gem", 40))
		row.add_child(claim)
		_list.add_child(UiKit.panel(row, "CardPanel"))

	# Special offers and conveniences the player can buy now.
	var specials := shop.visible_products(p, day).filter(func(x: Dictionary) -> bool: return x["category"] != "gems")
	if not specials.is_empty():
		_list.add_child(UiKit.label(tr("Special offers"), "HeadingLabel"))
		for product: Dictionary in specials:
			_list.add_child(_product_card(product))

	_list.add_child(_ledger_panel())

	# Gem offers (paid with earned or bought gems).
	_list.add_child(UiKit.label(tr("Resources"), "HeadingLabel"))
	for offer: Dictionary in shop.cfg.get("gem_offers", []):
		_list.add_child(_offer_card(offer))

	_list.add_child(UiKit.label(tr("Gems"), "HeadingLabel"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for product: Dictionary in shop.products():
		if product["category"] == "gems":
			grid.add_child(UiKit.expand(_gem_card(product)))
	_list.add_child(grid)

	_list.add_child(_history_panel())


func _product_card(product: Dictionary) -> Control:
	var lines: PackedStringArray = []
	for c: Dictionary in product["contents"]:
		lines.append(_describe(c))
	var info := UiKit.vbox([UiKit.label(tr(product["name_key"]), "HeadingLabel"),
		UiKit.wrap_label(tr(product["name_key"] + "_DESC"), "SmallLabel"),
		UiKit.wrap_label("• " + "\n• ".join(lines))], 4)
	UiKit.expand(info)
	var price := UiKit.button(Game.store.price_text(product["store_sku"]), func() -> void: Game.buy_product(product["id"]), "GreenButton", 220)
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return UiKit.panel(UiKit.hbox([info, price], 12), "CardPanel")


func _gem_card(product: Dictionary) -> Control:
	var amount := Shop._gems_in(product)
	var col := UiKit.vbox([UiKit.hbox([UiKit.icon("gem", 48), UiKit.label(UiKit.format_number(amount), "HeadingLabel")], 8)], 4)
	var bonus := Game.shop.gem_bonus_percent(product)
	if bonus > 0:
		col.add_child(UiKit.label(tr("+%d%% gems") % bonus, "SmallLabel"))
	if int(Game.profile.purchase_counts.get(product["id"], 0)) == 0 and product.get("first_purchase_double", false):
		var first := UiKit.label(tr("First purchase: double!"), "SmallLabel")
		first.add_theme_color_override("font_color", Palette.GREEN_DARK)
		col.add_child(first)
	col.add_child(UiKit.button(Game.store.price_text(product["store_sku"]), func() -> void: Game.buy_product(product["id"]), "GreenButton"))
	return UiKit.panel(col, "CardPanel")


func _offer_card(offer: Dictionary) -> Control:
	var p := Game.profile
	var day := Game.today()
	var amounts := Game.shop.offer_amounts(p, offer["id"])
	var what := ""
	if int(amounts["gold"]) > 0:
		what = tr("+%s gold (1 hour of farming)") % UiKit.format_number(int(amounts["gold"]))
	elif int(amounts["shards"]) > 0:
		what = tr("+%s shards") % UiKit.format_number(int(amounts["shards"]))
	var price := Game.shop.offer_price(p, offer["id"], day)
	var info := UiKit.vbox([UiKit.label(tr(offer["name_key"]), "HeadingLabel"), UiKit.label(what),
		UiKit.label(tr("%d left today") % Game.shop.offer_remaining(p, offer["id"], day), "SmallLabel")], 2)
	UiKit.expand(info)
	var button := UiKit.button(tr("Sold out") if price < 0 else str(price), func() -> void: Game.buy_offer(offer["id"]), "BlueButton", 200)
	button.disabled = price < 0 or not p.wallet.can_afford(Wallet.GEMS, price)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return UiKit.panel(UiKit.hbox([info, UiKit.icon("gem", 40), button], 10), "CardPanel")


func _ledger_panel() -> Control:
	var p := Game.profile
	var shop := Game.shop
	var owned := shop.has_entitlement(p, "tail_ledger")
	var box := UiKit.vbox([UiKit.label(tr("Tail Ledger"), "HeadingLabel"),
		UiKit.wrap_label(tr("Rewards for clearing chapters. Free for everyone; premium with the Tail Ledger."), "SmallLabel")], 6)
	for step: Dictionary in shop.ledger_steps():
		var chapter := int(step["chapter"])
		var row := UiKit.hbox([UiKit.label(tr("Ch %d") % chapter, "ValueLabel")], 8)
		row.add_child(_ledger_button(chapter, "free", int(step.get("free_gems", 0)), 0))
		if owned:
			row.add_child(_ledger_button(chapter, "premium", int(step.get("premium_gems", 0)), int(step.get("premium_shards", 0))))
		box.add_child(row)
	return UiKit.panel(box)


func _ledger_button(chapter: int, track: String, gems: int, shards: int) -> Control:
	var status := Game.shop.ledger_status(Game.profile, chapter, track)
	var text := tr("%d gems") % gems + (" + %d %s" % [shards, tr("shards")] if shards > 0 else "")
	if status == Shop.ERR_ALREADY:
		text = tr("Claimed")
	var b := UiKit.button(text, func() -> void: Game.claim_ledger(chapter, track), "GreenButton" if track == "premium" else "GhostButton")
	b.disabled = status != Shop.OK
	UiKit.expand(b)
	return b


func _history_panel() -> Control:
	var p := Game.profile
	var box := UiKit.vbox([UiKit.label(tr("Purchase history"), "HeadingLabel")], 4)
	if p.transactions.is_empty():
		box.add_child(UiKit.label(tr("No purchases yet."), "SmallLabel"))
	var recent := p.transactions.slice(maxi(0, p.transactions.size() - 10))
	recent.reverse()
	for t in recent:
		var product := Game.shop.product(t["product"])
		var date := Time.get_date_string_from_unix_time(int(t["day"]) * 86400)
		box.add_child(UiKit.label("%s  %s" % [date, tr(product.get("name_key", t["product"]))], "SmallLabel"))
	return UiKit.panel(box)


func _describe(c: Dictionary) -> String:
	match c["type"]:
		"gems":
			return tr("%s gems") % UiKit.format_number(int(c["amount"]))
		"shards":
			return tr("%s shards") % UiKit.format_number(int(c["amount"]))
		"gold":
			return tr("%s gold") % UiKit.format_number(int(c["amount"]))
		"gear":
			return tr("%s gear: %s") % [tr(String(c["rarity"]).capitalize()), tr(Game.db.gear_items[c["item"]]["name_key"])]
		"charter_days":
			return tr("%d days of daily gems") % int(c["amount"])
		"entitlement":
			if c["id"] == "tail_ledger":
				var totals := Game.shop.ledger_premium_totals()
				return tr("Premium track: %s gems + %s shards in total") % [UiKit.format_number(int(totals["gems"])), UiKit.format_number(int(totals["shards"]))]
			if c["id"] == "swift_paws":
				return tr("3x speed and Auto mode, forever")
	return str(c)


func _on_purchase_finished(_product_id: String, ok: bool, reason: String) -> void:
	var app := _find_app()
	if app != null:
		app.toast(tr("Thank you!") if ok else tr("Purchase failed (%s)") % reason)


func _find_app() -> App:
	var n: Node = get_parent()
	while n != null and not n is App:
		n = n.get_parent()
	return n as App

extends SimTestCase

var shop: Shop
const DAY := 20000


func before_each() -> void:
	super.before_each()
	shop = Shop.new(db)


func _profile(best: int = 0) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.best_chapter = best
	return p


func test_shop_content_is_valid() -> void:
	assert_true(db.is_valid(), " | ".join(db.errors))
	assert_gt(shop.products().size(), 6)


func test_grant_is_idempotent_per_transaction() -> void:
	var p := _profile()
	assert_eq(shop.grant(p, "gems_420", "t1", DAY), Shop.OK)
	var gems := p.wallet.balance(Wallet.GEMS)
	assert_eq(shop.grant(p, "gems_420", "t1", DAY), Shop.ERR_ALREADY)
	assert_eq(p.wallet.balance(Wallet.GEMS), gems, "no double grant")
	assert_eq(shop.grant(p, "gems_420", "", DAY), Shop.ERR_UNKNOWN)
	assert_eq(shop.grant(p, "nope", "t2", DAY), Shop.ERR_UNKNOWN)


func test_first_gem_purchase_is_doubled_once_and_paid() -> void:
	var p := _profile()
	shop.grant(p, "gems_420", "t1", DAY)
	assert_eq(p.wallet.gems_paid, 840)
	shop.grant(p, "gems_420", "t2", DAY)
	assert_eq(p.wallet.gems_paid, 840 + 420)
	assert_eq(p.wallet.gems_free, 0)
	assert_eq(p.purchase_counts["gems_420"], 2)


func test_gem_bonus_percent_is_computed() -> void:
	assert_eq(shop.gem_bonus_percent(shop.product("gems_80")), 0)
	assert_gt(shop.gem_bonus_percent(shop.product("gems_9800")), shop.gem_bonus_percent(shop.product("gems_420")))
	assert_eq(shop.gem_bonus_percent(shop.product("starter_pack")), 0, "only gem packs get bonus labels")


func test_starter_pack_window_and_contents() -> void:
	var fresh := _profile(0)
	assert_eq(shop.eligibility(fresh, shop.product("starter_pack"), DAY), Shop.ERR_LOCKED, "only after the first boss win")
	var p := _profile(1)
	assert_eq(shop.eligibility(p, shop.product("starter_pack"), DAY), Shop.OK)
	shop.grant(p, "starter_pack", "s1", DAY)
	assert_eq(p.wallet.gems_paid, 600)
	assert_eq(p.wallet.shards, 200)
	assert_eq(p.gear.size(), 1)
	assert_eq(p.gear[0]["rarity"], "epic")
	assert_eq(shop.eligibility(p, shop.product("starter_pack"), DAY), Shop.ERR_ALREADY, "one per player")
	assert_eq(shop.eligibility(_profile(10), shop.product("starter_pack"), DAY), Shop.ERR_NOT_ELIGIBLE, "disclosed end at chapter 10")


func test_entitlements_are_permanent_and_not_resold() -> void:
	var p := _profile(5)
	shop.grant(p, "swift_paws", "e1", DAY)
	assert_true(shop.has_entitlement(p, "swift_paws"))
	assert_ne(shop.eligibility(p, shop.product("swift_paws"), DAY), Shop.OK)


func test_offer_daily_limit_and_rising_price() -> void:
	var p := _profile(3)
	p.wallet.add(Wallet.GEMS, 10000, "test")
	var prices: Array = []
	while shop.offer_price(p, "gold_cache", DAY) > 0:
		prices.append(shop.offer_price(p, "gold_cache", DAY))
		assert_eq(shop.buy_offer(p, "gold_cache", DAY), Shop.OK)
	assert_eq(prices, [100, 150, 200, 300, 400])
	assert_eq(shop.buy_offer(p, "gold_cache", DAY), Shop.ERR_SOLD_OUT)
	assert_eq(shop.offer_price(p, "gold_cache", DAY + 1), 100, "resets the next day")
	assert_eq(p.wallet.gold, 5 * prog_gold_cache(p))


func prog_gold_cache(p: PlayerProfile) -> int:
	return Progression.new(db).farm_gold_per_minute(p) * 60


func test_offer_needs_gems() -> void:
	var p := _profile(1)
	assert_eq(shop.buy_offer(p, "gold_cache", DAY), Shop.ERR_FUNDS)
	assert_eq(p.wallet.gold, 0)


func test_charter_pays_daily_and_banks_up_to_a_week() -> void:
	var p := _profile(5)
	shop.grant(p, "fox_charter", "c1", DAY)
	assert_eq(p.wallet.gems_paid, 300)
	assert_eq(shop.charter_claimable(p, DAY), 90, "claim on the purchase day")
	shop.claim_charter(p, DAY)
	assert_eq(shop.claim_charter(p, DAY), Shop.ERR_NOTHING)
	assert_eq(shop.charter_claimable(p, DAY + 3), 270)
	assert_eq(shop.charter_claimable(p, DAY + 20), 7 * 90, "banks at most 7 days")
	shop.claim_charter(p, DAY + 20)
	assert_eq(shop.charter_claimable(p, DAY + 100), 7 * 90, "9 unpaid days left, bank caps at 7")
	shop.claim_charter(p, DAY + 100)
	var total := p.wallet.gems_paid - 300
	assert_eq(total, (1 + 7 + 7) * 90, "never more than the 30 days")
	assert_eq(shop.charter_claimable(p, DAY + 200), 0, "charter is over")
	assert_false(shop.charter_active(p, DAY + 30))


func test_charter_cannot_be_rebought_while_active() -> void:
	var p := _profile(5)
	shop.grant(p, "fox_charter", "c1", DAY)
	assert_eq(shop.eligibility(p, shop.product("fox_charter"), DAY + 5), Shop.ERR_NOT_ELIGIBLE)
	assert_eq(shop.eligibility(p, shop.product("fox_charter"), DAY + 30), Shop.OK)


func test_ledger_free_and_premium_tracks() -> void:
	var p := _profile(4)
	assert_eq(shop.claim_ledger(p, 2, "free"), Shop.OK)
	assert_eq(shop.claim_ledger(p, 2, "free"), Shop.ERR_ALREADY)
	assert_eq(shop.claim_ledger(p, 5, "free"), Shop.ERR_LOCKED, "chapter 5 not cleared yet")
	assert_eq(shop.claim_ledger(p, 2, "premium"), Shop.ERR_LOCKED, "premium needs the ledger")
	shop.grant(p, "tail_ledger", "l1", DAY)
	assert_eq(shop.claim_ledger(p, 2, "premium"), Shop.OK, "retroactive claims")
	assert_eq(shop.claim_ledger(p, 4, "premium"), Shop.OK)
	assert_eq(p.wallet.shards, 100)
	var totals := shop.ledger_premium_totals()
	assert_between(int(totals["gems"]), 4000, 5000)


func test_fake_store_emits_unique_transactions() -> void:
	var store := FakeStore.new(shop.products())
	var ids: Array = []
	store.purchase_completed.connect(func(_sku: String, tid: String) -> void: ids.append(tid))
	store.purchase("lok.gems.80")
	store.purchase("lok.gems.80")
	assert_eq(ids.size(), 2)
	assert_ne(ids[0], ids[1])
	assert_eq(store.price_text("lok.gems.880"), "$9.99")
	var failed: Array = []
	store.purchase_failed.connect(func(sku: String, reason: String) -> void: failed.append(reason))
	store.purchase("lok.nope")
	assert_eq(failed, ["unknown_product"])

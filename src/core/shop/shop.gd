class_name Shop
extends RefCounted
## Shop rules over data/shop.json: eligibility, granting store purchases exactly
## once per transaction id, gem offers (caches) with a daily limit and rising
## price, the Fox Charter's daily gems and the Tail Ledger tracks.
## Pure logic: callers pass `day` (days since the Unix epoch, UTC).
##
## Trust note: in the MVP the fake store "succeeds" locally. Real purchases
## (M6) must be verified by a server before grant() is called.

const OK := ""
const ERR_UNKNOWN := "unknown"
const ERR_ALREADY := "already_granted"
const ERR_NOT_ELIGIBLE := "not_eligible"
const ERR_FUNDS := "insufficient_funds"
const ERR_SOLD_OUT := "sold_out_today"
const ERR_LOCKED := "locked"
const ERR_NOTHING := "nothing_to_claim"

var db: ContentDB
var prog: Progression
var cfg: Dictionary


func _init(content: ContentDB) -> void:
	db = content
	prog = Progression.new(content)
	cfg = content.shop


# --- catalog -------------------------------------------------------------------------

func products() -> Array:
	return cfg.get("products", [])


func product(id: String) -> Dictionary:
	for p: Dictionary in products():
		if p["id"] == id:
			return p
	return {}


func product_by_sku(sku: String) -> Dictionary:
	for p: Dictionary in products():
		if p["store_sku"] == sku:
			return p
	return {}


func offer(id: String) -> Dictionary:
	for o: Dictionary in cfg.get("gem_offers", []):
		if o["id"] == id:
			return o
	return {}


## "" when the product may be shown and bought now, else the reason.
func eligibility(profile: PlayerProfile, p: Dictionary, day: int) -> String:
	if p.is_empty():
		return ERR_UNKNOWN
	var rules: Dictionary = p.get("eligibility", {})
	if profile.best_chapter < int(rules.get("min_chapter_cleared", 0)):
		return ERR_LOCKED
	if rules.has("max_chapter_cleared") and profile.best_chapter > int(rules["max_chapter_cleared"]):
		return ERR_NOT_ELIGIBLE
	if rules.has("max_purchases") and int(profile.purchase_counts.get(p["id"], 0)) >= int(rules["max_purchases"]):
		return ERR_ALREADY
	if rules.get("not_while_charter_active", false) and charter_active(profile, day):
		return ERR_NOT_ELIGIBLE
	for c: Dictionary in p["contents"]:
		if c["type"] == "entitlement" and profile.entitlements.has(c["id"]):
			return ERR_ALREADY
	return OK


func visible_products(profile: PlayerProfile, day: int) -> Array:
	return products().filter(func(p: Dictionary) -> bool: return eligibility(profile, p, day) == OK)


## Extra gems compared with the smallest gem pack, in percent (0 if not a gem pack).
## Used for honest "+N% gems" labels; computed, never typed by hand.
func gem_bonus_percent(p: Dictionary) -> int:
	var amount := _gems_in(p)
	if p.get("category") != "gems" or amount <= 0:
		return 0
	var base := 0.0
	for other: Dictionary in products():
		if other.get("category") == "gems":
			var rate := _gems_in(other) / float(other["test_price_usd"])
			base = rate if base == 0.0 else minf(base, rate)
	var mine := amount / float(p["test_price_usd"])
	return int(roundf((mine / base - 1.0) * 100.0))


static func _gems_in(p: Dictionary) -> int:
	var total := 0
	for c: Dictionary in p.get("contents", []):
		if c["type"] == "gems":
			total += int(c["amount"])
	return total


# --- store purchases ---------------------------------------------------------------------

## Grants a completed store purchase. Idempotent per transaction id. Does not
## re-check eligibility: if the store took the money, the player gets the goods.
func grant(profile: PlayerProfile, product_id: String, transaction_id: String, day: int) -> String:
	var p := product(product_id)
	if p.is_empty() or transaction_id.is_empty():
		return ERR_UNKNOWN
	for t in profile.transactions:
		if t["id"] == transaction_id:
			return ERR_ALREADY
	var first := int(profile.purchase_counts.get(product_id, 0)) == 0
	var reason := "iap_" + product_id
	for c: Dictionary in p["contents"]:
		match c["type"]:
			"gems":
				var amount := int(c["amount"])
				if first and p.get("first_purchase_double", false):
					amount *= 2
				profile.wallet.add(Wallet.GEMS, amount, reason, true)
			"shards":
				profile.wallet.add(Wallet.SHARDS, int(c["amount"]), reason)
			"gold":
				profile.wallet.add(Wallet.GOLD, int(c["amount"]), reason)
			"gear":
				prog.add_gear(profile, c["item"], c["rarity"])
			"entitlement":
				if not profile.entitlements.has(c["id"]):
					profile.entitlements.append(c["id"])
			"charter_days":
				if charter_active(profile, day):
					profile.charter_end_day += int(c["amount"])
				else:
					profile.charter_end_day = day + int(c["amount"])
					profile.charter_last_claim_day = day - 1
	profile.purchase_counts[product_id] = int(profile.purchase_counts.get(product_id, 0)) + 1
	profile.transactions.append({"id": transaction_id, "product": product_id, "day": day})
	return OK


func has_entitlement(profile: PlayerProfile, id: String) -> bool:
	return profile.entitlements.has(id)


# --- gem offers (caches) -----------------------------------------------------------------

func _offer_count(profile: PlayerProfile, offer_id: String, day: int) -> int:
	return int(profile.offer_counts.get(offer_id, 0)) if profile.offer_day == day else 0


## Gem price of the next purchase today, or -1 when today's limit is reached.
func offer_price(profile: PlayerProfile, offer_id: String, day: int) -> int:
	var o := offer(offer_id)
	if o.is_empty():
		return -1
	var prices: Array = o["gem_prices"]
	var n := _offer_count(profile, offer_id, day)
	return int(prices[n]) if n < prices.size() else -1


func offer_remaining(profile: PlayerProfile, offer_id: String, day: int) -> int:
	var o := offer(offer_id)
	return maxi(0, (o.get("gem_prices", []) as Array).size() - _offer_count(profile, offer_id, day)) if not o.is_empty() else 0


## Amounts an offer would grant right now: {gold, shards}.
func offer_amounts(profile: PlayerProfile, offer_id: String) -> Dictionary:
	var out := {"gold": 0, "shards": 0}
	for c: Dictionary in offer(offer_id).get("contents", []):
		var minutes := int(c["amount"])
		match c["type"]:
			"gold_minutes":
				out["gold"] += prog.farm_gold_per_minute(profile) * minutes
			"shard_minutes":
				out["shards"] += Fx.bp(prog.shard_cache_amount(profile), minutes * 10000 / 60)
	return out


func buy_offer(profile: PlayerProfile, offer_id: String, day: int) -> String:
	var price := offer_price(profile, offer_id, day)
	if price < 0:
		return ERR_SOLD_OUT if not offer(offer_id).is_empty() else ERR_UNKNOWN
	if not profile.wallet.spend(Wallet.GEMS, price, "offer_" + offer_id):
		return ERR_FUNDS
	var amounts := offer_amounts(profile, offer_id)
	if int(amounts["gold"]) > 0:
		profile.wallet.add(Wallet.GOLD, amounts["gold"], "offer_" + offer_id)
	if int(amounts["shards"]) > 0:
		profile.wallet.add(Wallet.SHARDS, amounts["shards"], "offer_" + offer_id)
	if profile.offer_day != day:
		profile.offer_day = day
		profile.offer_counts = {}
	profile.offer_counts[offer_id] = _offer_count(profile, offer_id, day) + 1
	return OK


# --- Fox Charter ----------------------------------------------------------------------------

func charter_active(profile: PlayerProfile, day: int) -> bool:
	return day < profile.charter_end_day


func charter_days_left(profile: PlayerProfile, day: int) -> int:
	return maxi(0, profile.charter_end_day - day)


## Gems claimable now: one payment per elapsed day, banked up to max_banked_days.
func charter_claimable(profile: PlayerProfile, day: int) -> int:
	if profile.charter_end_day <= 0:
		return 0
	var last_paid_day := mini(day, profile.charter_end_day - 1)
	var days := mini(last_paid_day - profile.charter_last_claim_day, int(cfg["charter"]["max_banked_days"]))
	return maxi(0, days) * int(cfg["charter"]["gems_per_day"])


func claim_charter(profile: PlayerProfile, day: int) -> String:
	var gems := charter_claimable(profile, day)
	if gems <= 0:
		return ERR_NOTHING
	profile.wallet.add(Wallet.GEMS, gems, "charter_daily", true)
	profile.charter_last_claim_day = mini(day, profile.charter_end_day - 1)
	return OK


# --- Tail Ledger ------------------------------------------------------------------------------

func ledger_steps() -> Array:
	return cfg.get("ledger", [])


## track: "free" or "premium". Returns "" if claimable now.
func ledger_status(profile: PlayerProfile, chapter: int, track: String) -> String:
	var step := _ledger_step(chapter)
	if step.is_empty():
		return ERR_UNKNOWN
	if (profile.ledger_claims.get(track, []) as Array).has(chapter):
		return ERR_ALREADY
	if track == "premium" and not has_entitlement(profile, "tail_ledger"):
		return ERR_LOCKED
	if profile.best_chapter < chapter:
		return ERR_LOCKED
	return OK


func claim_ledger(profile: PlayerProfile, chapter: int, track: String) -> String:
	var status := ledger_status(profile, chapter, track)
	if status != OK:
		return status
	var step := _ledger_step(chapter)
	var paid := track == "premium"
	var gems := int(step.get(track + "_gems", 0))
	var shards := int(step.get(track + "_shards", 0))
	if gems > 0:
		profile.wallet.add(Wallet.GEMS, gems, "ledger_" + track, paid)
	if shards > 0:
		profile.wallet.add(Wallet.SHARDS, shards, "ledger_" + track)
	(profile.ledger_claims[track] as Array).append(chapter)
	return OK


## Total gems and shards on the premium track (shown on the product card).
func ledger_premium_totals() -> Dictionary:
	var out := {"gems": 0, "shards": 0}
	for s: Dictionary in ledger_steps():
		out["gems"] += int(s.get("premium_gems", 0))
		out["shards"] += int(s.get("premium_shards", 0))
	return out


func _ledger_step(chapter: int) -> Dictionary:
	for s: Dictionary in ledger_steps():
		if int(s["chapter"]) == chapter:
			return s
	return {}

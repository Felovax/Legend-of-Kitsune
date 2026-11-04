class_name Wallet
extends RefCounted
## Currency balances. Every change carries a reason code and is recorded in a
## short ledger, so economy analytics are instrumented in one place.
## Gems are kept in two buckets (free / paid); spending uses free gems first.

const GOLD := "gold"
const GEMS := "gems"
const SHARDS := "shards"
const CURRENCIES: PackedStringArray = [GOLD, GEMS, SHARDS]
const LEDGER_CAP := 200

var gold: int = 0
var gems_free: int = 0
var gems_paid: int = 0
var shards: int = 0
## Most recent entries: {c: currency, d: delta, r: reason, b: balance after}
var ledger: Array[Dictionary] = []
## Lifetime totals per currency, for economy analysis.
var earned: Dictionary = {}
var spent: Dictionary = {}


func balance(currency: String) -> int:
	match currency:
		GOLD:
			return gold
		GEMS:
			return gems_free + gems_paid
		SHARDS:
			return shards
	return 0


func can_afford(currency: String, amount: int) -> bool:
	return amount >= 0 and balance(currency) >= amount


## Adds currency. paid=true only for gems bought with real money.
func add(currency: String, amount: int, reason: String, paid: bool = false) -> bool:
	if amount <= 0 or not CURRENCIES.has(currency) or reason.is_empty():
		return false
	match currency:
		GOLD:
			gold += amount
		SHARDS:
			shards += amount
		GEMS:
			if paid:
				gems_paid += amount
			else:
				gems_free += amount
	earned[currency] = int(earned.get(currency, 0)) + amount
	_record(currency, amount, reason)
	return true


## Spends currency if affordable. Returns false (and changes nothing) otherwise.
func spend(currency: String, amount: int, reason: String) -> bool:
	if amount <= 0 or not CURRENCIES.has(currency) or reason.is_empty() or not can_afford(currency, amount):
		return false
	match currency:
		GOLD:
			gold -= amount
		SHARDS:
			shards -= amount
		GEMS:
			var from_free := mini(gems_free, amount)
			gems_free -= from_free
			gems_paid -= amount - from_free
	spent[currency] = int(spent.get(currency, 0)) + amount
	_record(currency, -amount, reason)
	return true


func _record(currency: String, delta: int, reason: String) -> void:
	ledger.append({"c": currency, "d": delta, "r": reason, "b": balance(currency)})
	if ledger.size() > LEDGER_CAP:
		ledger = ledger.slice(ledger.size() - LEDGER_CAP)


func to_dict() -> Dictionary:
	return {"gold": gold, "gems_free": gems_free, "gems_paid": gems_paid, "shards": shards,
		"ledger": ledger.duplicate(true), "earned": earned.duplicate(), "spent": spent.duplicate()}


static func from_dict(d: Dictionary) -> Wallet:
	var w := Wallet.new()
	w.gold = maxi(0, int(d.get("gold", 0)))
	w.gems_free = maxi(0, int(d.get("gems_free", 0)))
	w.gems_paid = maxi(0, int(d.get("gems_paid", 0)))
	w.shards = maxi(0, int(d.get("shards", 0)))
	for e: Variant in d.get("ledger", []):
		if e is Dictionary:
			w.ledger.append(e)
	w.earned = (d.get("earned", {}) as Dictionary).duplicate()
	w.spent = (d.get("spent", {}) as Dictionary).duplicate()
	return w

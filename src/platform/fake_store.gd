class_name FakeStore
extends RefCounted
## Test store for development: every purchase "succeeds" without real money.
## Real stores (StoreKit 2 / Play Billing) will implement the same interface in
## M6: is_test_store(), price_text(sku), purchase(sku), and the two signals.
## Prices shown by real stores come from the store (localized), never from data.

signal purchase_completed(sku: String, transaction_id: String)
signal purchase_failed(sku: String, reason: String)

var _catalog: Dictionary = {}
var _counter: int = 0
## When true, purchases fail (for testing error paths).
var simulate_failure: bool = false


func _init(products: Array) -> void:
	for p: Dictionary in products:
		_catalog[p["store_sku"]] = p


func is_test_store() -> bool:
	return true


func price_text(sku: String) -> String:
	var p: Dictionary = _catalog.get(sku, {})
	return "$%.2f" % float(p.get("test_price_usd", 0.0)) if not p.is_empty() else "?"


func purchase(sku: String) -> void:
	if simulate_failure or not _catalog.has(sku):
		purchase_failed.emit(sku, "test_failure" if simulate_failure else "unknown_product")
		return
	_counter += 1
	var transaction_id := "fake-%d-%d" % [int(Time.get_unix_time_from_system()), _counter]
	purchase_completed.emit(sku, transaction_id)

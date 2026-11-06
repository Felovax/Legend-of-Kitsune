extends Node
## Autoload "Game": owns the player's profile at runtime. Screens read state
## from here and call its methods; they never change the profile directly.
## boot() is called by the App scene (not in _ready), so headless tests that
## load the project never touch real save files.

signal profile_changed
signal expedition_started(expedition: Expedition)
signal expedition_finished(result: RunResult)
signal settings_changed
## A store purchase finished: ok=false carries the reason.
signal purchase_finished(product_id: String, ok: bool, reason: String)

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_SETTINGS := {
	"music": true, "sfx": true, "reduced_effects": false, "screen_shake": true, "text_scale": 1.0, "battle_speed": 2,
}

var db: ContentDB
var prog: Progression
var shop: Shop
## Store adapter. FakeStore in development; StoreKit / Play Billing adapters in M6.
var store: FakeStore
var profile: PlayerProfile
var saves: SaveService
var analytics: Analytics
var expedition: Expedition = null
## Offline income granted at the last boot/resume: {minutes, gold}.
var last_offline: Dictionary = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var booted := false
var _settings_path := SETTINGS_PATH


## Loads content, the profile (or creates one) and settings, then claims offline income.
func boot(save_dir: String = SaveService.DEFAULT_DIR, settings_path: String = SETTINGS_PATH) -> bool:
	db = ContentDB.load_from_dir()
	if not db.is_valid():
		push_error("content invalid: " + " | ".join(db.errors))
		return false
	prog = Progression.new(db)
	shop = Shop.new(db)
	store = FakeStore.new(shop.products())
	store.purchase_completed.connect(_on_purchase_completed)
	store.purchase_failed.connect(_on_purchase_failed)
	saves = SaveService.new(save_dir)
	analytics = Analytics.new(save_dir, OS.is_debug_build())
	_settings_path = settings_path
	_load_settings()
	var loaded := saves.load_profile()
	profile = loaded["profile"] if loaded["ok"] else _new_profile()
	last_offline = prog.claim_offline(profile, now())
	expedition = null
	if not profile.active_run.is_empty():
		expedition = Expedition.restore(db, profile.active_run)
		if expedition == null:
			push_warning("could not resume the saved expedition; it was discarded")
			profile.active_run = {}
		else:
			expedition.action_taken.connect(_on_expedition_action)
	booted = true
	save()
	analytics.track("session_start", {"runs": int(profile.counters.get("runs", 0)), "best": profile.best_chapter, "level": profile.hero_level})
	profile_changed.emit()
	return true


func now() -> int:
	return int(Time.get_unix_time_from_system())


func save() -> void:
	if profile == null:
		return
	profile.last_seen_unix = now()
	var err := saves.save(profile)
	if err != OK:
		push_warning("save failed: %d" % err)


func _notification(what: int) -> void:
	if not booted:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT:
			save()
		NOTIFICATION_APPLICATION_RESUMED:
			last_offline = prog.claim_offline(profile, now())
			save()
			profile_changed.emit()


func _new_profile() -> PlayerProfile:
	var p := PlayerProfile.new()
	var bytes := Crypto.new().generate_random_bytes(6)
	for b in bytes:
		p.seed_base = (p.seed_base << 8) | b
	p.last_seen_unix = now()
	return p


# --- expeditions --------------------------------------------------------------------

func start_expedition(chapter: int) -> Expedition:
	if expedition != null and not expedition.is_finished():
		return expedition
	if not prog.can_start(profile, chapter):
		return null
	expedition = Expedition.start(db, profile, chapter)
	profile.active_run = expedition.to_snapshot()
	expedition.action_taken.connect(_on_expedition_action)
	save()
	analytics.track("run_start", {"chapter": chapter, "tutorial": expedition.tutorial})
	expedition_started.emit(expedition)
	return expedition


## True when an unfinished expedition was restored at boot.
func has_resumable_expedition() -> bool:
	return expedition != null and not expedition.is_finished()


## Saves the expedition's progress after every choice.
func _on_expedition_action(_action: Array) -> void:
	if expedition != null:
		profile.active_run["actions"] = expedition.actions.duplicate(true)
		save()


## Applies the finished expedition's rewards (once) and saves.
func finish_expedition() -> RunResult:
	if expedition == null:
		return null
	if not expedition.is_finished():
		expedition.abandon()
	var result := expedition.result()
	analytics.track("run_end", {"chapter": result.chapter, "won": result.won, "room": result.rooms_cleared, "tails": expedition.tails(), "gold": result.gold})
	prog.apply_run_result(profile, result)
	profile.active_run = {}
	expedition = null
	save()
	expedition_finished.emit(result)
	profile_changed.emit()
	return result


# --- upgrades (each saves and notifies on success) -------------------------------------

func level_up() -> String:
	var code := _commit(prog.level_up(profile))
	if code == Progression.OK:
		analytics.track("level_up", {"level": profile.hero_level, "best": profile.best_chapter})
	return code


func train(id: String) -> String:
	return _commit(prog.train(profile, id))


func attune(relic_id: String) -> String:
	return _commit(prog.attune(profile, relic_id))


func enhance(uid: int) -> String:
	return _commit(prog.enhance(profile, uid))


func equip(uid: int) -> String:
	return _commit(prog.equip(profile, uid))


func merge(item_id: String, rarity: String) -> String:
	return _commit(prog.merge(profile, item_id, rarity))


func choose_echo(relic_id: String) -> String:
	return _commit(prog.choose_echo(profile, relic_id))


func _commit(code: String) -> String:
	if code == Progression.OK:
		save()
		profile_changed.emit()
	return code


# --- shop -----------------------------------------------------------------------------

## Days since the Unix epoch (UTC), the shop's notion of "today".
func today() -> int:
	@warning_ignore("integer_division")
	return now() / 86400


## Starts a store purchase; the result arrives via purchase_finished.
func buy_product(product_id: String) -> String:
	var p := shop.product(product_id)
	var reason := shop.eligibility(profile, p, today())
	if reason != Shop.OK:
		return reason
	store.purchase(p["store_sku"])
	return Shop.OK


func buy_offer(offer_id: String) -> String:
	var code := _commit(shop.buy_offer(profile, offer_id, today()))
	if code == Shop.OK:
		analytics.track("offer", {"id": offer_id})
	return code


func claim_charter() -> String:
	return _commit(shop.claim_charter(profile, today()))


func claim_ledger(chapter: int, track: String) -> String:
	return _commit(shop.claim_ledger(profile, chapter, track))


func _on_purchase_completed(sku: String, transaction_id: String) -> void:
	var p := shop.product_by_sku(sku)
	var code := shop.grant(profile, p.get("id", ""), transaction_id, today())
	if code == Shop.OK:
		save()
		analytics.track("purchase", {"product": p.get("id", ""), "best": profile.best_chapter})
		profile_changed.emit()
	purchase_finished.emit(p.get("id", ""), code == Shop.OK, code)


func _on_purchase_failed(sku: String, reason: String) -> void:
	analytics.track("purchase_failed", {"product": shop.product_by_sku(sku).get("id", ""), "reason": reason})
	purchase_finished.emit(shop.product_by_sku(sku).get("id", ""), false, reason)


# --- debug tools (debug builds only) ---------------------------------------------------

func debug_enabled() -> bool:
	return OS.is_debug_build()


func debug_add(currency: String, amount: int) -> void:
	if debug_enabled():
		profile.wallet.add(currency, amount, "debug")
		_commit(Progression.OK)


func debug_unlock_chapter() -> void:
	if debug_enabled() and profile.best_chapter < db.max_chapter():
		profile.best_chapter += 1
		_commit(Progression.OK)


func debug_reset() -> void:
	if not debug_enabled():
		return
	saves.delete_all()
	analytics.clear()
	boot(saves.dir_path, _settings_path)


## Battle speeds the player may pick: 1x and 2x for everyone, 3x with Swift Paws.
func allowed_speeds() -> Array[int]:
	var speeds: Array[int] = [1, 2]
	if shop.has_entitlement(profile, "swift_paws"):
		speeds.append(3)
	return speeds


func auto_mode_allowed() -> bool:
	return shop.has_entitlement(profile, "swift_paws") or debug_enabled()


# --- settings ------------------------------------------------------------------------------

func set_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	settings[key] = value
	var cfg := ConfigFile.new()
	for k: String in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(_settings_path)
	settings_changed.emit()


func _load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(_settings_path) == OK:
		for k: String in DEFAULT_SETTINGS:
			settings[k] = cfg.get_value("settings", k, DEFAULT_SETTINGS[k])

extends TestCase
## UI smoke tests: every screen builds without engine errors, and an expedition
## can be played start to finish through the Expedition screen's own buttons.

var game: Node
var root: Window
var dir: String


func before_each() -> void:
	root = (Engine.get_main_loop() as SceneTree).root
	game = root.get_node("Game")
	dir = "user://test_ui/%d" % Time.get_ticks_usec()
	game.boot(dir, dir + "/settings.cfg")


func _host(screen: Control) -> Control:
	var host := Control.new()
	host.size = Vector2(1032, 1700)
	host.theme = UiTheme.build()
	root.add_child(host)
	screen.size = host.size
	host.add_child(screen)
	return host


func _cleanup(host: Node) -> void:
	host.queue_free()
	SaveService.new(dir).delete_all()


func test_boot_creates_and_saves_a_profile() -> void:
	assert_true(game.booted)
	assert_ne(game.profile.seed_base, 0)
	assert_true(FileAccess.file_exists(dir + "/profile.json"))
	SaveService.new(dir).delete_all()


func test_boot_reloads_existing_profile() -> void:
	game.profile.wallet.add(Wallet.GOLD, 123, "test")
	game.save()
	game.boot(dir, dir + "/settings.cfg")
	assert_eq(game.profile.wallet.gold, 123)
	SaveService.new(dir).delete_all()


func test_settings_persist() -> void:
	game.set_setting("screen_shake", false)
	game.set_setting("not_a_setting", 5)
	game.boot(dir, dir + "/settings.cfg")
	assert_eq(game.settings["screen_shake"], false)
	assert_false(game.settings.has("not_a_setting"))
	SaveService.new(dir).delete_all()


func test_locked_chapter_cannot_start() -> void:
	assert_eq(game.start_expedition(3), null)
	assert_ne(game.start_expedition(1), null)
	game.finish_expedition()
	SaveService.new(dir).delete_all()


func test_every_tab_screen_builds() -> void:
	for screen in [CampScreen.new(), HeroScreen.new(), CodexScreen.new(), SettingsScreen.new(), ShopScreen.new()]:
		var host := _host(screen)
		assert_gt(screen.get_child_count(), 0, screen.get_class())
		host.queue_free()
	SaveService.new(dir).delete_all()


func test_app_shell_builds_and_switches_tabs() -> void:
	var app := App.new()
	var host := _host(app)
	for tab in ["hero", "codex", "settings", "shop", "camp"]:
		app.show_tab(tab)
	assert_eq(app._current_tab, "camp")
	_cleanup(host)


func test_play_expedition_through_screen_buttons() -> void:
	var exp: Expedition = game.start_expedition(1)
	var screen := ExpeditionScreen.new()
	screen.setup(exp)
	var host := _host(screen)
	var guard := 0
	while not exp.is_finished() and guard < 80:
		guard += 1
		match exp.phase:
			Expedition.Phase.DOOR:
				screen._choose_door(0)
			Expedition.Phase.BATTLE:
				pass
			Expedition.Phase.DRAFT:
				exp.pick_relic(0)
				screen._refresh()
			Expedition.Phase.EVENT:
				exp.choose_event_option(0)
				screen._refresh()
		if screen._battle != null:
			screen._battle.skip()
			screen._refresh()
	assert_true(exp.is_finished())
	screen._refresh()
	assert_ne(screen._result, null, "results screen applied the run")
	assert_eq(game.profile.counters.get("runs", 0), 1)
	_cleanup(host)


func test_battle_view_skip_reaches_final_hp() -> void:
	var db := ContentDB.load_from_dir()
	var f := CombatFactory.new(db)
	var sim := BattleSim.new(f.cfg, 5)
	sim.add_unit(f.make_hero("kitsune", {"ember_stone": 1}))
	sim.add_unit(f.make_enemy("moss_slime"))
	var result := sim.run()
	var view := BattleView.new()
	var host := _host(view)
	view.play(result, f.cfg.tps)
	view.skip()
	assert_false(view.is_playing())
	assert_eq(int((view._units[0]["bar"] as ProgressBar).value), result.hero_hp)
	_cleanup(host)


func test_number_formatting() -> void:
	assert_eq(UiKit.format_number(999), "999")
	assert_eq(UiKit.format_number(1234), "1,234")
	assert_eq(UiKit.format_number(12345), "12.3K")
	assert_eq(UiKit.format_number(2_500_000), "2.5M")
	assert_eq(UiKit.format_number(999_000_000_000), "999B")


func test_purchase_flow_through_game() -> void:
	game.profile.best_chapter = 3
	var results: Array = []
	game.purchase_finished.connect(func(id: String, ok: bool, _r: String) -> void: results.append([id, ok]), CONNECT_ONE_SHOT)
	assert_eq(game.buy_product("gems_880"), Shop.OK)
	assert_eq(results, [["gems_880", true]])
	assert_eq(game.profile.wallet.gems_paid, 1760, "first purchase doubled")
	assert_eq(game.profile.transactions.size(), 1)
	assert_eq(game.buy_offer("gold_cache"), Shop.OK)
	assert_gt(game.profile.wallet.gold, 0)
	game.boot(dir, dir + "/settings.cfg")
	assert_eq(game.profile.transactions.size(), 1, "purchase was saved")
	assert_eq(game.buy_product("starter_pack"), Shop.OK)
	assert_ne(game.buy_product("starter_pack"), Shop.OK, "one per player")
	SaveService.new(dir).delete_all()


func test_shop_screen_builds_with_progress() -> void:
	game.profile.best_chapter = 5
	game.shop.grant(game.profile, "tail_ledger", "t-ledger", game.today())
	game.shop.grant(game.profile, "fox_charter", "t-charter", game.today())
	var host := _host(ShopScreen.new())
	assert_gt(host.get_child(0).get_child_count(), 0)
	_cleanup(host)

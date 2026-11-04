extends Control
## Screenshot helper: a profile with some progress, showing the tab in
## PREVIEW_TAB (camp | hero | codex | settings | shop). Uses user://preview/.


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://preview")
	SaveService.new("user://preview/saves").delete_all()
	Game.boot("user://preview/saves", "user://preview/settings.cfg")
	var p := Game.profile
	for i in 12:
		var target := mini(p.best_chapter + 1, Game.db.max_chapter())
		var r := AutoPilot.play(Expedition.start(Game.db, p, target), false, i)
		Game.prog.apply_run_result(p, r)
		AutoPilot.spend_greedily(Game.prog, p, 25)
	p.wallet.add(Wallet.GOLD, 500, "preview")
	Game.save()
	var app := App.new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(app)
	var tab := OS.get_environment("PREVIEW_TAB")
	if tab != "":
		app.show_tab.call_deferred(tab)

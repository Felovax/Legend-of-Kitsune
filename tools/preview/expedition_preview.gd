extends Control
## Screenshot helper: shows the Expedition screen in a chosen phase.
## PREVIEW_PHASE = first | doors | battle | draft | event | results (default battle).
## "first" is the very first door of a new player's first expedition.
## Uses separate save files under user://preview/.


func _ready() -> void:
	theme = UiTheme.build()
	DirAccess.make_dir_recursive_absolute("user://preview")
	SaveService.new("user://preview/saves").delete_all()
	Game.boot("user://preview/saves", "user://preview/settings.cfg")
	var bg := Backdrop.new()
	bg.variant = "ruins"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var exp := Game.start_expedition(1)
	match OS.get_environment("PREVIEW_PHASE"):
		"first":
			pass
		"doors":
			exp.choose_door(0)
			exp.fight()
			exp.pick_relic(0)
		"draft":
			exp.relics["ember_stone"] = 1
			exp.choose_door(0)
			exp.fight()
		"event":
			exp.phase = Expedition.Phase.EVENT
			exp.event_id = "cursed_altar"
		"results":
			AutoPilot.play(exp)
		_:
			exp.relics["ember_stone"] = 1
			exp.relics["frozen_core"] = 1
			exp.choose_door(0)
	var screen := ExpeditionScreen.new()
	screen.setup(exp)
	var margin := UiKit.margin(screen, 24)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

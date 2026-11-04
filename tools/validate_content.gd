extends SceneTree
## Validates res://data. Exit code 1 with readable errors if anything is wrong.
##   godot --headless --path . --script res://tools/validate_content.gd


func _initialize() -> void:
	var db := ContentDB.load_from_dir()
	if db.is_valid():
		print("content OK: %d heroes, %d enemies, %d relics, %d resonances" % [
			db.heroes.size(), db.enemies.size(), db.relics.size(), db.resonances.size()])
		quit(0)
	else:
		for e in db.errors:
			printerr("content error: " + e)
		quit(1)

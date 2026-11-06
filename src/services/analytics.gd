class_name Analytics
extends RefCounted
## Local-only gameplay event log for playtests (docs/DECISIONS.md #27).
## Writes one JSON object per line. Nothing is sent anywhere, and no device
## identifiers or personal data are recorded: only game events and a timestamp.
## Release builds keep it off until a privacy policy and consent screen exist.

const FILE_NAME := "analytics.jsonl"
## When the log grows past this, it is moved to "<file>.1" (one old file kept).
const MAX_BYTES := 256 * 1024

var path: String
var enabled: bool


func _init(directory: String, is_enabled: bool = true) -> void:
	path = directory.path_join(FILE_NAME)
	enabled = is_enabled


func track(event: String, props: Dictionary = {}) -> void:
	if not enabled:
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_rotate_if_large()
	var exists := FileAccess.file_exists(path)
	var file := FileAccess.open(path, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	var entry := {"t": int(Time.get_unix_time_from_system()), "e": event}
	entry.merge(props)
	file.store_line(JSON.stringify(entry))
	file.close()


## All logged events (current file only), oldest first.
func events() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var json := JSON.new()
		if json.parse(line) == OK and json.data is Dictionary:
			out.append(ContentDB.normalize(json.data))
	return out


## Short playtest summary: sessions, runs, wins, win rate, purchases.
func summary() -> Dictionary:
	var out := {"sessions": 0, "runs": 0, "wins": 0, "purchases": 0, "offers": 0, "level_ups": 0}
	for e in events():
		match String(e["e"]):
			"session_start":
				out["sessions"] += 1
			"run_end":
				out["runs"] += 1
				if e.get("won", false):
					out["wins"] += 1
			"purchase":
				out["purchases"] += 1
			"offer":
				out["offers"] += 1
			"level_up":
				out["level_ups"] += 1
	return out


func clear() -> void:
	for p in [path, path + ".1"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _rotate_if_large() -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var length := file.get_length() if file != null else 0
	file = null
	if length > MAX_BYTES:
		DirAccess.rename_absolute(path, path + ".1")

class_name SaveService
extends RefCounted
## Local save files: atomic writes, two rotating backups and an HMAC checksum.
## The checksum only detects corruption and casual editing; it is not security.
## Anything that matters for money or competition must be verified on a server.
##
## Load order: main -> backup1 -> backup2 -> leftover temp file.

const DEFAULT_DIR := "user://saves"
const FILE_NAME := "profile.json"
const BACKUPS := 2
## Obfuscation key for the checksum (not a secret; it ships in the app).
const SIGN_KEY := "lok-save-sign-v1-7f3a9c"

var dir_path: String


func _init(directory: String = DEFAULT_DIR) -> void:
	dir_path = directory


func main_path() -> String:
	return dir_path.path_join(FILE_NAME)


func backup_path(n: int) -> String:
	return dir_path.path_join("%s.bak%d" % [FILE_NAME, n])


func temp_path() -> String:
	return dir_path.path_join(FILE_NAME + ".tmp")


func save(profile: PlayerProfile) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return err
	var payload := JSON.stringify(SaveCodec.encode(profile))
	var envelope := JSON.stringify({"payload": payload, "sig": checksum(payload)})
	var file := FileAccess.open(temp_path(), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(envelope)
	file.flush()
	file.close()
	# Rotate: bak(n-1) -> bak(n) ... main -> bak1, then tmp -> main.
	for n in range(BACKUPS, 1, -1):
		if FileAccess.file_exists(backup_path(n - 1)):
			DirAccess.rename_absolute(backup_path(n - 1), backup_path(n))
	if FileAccess.file_exists(main_path()):
		DirAccess.rename_absolute(main_path(), backup_path(1))
	return DirAccess.rename_absolute(temp_path(), main_path())


## Returns {ok, profile, source, errors}. source is "main", "backup1", ...
func load_profile() -> Dictionary:
	var errors: PackedStringArray = []
	var candidates := [["main", main_path()]]
	for n in range(1, BACKUPS + 1):
		candidates.append(["backup%d" % n, backup_path(n)])
	candidates.append(["temp", temp_path()])
	for c: Array in candidates:
		var path: String = c[1]
		if not FileAccess.file_exists(path):
			continue
		var decoded := _read(path)
		if decoded["ok"]:
			return {"ok": true, "profile": decoded["profile"], "source": c[0], "errors": errors}
		errors.append("%s: %s" % [c[0], decoded["error"]])
	return {"ok": false, "profile": null, "source": "", "errors": errors}


func delete_all() -> void:
	for path in [main_path(), backup_path(1), backup_path(2), temp_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _read(path: String) -> Dictionary:
	var envelope: Variant = _parse(FileAccess.get_file_as_string(path))
	if not envelope is Dictionary or not envelope.get("payload") is String:
		return {"ok": false, "error": "unreadable"}
	var payload: String = envelope["payload"]
	if envelope.get("sig", "") != checksum(payload):
		return {"ok": false, "error": "checksum_mismatch"}
	var result := SaveCodec.decode(ContentDB.normalize(_parse(payload)))
	if not result["ok"]:
		return {"ok": false, "error": result["error"]}
	return result


## Parses JSON without logging engine errors (corrupt files are expected here).
static func _parse(text: String) -> Variant:
	if text.is_empty():
		return null
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


static func checksum(text: String) -> String:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, SIGN_KEY.to_utf8_buffer(), text.to_utf8_buffer()).hex_encode()

extends TestCase

var svc: SaveService


func before_each() -> void:
	svc = SaveService.new("user://test_saves/%d" % Time.get_ticks_usec())


func _profile(level: int) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.hero_level = level
	p.wallet.add(Wallet.GOLD, level * 100, "test")
	p.codex_relics = PackedStringArray(["ember_stone"])
	p.seed_base = 777
	return p


func _cleanup() -> void:
	svc.delete_all()
	DirAccess.remove_absolute(svc.dir_path)


func test_round_trip() -> void:
	var p := _profile(5)
	assert_eq(svc.save(p), OK)
	var loaded := svc.load_profile()
	assert_true(loaded["ok"])
	assert_eq(loaded["source"], "main")
	assert_eq(JSON.stringify((loaded["profile"] as PlayerProfile).to_dict()), JSON.stringify(p.to_dict()))
	_cleanup()


func test_backups_rotate() -> void:
	svc.save(_profile(1))
	svc.save(_profile(2))
	svc.save(_profile(3))
	assert_has(FileAccess.get_file_as_string(svc.main_path()), "\\\"hero_level\\\":3")
	assert_has(FileAccess.get_file_as_string(svc.backup_path(1)), "\\\"hero_level\\\":2")
	assert_has(FileAccess.get_file_as_string(svc.backup_path(2)), "\\\"hero_level\\\":1")
	_cleanup()


func test_corrupted_main_falls_back_to_backup() -> void:
	svc.save(_profile(1))
	svc.save(_profile(2))
	var f := FileAccess.open(svc.main_path(), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var loaded := svc.load_profile()
	assert_true(loaded["ok"])
	assert_eq(loaded["source"], "backup1")
	assert_eq((loaded["profile"] as PlayerProfile).hero_level, 1)
	_cleanup()


func test_tampered_save_is_rejected() -> void:
	svc.save(_profile(4))
	var text := FileAccess.get_file_as_string(svc.main_path())
	var f := FileAccess.open(svc.main_path(), FileAccess.WRITE)
	f.store_string(text.replace("\\\"gold\\\":400", "\\\"gold\\\":999999"))
	f.close()
	var loaded := svc.load_profile()
	assert_false(loaded["ok"], "only save was tampered, nothing valid remains")
	assert_has(" ".join(loaded["errors"]), "checksum_mismatch")
	_cleanup()


func test_interrupted_save_recovers_from_temp() -> void:
	# Simulate a crash after main was moved to backup but before tmp became main.
	svc.save(_profile(1))
	svc.save(_profile(2))
	DirAccess.rename_absolute(svc.main_path(), svc.temp_path())
	var loaded := svc.load_profile()
	assert_true(loaded["ok"])
	assert_eq(loaded["source"], "backup1")
	DirAccess.remove_absolute(svc.backup_path(1))
	DirAccess.remove_absolute(svc.backup_path(2))
	loaded = svc.load_profile()
	assert_eq(loaded["source"], "temp")
	assert_eq((loaded["profile"] as PlayerProfile).hero_level, 2)
	_cleanup()


func test_no_save_returns_not_ok() -> void:
	var loaded := svc.load_profile()
	assert_false(loaded["ok"])
	assert_eq(loaded["profile"], null)


func test_newer_schema_is_refused() -> void:
	var data := SaveCodec.encode(_profile(1))
	data["schema"] = SaveCodec.SCHEMA + 1
	assert_eq(SaveCodec.decode(data)["error"], "save_from_newer_version")


func test_not_a_save_is_refused() -> void:
	assert_eq(SaveCodec.decode({"hello": 1})["error"], "not_a_save")
	assert_eq(SaveCodec.decode("text")["error"], "not_a_save")


func test_migration_chain_runs_in_order() -> void:
	# Pretend the current schema is 3 and the save is version 1.
	var old := SaveCodec.encode(_profile(2))
	var steps := {
		1: func(d: Dictionary) -> Dictionary:
			d["profile"]["hero_level"] = int(d["profile"]["hero_level"]) + 10
			return d,
		2: func(d: Dictionary) -> Dictionary:
			d["profile"]["echo_relic"] = "migrated"
			return d,
	}
	var result := SaveCodec.decode(old, 3, steps)
	assert_true(result["ok"], str(result["error"]))
	assert_eq(result["migrated_from"], 1)
	var p: PlayerProfile = result["profile"]
	assert_eq(p.hero_level, 12)
	assert_eq(p.echo_relic, "migrated")


func test_missing_migration_step_fails_safely() -> void:
	var old := SaveCodec.encode(_profile(2))
	var result := SaveCodec.decode(old, 2, {})
	assert_false(result["ok"])
	assert_eq(result["error"], "no_migration_from_1")

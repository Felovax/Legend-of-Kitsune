class_name SaveCodec
extends RefCounted
## Turns a PlayerProfile into a versioned save dictionary and back.
##
## When the save format changes:
##   1. bump SCHEMA,
##   2. add a step to `steps()` that upgrades a dictionary from the previous
##      version (keyed by the version it upgrades FROM),
##   3. add a test with a real old save.
## Never edit an old step once a version has shipped.

const SCHEMA := 1
const GAME_ID := "legend_of_kitsune"


## from_version -> Callable(data: Dictionary) -> Dictionary
static func steps() -> Dictionary:
	return {}


static func encode(profile: PlayerProfile) -> Dictionary:
	return {"game": GAME_ID, "schema": SCHEMA, "profile": profile.to_dict()}


## Returns {ok: bool, profile: PlayerProfile|null, error: String, migrated_from: int}.
static func decode(data: Variant, target_schema: int = SCHEMA, migration_steps: Dictionary = steps()) -> Dictionary:
	var out := {"ok": false, "profile": null, "error": "", "migrated_from": -1}
	if not data is Dictionary or data.get("game") != GAME_ID:
		out["error"] = "not_a_save"
		return out
	var d: Dictionary = (data as Dictionary).duplicate(true)
	var version := int(d.get("schema", 0))
	if version > target_schema:
		out["error"] = "save_from_newer_version"
		return out
	if version < target_schema:
		out["migrated_from"] = version
	while version < target_schema:
		if not migration_steps.has(version):
			out["error"] = "no_migration_from_%d" % version
			return out
		d = (migration_steps[version] as Callable).call(d)
		version += 1
		d["schema"] = version
	if not d.get("profile") is Dictionary:
		out["error"] = "missing_profile"
		return out
	out["profile"] = PlayerProfile.from_dict(d["profile"])
	out["ok"] = true
	return out

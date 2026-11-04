class_name ContentSchema
extends RefCounted
## The vocabulary content files may use. Adding a new relic only needs data;
## adding a new trigger, action, status or stat needs code in BattleSim too.

const TRIGGERS: PackedStringArray = [
	"passive",            # stat changes applied before the fight
	"fight_start",
	"on_hit",             # after the owner's basic attack hits
	"on_crit",
	"every_n_attacks",    # needs "n"
	"every_seconds",      # needs "seconds"
	"on_kill",
	"on_damage_taken",
	"hp_below",           # needs "threshold_bp"; fires once per fight
	"on_status_applied",  # needs "status"; the owner applied that status
]

const ACTIONS: PackedStringArray = ["apply_status", "damage", "heal", "shield", "modify_stat", "consume_burst"]
const TARGETS: PackedStringArray = ["target", "self", "all_enemies", "other_enemies", "random_enemy"]
const STATUSES: PackedStringArray = ["burn", "chill", "freeze", "shock"]
const STATS: PackedStringArray = [
	"atk_bp", "crit_bp", "crit_dmg_bp", "aps_bonus_bp", "lifesteal_bp", "armor_bp", "chain_targets", "chain_ratio_bp",
]
const RARITIES: PackedStringArray = ["common", "rare", "epic", "legendary"]
const ENEMY_ROLES: PackedStringArray = ["normal", "elite", "boss"]
const HERO_STATS: PackedStringArray = ["hp", "atk", "aps_milli", "crit_bp", "crit_dmg_bp", "armor_bp"]
const ENEMY_STATS: PackedStringArray = ["hp", "atk", "aps_milli", "armor_bp"]

class_name Palette
extends RefCounted
## Colours for the bright chibi look. Change them here, not in screens.

const SKY := Color("#8fd3ff")
const SKY_DEEP := Color("#5bb8f0")
const GRASS := Color("#7bd35a")
const CREAM := Color("#fff3d6")
const CREAM_DARK := Color("#f3dfb2")
const OUTLINE := Color("#5a3a1e")
const INK := Color("#3b2414")
const INK_SOFT := Color("#7a5a3a")
const WHITE := Color("#ffffff")

const GOLD := Color("#ffcf3f")
const GOLD_DARK := Color("#e8a91a")
const ORANGE := Color("#ff9b3d")
const GREEN := Color("#5fd35a")
const GREEN_DARK := Color("#3a9e36")
const RED := Color("#ff4b4b")
const BLUE := Color("#4aa8ff")
const PURPLE := Color("#b46bff")

const HP := Color("#6de07a")
const HP_ENEMY := Color("#ff5d6c")
const SHIELD := Color("#9fd8ff")

const ELEMENT := {
	"ember": Color("#ff6b3d"), "frost": Color("#5fd0f0"), "storm": Color("#ffd43d"),
	"chain": Color("#b46bff"), "edge": Color("#c8d2dc"), "life": Color("#ff5d7a"),
	"ward": Color("#4aa8ff"), "tempo": Color("#5fd35a"),
}

const RARITY := {
	"common": Color("#b8c0c8"), "rare": Color("#4aa8ff"), "epic": Color("#b46bff"), "legendary": Color("#ffa53a"),
}

const DOOR := {
	"fight": Color("#ff9b3d"), "elite": Color("#ff4b4b"), "boss": Color("#b42d3c"),
	"shrine": Color("#5fd35a"), "treasure": Color("#ffcf3f"), "event": Color("#b46bff"),
}


static func element_of(tags: Array) -> Color:
	return ELEMENT.get(tags[0], ORANGE) if not tags.is_empty() else ORANGE

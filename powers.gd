extends RefCounted
## Power-up bubbles. char: the letter that places one in a level chunk (see levels.gd).
## time: how long it lasts (0 = until you get hit or fall). art: 8 x 8 icon (pixel_art.gd).

const POWERS := {
	"speed": {"char": "!", "name": "SPEED BOOST", "time": 12.0, "tint": Color(1.5, 0.75, 0.4), "art": [
		"........",
		"....rrr.",
		"....rrr.",
		"ww..rrrr",
		"...rrrrr",
		"ww.rrrrr",
		"...ccccc",
		"........"]},
	"jump": {"char": "+", "name": "EXTRA JUMP", "time": 0.0, "tint": Color(1.2, 1.3, 1.6), "art": [
		"......ww",
		"....wwws",
		"...wwwss",
		".wwwwss.",
		"wwwwss..",
		".wwss...",
		"..ss....",
		"........"]},
	"super": {"char": "@", "name": "SUPER BOUNCE", "time": 12.0, "tint": Color(0.6, 1.5, 0.7), "art": [
		"...gg...",
		"..gggg..",
		".gggggg.",
		"...gg...",
		"eeeeeeee",
		".e....e.",
		"eeeeeeee",
		".e....e."]},
	"magnet": {"char": "$", "name": "COIN MAGNET", "time": 15.0, "tint": Color(1.6, 0.6, 0.7), "art": [
		"ee....ee",
		"ee....ee",
		"rr....rr",
		"rr....rr",
		"rrr..rrr",
		".rrrrrr.",
		"..rrrr..",
		"........"]},
	"shield": {"char": "&", "name": "BUBBLE SHIELD", "time": 0.0, "tint": Color(0.6, 1.1, 1.8), "art": [
		".ssssss.",
		"sbbbbbbs",
		"sbwbbbbs",
		"sbbbbbbs",
		".sbbbbs.",
		"..sbbs..",
		"...ss...",
		"........"]},
}

## Most extra jumps a bear can stack up: two make a triple jump.
const MAX_AIR_JUMPS := 2


static func by_char(ch: String) -> String:
	for k in POWERS:
		if POWERS[k]["char"] == ch:
			return k
	return ""

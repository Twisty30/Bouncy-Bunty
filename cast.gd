extends RefCounted
## The characters: who they are and how to draw them from the sprites we have.

const BEAR := preload("res://little-bear-idle.png")
const WALK := preload("res://little-bear-walk.png")
const CHARS := preload("res://kenney_pixel-platformer/Tilemap/tilemap-characters_packed.png")

## bear: drawn from the little bear sprite. char: tile number in the Kenney characters sheet.
const CAST := {
	"BUNTY": {"bear": true, "tint": Color(1, 1, 1), "color": Color(1.0, 0.75, 0.45)},
	"MISS BEAR": {"bear": true, "tint": Color(1.5, 1.05, 1.9), "bow": true, "color": Color(1.0, 0.6, 0.9)},
	"KING BEAR": {"bear": true, "tint": Color(0.72, 0.5, 0.62), "crown": true, "color": Color(1.0, 0.8, 0.25)},
	"REBOUND KING": {"bear": true, "tint": Color(0.75, 0.35, 1.1), "crown": true, "color": Color(0.85, 0.5, 1.0)},
	"CAPTAIN CLANK": {"char": 21, "tint": Color(1, 1, 1), "color": Color(0.4, 0.75, 1.0)},
	"DRILL SERGEANT": {"char": 15, "tint": Color(1, 1, 1), "color": Color(1.0, 0.45, 0.3)},
	"BLOCKHEAD": {"char": 11, "tint": Color(0.6, 0.9, 1.4), "color": Color(0.6, 0.9, 1.0)},
	"BARON VON FLAP": {"char": 24, "tint": Color(1.1, 0.8, 1.3), "color": Color(0.8, 0.6, 1.0)},
	"BOT": {"char": 18, "tint": Color(1, 1, 1), "color": Color(0.5, 0.8, 1.0)},
	"": {"color": Color(1, 0.96, 0.84)},
}


static func char_tex(idx: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = CHARS
	a.region = Rect2(idx % 9 * 24, idx / 9 * 24, 24, 24)
	return a


static func color(who: String) -> Color:
	return CAST.get(who, CAST[""])["color"]


## A character as a node whose origin is at its feet. px = size of one art pixel on screen.
## The sprite is the child called "spr".
static func actor(who: String, px: float) -> Node2D:
	var info: Dictionary = CAST.get(who, CAST["BUNTY"])
	var root := Node2D.new()
	var spr := Sprite2D.new()
	spr.name = "spr"
	spr.centered = false
	if info.get("bear", false):
		spr.texture = BEAR
		spr.offset = Vector2(-16.5, -32)
	else:
		spr.texture = char_tex(info["char"])
		spr.offset = Vector2(-12, -24)
	spr.scale = Vector2(px, px)
	spr.modulate = info.get("tint", Color.WHITE)
	root.add_child(spr)
	if who == "BUNTY":
		load("res://skins.gd").dress(spr)   # wears what was bought in the Bear Shop
	if info.get("crown", false):
		var crown := Polygon2D.new()
		crown.polygon = PackedVector2Array([Vector2(-6, -20), Vector2(6, -20), Vector2(6, -25),
			Vector2(3, -22), Vector2(0, -26), Vector2(-3, -22), Vector2(-6, -25)])
		crown.color = Color(1, 0.8, 0.2)
		crown.scale = Vector2(px, px)
		crown.name = "crown"
		root.add_child(crown)
		var jewel := Polygon2D.new()
		jewel.polygon = PackedVector2Array([Vector2(-1, -22), Vector2(1, -22), Vector2(1, -20), Vector2(-1, -20)])
		jewel.color = Color(0.9, 0.2, 0.4)
		jewel.scale = Vector2(px, px)
		root.add_child(jewel)
	if info.get("bow", false):
		var bow := Polygon2D.new()
		bow.polygon = PackedVector2Array([Vector2(-5, -22), Vector2(-1, -20), Vector2(3, -22),
			Vector2(3, -17), Vector2(-1, -19), Vector2(-5, -17)])
		bow.color = Color(1.0, 0.3, 0.55)
		bow.scale = Vector2(px, px)
		root.add_child(bow)
	return root

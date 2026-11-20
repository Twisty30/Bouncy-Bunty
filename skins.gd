extends RefCounted
## Bear Shop goods: fur colours (a recolour shader on the bear sprite) and hats (pixel art
## that sits on the bear's head). Bought with the coins banked at the end of each level.

const PixelArt := preload("res://pixel_art.gd")

## hue: shift round the colour wheel, sat / val: multipliers, rainbow: cycles the hue,
## shine: a glint that sweeps across.
const SKINS := [
	{"id": "classic", "name": "CLASSIC", "price": 0, "hue": 0.0, "sat": 1.0, "val": 1.0},
	{"id": "honey", "name": "HONEY", "price": 120, "hue": 0.05, "sat": 1.15, "val": 1.3},
	{"id": "mint", "name": "MINT", "price": 180, "hue": 0.36, "sat": 0.85, "val": 1.2},
	{"id": "berry", "name": "BERRY", "price": 180, "hue": -0.1, "sat": 1.1, "val": 1.25},
	{"id": "ocean", "name": "OCEAN", "price": 250, "hue": 0.55, "sat": 1.0, "val": 1.15},
	{"id": "polar", "name": "POLAR", "price": 320, "hue": 0.0, "sat": 0.12, "val": 1.5},
	{"id": "shadow", "name": "SHADOW", "price": 320, "hue": 0.7, "sat": 0.35, "val": 0.55},
	{"id": "rainbow", "name": "RAINBOW", "price": 600, "hue": 0.0, "sat": 1.5, "val": 1.3, "rainbow": 1.0},
	{"id": "golden", "name": "GOLDEN", "price": 900, "hue": 0.04, "sat": 1.2, "val": 1.55, "shine": 0.45},
]

## Art is drawn in the bear sprite's own pixels (32 x 32, head top between the ears at 16, 15).
const HATS := [
	{"id": "none", "name": "NO HAT", "price": 0, "at": Vector2.ZERO, "art": []},
	{"id": "party", "name": "PARTY HAT", "price": 80, "at": Vector2(13, 7), "art": [
		"...y...",
		"..yyy..",
		"...p...",
		"..ppb..",
		"..pbp..",
		".pbppb.",
		".bppbp.",
		"ppbppbp",
		"kkkkkkk"]},
	{"id": "flower", "name": "FLOWER", "price": 100, "at": Vector2(18, 9), "art": [
		".p.p.",
		"ppypp",
		".pyp.",
		"..G..",
		"..G.."]},
	{"id": "bow", "name": "BIG BOW", "price": 120, "at": Vector2(16, 10), "art": [
		"pp...pp",
		"pppkppp",
		"ppprppp",
		"pppkppp",
		"pp...pp"]},
	{"id": "cap", "name": "BALL CAP", "price": 150, "at": Vector2(10, 11), "art": [
		"...bbbbb....",
		"..bbbwbbb...",
		"..bbbbbbb...",
		"..kkkkkkbbbb"]},
	{"id": "shades", "name": "COOL SHADES", "price": 200, "at": Vector2(14, 19), "art": [
		"kkkkkkkkk",
		"kwkk.kwkk",
		".kk...kk."]},
	{"id": "tophat", "name": "TOP HAT", "price": 260, "at": Vector2(11, 7), "art": [
		"..wwwwwww..",
		"..wdddddw..",
		"..wdddddw..",
		"..wdddddw..",
		"..wrrrrrw..",
		"wwwdddddwww",
		"wdddddddddw",
		"wwwwwwwwwww"]},
	{"id": "halo", "name": "HALO", "price": 420, "at": Vector2(11, 6), "bob": 1.0, "art": [
		".yyyyyyyyy.",
		"y.........y",
		".yyyyyyyyy."]},
	{"id": "crown", "name": "CROWN", "price": 650, "at": Vector2(12, 9), "art": [
		"y...y...y",
		"yy.yyy.yy",
		"yyyyyyyyy",
		"yryybyyry",
		"yyyyyyyyy"]},
]

const SHADER := preload("res://skin.gdshader")

static func skin(id: String) -> Dictionary:
	for s in SKINS:
		if s["id"] == id:
			return s
	return SKINS[0]


static func hat(id: String) -> Dictionary:
	for h in HATS:
		if h["id"] == id:
			return h
	return HATS[0]


static func item(id: String) -> Dictionary:
	for s in SKINS + HATS:
		if s["id"] == id:
			return s
	return {}


static func is_hat(id: String) -> bool:
	for h in HATS:
		if h["id"] == id:
			return true
	return false


## Dress a bear sprite (Sprite2D or AnimatedSprite2D drawn with offset (-16.5, -32)).
## Empty ids use what the player has equipped.
static func dress(spr: CanvasItem, skin_id: String = "", hat_id: String = "") -> void:
	if skin_id == "":
		skin_id = Game.equipped("skin")
	if hat_id == "":
		hat_id = Game.equipped("hat")
	var s := skin(skin_id)
	if s["id"] == "classic":
		spr.material = null
	else:
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("hue", s["hue"])
		m.set_shader_parameter("sat", s["sat"])
		m.set_shader_parameter("val", s["val"])
		m.set_shader_parameter("rainbow", s.get("rainbow", 0.0))
		m.set_shader_parameter("shine", s.get("shine", 0.0))
		spr.material = m
	var old := spr.get_node_or_null("hat")
	if old != null:
		spr.remove_child(old)
		old.queue_free()
	var h := hat(hat_id)
	if not h["art"].is_empty():
		var art: Node2D = PixelArt.make(h["art"], h["at"])
		art.name = "hat"
		art.hat = true
		art.bob = h.get("bob", 0.0)
		spr.add_child(art)

extends Node2D
## Tiny pixel art drawn from text rows, one character per pixel (see PALETTE). Used for the
## hats from the Bear Shop and the power-up icons. One art pixel is one unit, so scale the node.
##
## As a hat it is a child of a bear sprite and draws in that sprite's pixel space; it mirrors
## itself whenever the sprite is flipped.

const PALETTE := {
	"k": Color(0.11, 0.09, 0.2),     # ink
	"d": Color(0.24, 0.21, 0.34),    # dark slate
	"w": Color(1, 1, 1),
	"c": Color(1, 0.96, 0.84),       # cream
	"y": Color(1, 0.82, 0.22),       # gold
	"o": Color(1, 0.55, 0.15),
	"r": Color(0.92, 0.22, 0.28),
	"p": Color(1.0, 0.45, 0.68),
	"b": Color(0.3, 0.55, 1.0),
	"s": Color(0.55, 0.85, 1.0),     # sky
	"g": Color(0.35, 0.8, 0.35),
	"G": Color(0.2, 0.55, 0.25),
	"v": Color(0.6, 0.4, 0.95),
	"e": Color(0.6, 0.62, 0.7),      # steel
	"n": Color(0.45, 0.28, 0.16),    # brown
}

var rows: Array = []
var at := Vector2.ZERO        # top-left corner, in the parent sprite's pixels (hats)
var hat := false              # sit on a bear sprite and follow its flip
var bob := 0.0                # floats up and down this many pixels (halo)
var glow := false             # gentle pulse
var t := 0.0
var flipped := false
var base := Vector2.ZERO      # where the node was put, before any bobbing


static func make(art: Array, top_left: Vector2 = Vector2.ZERO) -> Node2D:
	var n: Node2D = load("res://pixel_art.gd").new()
	n.rows = art
	n.at = top_left
	return n


func size() -> Vector2:
	var w := 0
	for r: String in rows:
		w = maxi(w, r.length())
	return Vector2(w, rows.size())


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base = position
	_place()
	set_process(hat or bob != 0.0 or glow)


func _process(delta: float) -> void:
	t += delta
	if hat:
		var p := get_parent()
		var f: bool = p != null and p.get("flip_h") == true
		if f != flipped:
			flipped = f
			_place()
	if bob != 0.0:
		_place()
	if glow:
		modulate.a = 0.75 + 0.25 * sin(t * 5.0)


func _place() -> void:
	var y := roundf(sin(t * 3.0) * bob) if bob != 0.0 else 0.0
	if hat:
		# the bear sprite is drawn with offset (-16.5, -32); a flipped sprite mirrors its pixels
		position = Vector2(15.5 if flipped else -16.5, -32 + y)
		scale.x = -1.0 if flipped else 1.0
	elif bob != 0.0:
		position = base + Vector2(0, y)


func _draw() -> void:
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			var ch := r[x]
			if PALETTE.has(ch):
				draw_rect(Rect2(at.x + x, at.y + y, 1, 1), PALETTE[ch])

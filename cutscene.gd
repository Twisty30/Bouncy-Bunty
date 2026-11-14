extends Node2D
## cutscenes

const BEAR := preload("res://little-bear-idle.png")

const INTRO := [
	["", "Once upon a time, in the bouncy hills..."],
	["MISS BEAR", "What a lovely day for bouncing, Bunty!"],
	["KING BEAR", "HO HO HO! I am KING BEAR, ruler of every hill!"],
	["KING BEAR", "Miss Bear will be my queen! Tonight I'll carry her off to my castle!"],
	["MISS BEAR", "Never! Bunty, help!"],
	["BUNTY", "You'll have to get past me first!"],
	["KING BEAR", "Then come to my castle... if you can make it through 14 lands! MWAHAHA!"],
	["BUNTY", "Let's go! We'll stop him before nightfall!"],
]
const ENDING := [
	["KING BEAR", "Ow ow ow... you bounced right on my crown!"],
	["KING BEAR", "Fine! I give up! I'll leave Miss Bear alone!"],
	["MISS BEAR", "Bunty, you did it! You saved me!"],
	["BUNTY", "Nobody kidnaps Miss Bear on my watch!"],
	["", "THE END - Thanks for playing!"],
]

var lines: Array
var index := 0
var text := Label.new()
var king: Sprite2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.5, 0.85, 0.95) if Game.cutscene == "intro" else Color(0.25, 0.2, 0.35))
	lines = INTRO if Game.cutscene == "intro" else ENDING
	if Game.player_schemes.size() > 1:
		lines = lines.map(func(l: Array) -> Array:
			return [l[0].replace("BUNTY", "BUNTY & FRIENDS"), l[1].replace(" me ", " us ").replace("my watch", "our watch")])
	var ground := ColorRect.new()
	ground.color = Color(0.45, 0.3, 0.2)
	ground.position = Vector2(0, 470)
	ground.size = Vector2(1152, 200)
	add_child(ground)
	for i in Game.player_schemes.size():
		_bear(Vector2(400 - i * 70, 470), 3, Game.TINTS[i])
	_bear(Vector2(500, 470), 3, Color(1.5, 1.05, 1.9)).flip_h = true
	king = _bear(Vector2(800, 470), 9, Color(0.72, 0.5, 0.62))
	king.flip_h = true
	var crown := Polygon2D.new()
	crown.polygon = PackedVector2Array([Vector2(-6, -20), Vector2(6, -20), Vector2(6, -25), Vector2(3, -22), Vector2(0, -26), Vector2(-3, -22), Vector2(-6, -25)])
	crown.color = Color(1, 0.8, 0.2)
	king.add_child(crown)
	king.visible = Game.cutscene == "ending"
	if Game.cutscene == "ending":
		king.rotation = -1.2
	text.position = Vector2(60, 60)
	text.size = Vector2(1032, 120)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(text)
	show_line()


func _bear(pos: Vector2, size: float, tint: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = BEAR
	s.centered = false
	s.offset = Vector2(-16, -32)
	s.scale = Vector2(size, size)
	s.position = pos
	s.modulate = tint
	add_child(s)
	return s


func show_line() -> void:
	var who: String = lines[index][0]
	text.text = (who + ":\n" if who != "" else "") + lines[index][1]
	if who == "KING BEAR" and not king.visible:
		king.visible = true
		Game.sfx("roar")
	Game.sfx("blip ")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("back"):
		Game.cutscene_done()
	elif Input.is_action_just_pressed("next"):
		index += 1
		if index >= lines.size():
			Game.cutscene_done()
		else:
			if Game.cutscene == "intro" and index == lines.size() - 1:
				king.visible = false
			show_line()

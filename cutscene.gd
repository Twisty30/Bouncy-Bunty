extends Node2D
## Story scenes. Each scene is a list of steps that run one after another on a little stage:
##   ["bg", theme]                       scenery ("grass", "sand", "snow", "storm", "castle")
##   ["add", id, who, x, y, facing, px]  put a character on stage (y: 0 = on the ground, - = up)
##   ["prop", id, fx, x, y, scale]       a looping pixelfx effect as a prop
##   ["say", who, text]                  a line of dialogue (waits for the player)
##   ["go", id, x, y, seconds]           move and wait        ["slide", ...] the same, no wait
##   ["drop", id]                        fall from the sky and land with a thud
##   ["hop", id]  ["face", id, dir]  ["show", id]  ["hide", id]  ["tint", id, color]
##   ["fx", name, x, y, scale]  ["sfx", name, pitch]  ["shake", amount]  ["flash", color]
##   ["wait", seconds]  ["music", song, pitch]  ["title", text, small text, seconds]
## The stage is 1152 wide; x = 576 is the middle of the screen.

const Cast := preload("res://cast.gd")
const Ui := preload("res://ui.gd")
const Levels := preload("res://levels.gd")
const DialogScript := preload("res://dialog.gd")
const BackdropScript := preload("res://backdrop.gd")
const TILES := preload("res://kenney_pixel-platformer/Tilemap/tilemap_packed.png")

const FLOOR := 468.0
const PURPLE := Color(0.75, 0.35, 1.1)

const SCENES := {
	"intro": [
		["bg", "grass"], ["music", "menu", 1.0],
		["prop", "glow", "sunburst", 760, -150, 2.0],
		["prop", "crystal", "shard", 760, -70, 3.0],
		["add", "bunty", "BUNTY", 360, 0, 1, 4.0],
		["add", "miss", "MISS BEAR", 500, 0, -1, 4.0],
		["wait", 0.8],
		["title", "THE BOUNCY HILLS", "ONE YEAR AFTER KING BEAR'S DEFEAT", 2.4],
		["say", "MISS BEAR", "Look, Bunty! The Rebound Crystal is shining extra bright today."],
		["hop", "bunty"],
		["say", "BUNTY", "It's what keeps the whole world bouncy. Guarding it is the best job ever!"],
		["music", "", 1.0], ["shake", 6.0], ["sfx", "roar", 0.8], ["flash", Color(1, 1, 1, 0.5)],
		["face", "bunty", 1], ["face", "miss", 1],
		["fx", "alert", 360, -110, 2.0], ["fx", "alert", 500, -110, 2.0],
		["wait", 0.7],
		["add", "king", "KING BEAR", 930, 0, -1, 7.0], ["drop", "king"],
		["music", "boss", 0.85],
		["say", "KING BEAR", "HO HO HO! Did you miss me, little bouncer?"],
		["say", "BUNTY", "King Bear?! We sent you packing a year ago!"],
		["say", "KING BEAR", "And this time I brought friends. GENERALS! FRONT AND CENTRE!"],
		["fx", "summon", 1040, 0, 1.6], ["sfx", "whoosh", 0.8], ["wait", 0.5],
		["add", "clank", "CAPTAIN CLANK", 1040, 0, -1, 5.0], ["hop", "clank"],
		["fx", "dirt_boom", 830, 0, 1.3], ["sfx", "break", 0.7], ["wait", 0.3],
		["add", "drill", "DRILL SERGEANT", 830, 0, -1, 4.5], ["hop", "drill"],
		["add", "block", "BLOCKHEAD", 1000, -620, -1, 4.5], ["slide", "block", 1000, -250, 0.4],
		["add", "flap", "BARON VON FLAP", 1300, -420, -1, 4.5], ["go", "flap", 860, -300, 0.5],
		["sfx", "roar", 1.2], ["shake", 5.0],
		["say", "KING BEAR", "The crystal's power will be MINE. Every last bounce of it!"],
		["go", "king", 800, 0, 0.35],
		["fx", "charge", 760, -90, 2.0], ["sfx", "zap", 0.6], ["wait", 1.3],
		["hide", "crystal"], ["hide", "glow"],
		["fx", "dark_boom", 760, 0, 1.6], ["sfx", "explosion", 0.7], ["flash", Color(0.8, 0.5, 1.0, 0.9)], ["shake", 16.0],
		["wait", 1.6],
		["say", "", "CRACK! The Rebound Crystal split into five shards."],
		["say", "KING BEAR", "One shard each! Scatter! Let the little bear TRY to catch us all!"],
		["sfx", "whoosh", 0.7],
		["slide", "clank", 1500, 0, 0.6], ["slide", "drill", 1500, 0, 0.7], ["slide", "block", 1000, -900, 0.6],
		["slide", "flap", 1500, -700, 0.6], ["go", "king", 1500, -200, 0.8],
		["music", "menu", 0.9],
		["face", "miss", -1],
		["say", "MISS BEAR", "Bunty... the mushrooms. They've gone all floppy!"],
		["hop", "bunty"],
		["say", "BUNTY", "Not for long. I'm bringing every shard home."],
		["say", "MISS BEAR", "Then remember: claws out, and never stop bouncing!"],
		["face", "bunty", 1], ["sfx", "dash", 1.0], ["go", "bunty", 1400, 0, 0.7],
		["wait", 0.4],
	],
	"world2": [
		["bg", "sand"], ["music", "desert", 1.0],
		["add", "bunty", "BUNTY", -100, 0, 1, 4.0],
		["go", "bunty", 380, 0, 1.0],
		["title", "DUNE DESERT", "WORLD 2", 2.0],
		["say", "BUNTY", "One shard back, and the hills are bouncing again. Phew, it's hot out here."],
		["fx", "quake", 800, 0, 1.6], ["shake", 5.0], ["sfx", "break", 0.7], ["wait", 0.6],
		["fx", "dirt_boom", 800, 0, 1.4],
		["add", "drill", "DRILL SERGEANT", 800, 0, -1, 5.0], ["hop", "drill"], ["sfx", "roar", 1.3],
		["say", "DRILL SERGEANT", "FRESH RECRUIT SPOTTED! Hup, two, three, four! You'll never reach my shard!"],
		["fx", "dirt_boom", 800, 0, 1.4], ["hide", "drill"], ["sfx", "break", 0.6],
		["say", "BUNTY", "...Great. A shouty one."],
		["sfx", "dash", 1.0], ["go", "bunty", 1400, 0, 0.8],
	],
	"world3": [
		["bg", "snow"], ["music", "frost", 1.0],
		["add", "bunty", "BUNTY", -100, 0, 1, 4.0],
		["go", "bunty", 400, 0, 1.0],
		["title", "FROST PEAKS", "WORLD 3", 2.0],
		["say", "BUNTY", "Brrr! Two shards down. My paws are f-f-freezing."],
		["add", "block", "BLOCKHEAD", 800, -700, -1, 5.0], ["go", "block", 800, 0, 0.3],
		["fx", "slam", 800, 0, 1.6], ["fx", "ice_spikes", 840, 0, 1.3], ["sfx", "slam", 1.0], ["shake", 12.0],
		["hop", "bunty"], ["wait", 0.8],
		["say", "BLOCKHEAD", "ICE. SLIPPY. BEAR. SLIDE."],
		["say", "BUNTY", "A talking block. Sure. Why not."],
		["go", "block", 800, -800, 0.5],
		["sfx", "dash", 1.0], ["go", "bunty", 1400, 0, 0.9],
	],
	"world4": [
		["bg", "storm"], ["music", "storm", 1.0],
		["add", "bunty", "BUNTY", -100, 0, 1, 4.0],
		["go", "bunty", 400, 0, 1.0],
		["title", "THUNDER HEIGHTS", "WORLD 4", 2.0],
		["say", "BUNTY", "Three shards! The fourth one is somewhere up in those clouds."],
		["fx", "bolt", 620, 0, 1.4], ["wait", 0.8], ["flash", Color(1, 1, 1, 0.7)], ["sfx", "zap", 0.8], ["shake", 10.0],
		["hop", "bunty"], ["wait", 0.6],
		["add", "flap", "BARON VON FLAP", 1300, -420, -1, 5.0], ["go", "flap", 820, -260, 0.6],
		["say", "BARON VON FLAP", "Ha ha ha! Zat was only a warning shot, little bear. Ze sky belongs to ze Baron!"],
		["say", "BUNTY", "Then I'll just have to bounce higher than you fly."],
		["go", "flap", 1400, -600, 0.5],
		["sfx", "dash", 1.0], ["go", "bunty", 1400, 0, 0.8],
	],
	"world5": [
		["bg", "castle"], ["music", "castle", 1.0],
		["add", "bunty", "BUNTY", -100, 0, 1, 4.0],
		["go", "bunty", 380, 0, 1.0],
		["title", "KING'S CASTLE", "WORLD 5", 2.0],
		["say", "BUNTY", "Four shards. Only King Bear's is left."],
		["prop", "fire1", "torch", 700, -40, 2.0], ["prop", "fire2", "torch", 980, -40, 2.0],
		["add", "king", "KING BEAR", 840, -230, -1, 6.0], ["fx", "summon", 840, -230, 1.6], ["sfx", "roar", 0.8], ["shake", 6.0],
		["say", "KING BEAR", "So you beat my generals. No matter! My castle is full of fire, saws and things that go SQUISH."],
		["say", "KING BEAR", "Come and find me, Bunty... if you can!"],
		["fx", "dark_boom", 840, -150, 1.2], ["hide", "king"], ["sfx", "explosion", 0.9], ["flash", Color(0.8, 0.5, 1.0, 0.6)],
		["wait", 1.0],
		["say", "BUNTY", "One last climb. Here I come!"],
		["sfx", "dash", 1.0], ["go", "bunty", 1400, 0, 0.8],
	],
	"ending": [
		["bg", "grass"], ["music", "menu", 1.0],
		["add", "bunty", "BUNTY", 380, 0, 1, 4.0],
		["add", "miss", "MISS BEAR", 520, 0, -1, 4.0],
		["add", "king", "KING BEAR", 960, 0, -1, 6.0], ["tint", "king", Color(0.72, 0.5, 0.62)],
		["wait", 0.6],
		["say", "MISS BEAR", "Bunty! You're back! And you brought..."],
		["say", "BUNTY", "All five shards. Stand back!"],
		["prop", "s1", "shard", 640, -330, 2.0], ["sfx", "gem", 0.9], ["wait", 0.25],
		["prop", "s2", "shard", 700, -380, 2.0], ["sfx", "gem", 1.0], ["wait", 0.25],
		["prop", "s3", "shard", 760, -400, 2.0], ["sfx", "gem", 1.1], ["wait", 0.25],
		["prop", "s4", "shard", 820, -380, 2.0], ["sfx", "gem", 1.2], ["wait", 0.25],
		["prop", "s5", "shard", 880, -330, 2.0], ["sfx", "gem", 1.3], ["wait", 0.5],
		["slide", "s1", 760, -80, 0.7], ["slide", "s2", 760, -80, 0.7], ["slide", "s3", 760, -80, 0.7],
		["slide", "s4", 760, -80, 0.7], ["go", "s5", 760, -80, 0.7],
		["hide", "s1"], ["hide", "s2"], ["hide", "s3"], ["hide", "s4"], ["hide", "s5"],
		["fx", "mana_burst", 760, -80, 2.4], ["fx", "holy_pillar", 760, 0, 2.2], ["flash", Color(1, 1, 1, 0.9)],
		["sfx", "powerup", 0.8], ["shake", 10.0],
		["prop", "glow", "sunburst", 760, -150, 2.0],
		["prop", "crystal", "shard", 760, -70, 3.0],
		["wait", 1.4],
		["say", "", "The Rebound Crystal was whole again, and the whole world went BOING."],
		["hop", "bunty"], ["hop", "miss"],
		["say", "KING BEAR", "...Fine. You win. Again."],
		["say", "KING BEAR", "But... could I maybe have ONE go on the mushrooms? They look really fun."],
		["say", "MISS BEAR", "Only if you ask nicely. And no stealing!"],
		["hop", "king"], ["sfx", "bounce", 0.8],
		["say", "BUNTY", "Last one to the meadow is a floppy mushroom!"],
		["music", "title", 1.0],
		["fx", "firework", 300, -300, 2.4], ["sfx", "explosion", 1.5], ["wait", 0.4],
		["fx", "firework", 860, -360, 2.4], ["sfx", "explosion", 1.6], ["wait", 0.4],
		["fx", "firework", 580, -400, 2.4], ["sfx", "explosion", 1.4], ["fx", "confetti", 576, -100, 4.0],
		["title", "THE END", "THANK YOU FOR PLAYING BOUNCY BUNTY REBOUND", 4.5],
		["fx", "firework", 400, -340, 2.4], ["fx", "firework", 760, -300, 2.4], ["sfx", "explosion", 1.5],
		["title", "{gems} OF 135 GEMS FOUND", "CAN YOU FIND THEM ALL AND EARN EVERY S RANK?", 4.0],
	],
}

var steps: Array = []
var actors := {}
var stage := Node2D.new()
var ground: TileMapLayer
var backdrop: Node
var dialog: CanvasLayer
var ui := CanvasLayer.new()
var flash_rect := ColorRect.new()
var shake_amt := 0.0
var t := 0.0
var leaving := false


func _ready() -> void:
	steps = SCENES.get(Game.cutscene, SCENES["intro"])
	backdrop = BackdropScript.new()
	backdrop.horizon = 0.36
	add_child(backdrop)
	add_child(stage)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(18, 18)
	var src := TileSetAtlasSource.new()
	src.texture = TILES
	src.texture_region_size = Vector2i(18, 18)
	for y in 9:
		for x in 20:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src)
	ground = TileMapLayer.new()
	ground.tile_set = ts
	ground.scale = Vector2(2, 2)
	ground.collision_enabled = false
	stage.add_child(ground)
	dialog = DialogScript.new()
	add_child(dialog)
	dialog.line_shown.connect(_on_line)
	dialog.esc_closes = false   # Esc skips the whole scene here, not one line

	ui.layer = 40
	add_child(ui)
	# cinema bars
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0.05, 0.04, 0.1)
		bar.anchor_right = 1.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if top:
			bar.offset_bottom = 56
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -20
		ui.add_child(bar)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash_rect)
	var skip := Ui.button("SKIP", _leave, 14, Vector2(110, 40))
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -126
	skip.offset_right = -16
	skip.offset_top = 8
	skip.offset_bottom = 48
	skip.focus_mode = Control.FOCUS_NONE
	ui.add_child(skip)
	_place_stage()
	_play()


func _place_stage() -> void:
	var view := get_viewport().get_visible_rect().size
	stage.position = Vector2((view.x - 1152.0) / 2.0, view.y - 648.0) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt


func _process(delta: float) -> void:
	t += delta
	shake_amt = move_toward(shake_amt, 0.0, 30.0 * delta)
	_place_stage()
	backdrop.scroll(t * 20.0, 252.0, delta)
	# everybody breathes
	for id in actors:
		var a: Node2D = actors[id]
		if a.has_meta("char"):
			a.get_node("spr").scale.y = a.get_meta("px") * (1.0 + sin(t * 3.0 + a.position.x) * 0.025)
			if a.position.y < -40.0:      # fliers bob
				a.get_node("spr").position.y = sin(t * 4.0 + a.position.x) * 8.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("back"):
		_leave()


func _leave() -> void:
	if leaving:
		return
	leaving = true
	Game.cutscene_done()


func _set_bg(theme: String) -> void:
	backdrop.set_theme(theme)
	var info: Dictionary = Levels.THEMES[theme]
	ground.modulate = info["tint"]
	ground.clear()
	for x in range(-24, 60):
		var top: int = info["top"] + 2
		ground.set_cell(Vector2i(x, 13), 0, Vector2i(top % 20, top / 20))
		for y in range(14, 24):
			var fill := 122
			ground.set_cell(Vector2i(x, y), 0, Vector2i(fill % 20, fill / 20))


func _on_line(who: String, _index: int) -> void:
	for id in actors:
		var a: Node2D = actors[id]
		if a.get_meta("who", "") == who:
			_hop(a, 14.0)


func _hop(a: Node2D, height: float = 46.0) -> void:
	var base := a.position.y
	var tw := a.create_tween()
	tw.tween_property(a, "position:y", base - height, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(a, "position:y", base, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	a.scale = Vector2(0.85, 1.2)
	a.create_tween().tween_property(a, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _face(a: Node2D, dir: int) -> void:
	if not a.has_meta("char"):
		return
	var spr: Sprite2D = a.get_node("spr")
	# the bear art looks right, the Kenney characters look left
	spr.flip_h = dir < 0 if a.get_meta("bear") else dir > 0


func _play() -> void:
	await get_tree().create_timer(0.3).timeout
	for step: Array in steps:
		if leaving:
			return
		await _do(step)
	_leave()


func _do(s: Array) -> void:
	match s[0]:
		"bg":
			_set_bg(s[1])
		"music":
			if s[1] == "":
				Game.music_player.stop()
				Game.track = ""
			else:
				Game.music(s[1], s[2])
		"add":
			var a := Cast.actor(s[2], s[6])
			a.position = Vector2(s[3], FLOOR + s[4])
			a.set_meta("char", true)
			a.set_meta("who", s[2])
			a.set_meta("px", float(s[6]))
			a.set_meta("bear", Cast.CAST[s[2]].get("bear", false))
			stage.add_child(a)
			actors[s[1]] = a
			_face(a, s[5])
		"prop":
			var p := Fx.play(stage, s[2], Vector2(s[3], FLOOR + s[4]), {"scale": s[5], "z": 0})
			actors[s[1]] = p
		"say":
			dialog.say([[s[1], s[2]]])
			await dialog.done
		"go", "slide":
			var a: Node2D = actors[s[1]]
			if a.has_meta("char") and absf(s[2] - a.position.x) > 4.0:
				_face(a, 1 if s[2] > a.position.x else -1)
			var tw := a.create_tween()
			tw.tween_property(a, "position", Vector2(s[2], FLOOR + s[3]), s[4]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			if s[0] == "go":
				await tw.finished
		"drop":
			var a: Node2D = actors[s[1]]
			var home := a.position
			a.position.y -= 700.0
			var tw := a.create_tween()
			tw.tween_property(a, "position:y", home.y, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await tw.finished
			Fx.play(stage, "slam", home, {"scale": 1.6, "z": 3})
			Game.sfx("slam")
			shake_amt = 12.0
			a.scale = Vector2(1.35, 0.7)
			a.create_tween().tween_property(a, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			await get_tree().create_timer(0.5).timeout
		"hop":
			_hop(actors[s[1]])
			Game.sfx("jump", 1.1, 0.6)
			await get_tree().create_timer(0.3).timeout
		"face":
			_face(actors[s[1]], s[2])
		"show":
			actors[s[1]].visible = true
		"hide":
			actors[s[1]].visible = false
		"tint":
			actors[s[1]].get_node("spr").modulate = s[2]
		"fx":
			Fx.play(stage, s[1], Vector2(s[2], FLOOR + s[3]), {"scale": s[4], "z": 3})
		"sfx":
			Game.sfx(s[1], s[2])
		"shake":
			shake_amt = s[1]
		"flash":
			flash_rect.color = s[1]
			flash_rect.create_tween().tween_property(flash_rect, "color:a", 0.0, 0.5)
		"wait":
			await get_tree().create_timer(s[1]).timeout
		"title":
			await _title(s[1], s[2], s[3])


func _title(text: String, small: String, seconds: float) -> void:
	text = text.replace("{gems}", str(Game.total_gems()))
	var box := VBoxContainer.new()
	box.anchor_right = 1.0
	box.offset_top = 110
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(box)
	var big := Ui.label(text, 44, Ui.GOLD, 14)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)
	var sub := Ui.label(small, 16, Ui.CREAM, 8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.modulate.a = 0.0
	box.position.y = 80.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(box, "position:y", 110.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds - 0.8)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)
	await tw.finished

extends Node2D
## da levels

const Levels := preload("res://levels.gd")
const PlayerScript := preload("res://player.gd")
const BossScript := preload("res://boss.gd")
const TILES := preload("res://kenney_pixel-platformer/Tilemap/tilemap_packed.png")

const T := 36
const THEMES := {
	"grass": {"top": 22, "thin": 2, "sky": Color(0.5, 0.85, 0.95)},
	"sand": {"top": 62, "thin": 42, "sky": Color(0.98, 0.8, 0.55)},
	"snow": {"top": 102, "thin": 82, "sky": Color(0.8, 0.9, 0.95)},
	"castle": {"top": 29, "thin": 29, "sky": Color(0.25, 0.2, 0.35)},
}

var players: Array = []
var checkpoint := Vector2.ZERO
var goal_pos := Vector2(-9999, 0)
var boss: Node = null
var theme := "grass"
var levers := {}
var plates := {}     # id -> list of plate areas
var doors := {}      # id -> list of door bodies
var time := 0.0
var deaths := 0
var done := false

var tiles := TileMapLayer.new()
var cam := Camera2D.new()
var hud := Label.new()
var message := Label.new()

# time trial
var trial_left := 60.0
var next_x := 0
var start_x := 0.0
var distance := 0.0


func _ready() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(18, 18)
	var src := TileSetAtlasSource.new()
	src.texture = TILES
	src.texture_region_size = Vector2i(18, 18)
	for y in 9:
		for x in 20:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src)
	tiles.tile_set = ts
	tiles.scale = Vector2(2, 2)
	add_child(tiles)

	var title := ""
	var data: Dictionary
	match Game.mode:
		Game.Mode.TUTORIAL:
			title = "TUTORIAL"
			data = Levels.build(Levels.TUTORIAL)
		Game.Mode.STORY:
			var info: Dictionary = Levels.LEVELS[Game.story_level]
			title = "%d. %s" % [Game.story_level + 1, info["name"]]
			theme = info["theme"]
			data = Levels.boss_arena() if info.get("boss", false) else Levels.build(info["pieces"])
		_:
			title = "TIME TRIAL"
			data = Levels.empty()
			next_x = Levels.add_piece(data, "start", 0, 0)
	build(data)
	RenderingServer.set_default_clear_color(THEMES[theme]["sky"])

	checkpoint = _pos(data["spawn"])
	start_x = checkpoint.x
	for i in Game.player_schemes.size():
		var p: CharacterBody2D = PlayerScript.new()
		p.schemes = Game.player_schemes[i]
		add_child(p)
		p.sprite.modulate = Game.TINTS[i]
		p.tag.text = "P%d" % (i + 1) if Game.player_schemes.size() > 1 else ""
		p.died.connect(func() -> void: deaths += 1)
		players.append(p)
	_set_spawns()
	for p in players:
		p.position = p.spawn_point

	cam.limit_bottom = 16 * T
	cam.limit_left = 0
	add_child(cam)
	var ui := CanvasLayer.new()
	add_child(ui)
	hud.position = Vector2(16, 12)
	ui.add_child(hud)
	message.position = Vector2(0, 160)
	message.size = Vector2(1152, 100)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 30)
	ui.add_child(message)
	show_message(title, 2.0)
	if Game.mode == Game.Mode.TIME_TRIAL:
		_countdown()


func _pos(cell: Array) -> Vector2:
	return Vector2(cell[0] * T + T / 2.0, cell[1] * T)


## everything
func build(d: Dictionary) -> void:
	var coop := Game.player_schemes.size() > 1
	for r in d["plats"]:
		_block(r[0], r[1], r[2], r[3])
	for m in d["mushrooms"]:
		var body := _block(m[0], m[1], m[2], 1, true)
		body.set_meta("bouncy", true)
	for s in d["spikes"]:
		for i in s[2]:
			_tile(68, s[0] + i, s[1] - 1)
		var hurt := _area(_pos(s) + Vector2((s[2] - 1) * T / 2.0, -8), Vector2(s[2] * T - 10, 14))
		hurt.body_entered.connect(func(b: Node) -> void: if b in players: b.die())
	for c in d["coins"]:
		var coin := _area(_pos(c) + Vector2(0, T / 2.0), Vector2(22, 26))
		coin.add_child(_sprite(151))
		coin.body_entered.connect(_coin.bind(coin))
	for s in d["stars"]:
		var gem := _area(_pos(s) + Vector2(0, -18), Vector2(28, 28))
		var spr := _sprite(67)
		spr.modulate = Color(1.6, 0.7, 1.4)
		gem.add_child(spr)
		gem.body_entered.connect(_star.bind(gem))
	for c in d["checkpoints"]:
		var flag := _area(_pos(c) + Vector2(0, -T), Vector2(36, 2 * T))
		var pole := _sprite(131)
		pole.position.y = T / 2.0
		flag.add_child(pole)
		var top := _sprite(111)
		top.position.y = -T / 2.0
		top.modulate = Color(0.5, 0.5, 0.5)
		flag.add_child(top)
		flag.body_entered.connect(_checkpoint.bind(_pos(c), top))
	for l in d["levers"]:
		if l[3] and not coop:
			continue
		var lever := _area(_pos(l) + Vector2(0, -T / 2.0), Vector2(30, T))
		lever.collision_mask = 0
		var spr := _sprite(64)
		lever.add_child(spr)
		lever.set_meta("lever", func() -> void:
			levers[l[2]] = true
			spr.texture = _tex(66)
			Game.sfx("lever"))
	for p in d["plates"]:
		if p[3] and not coop:
			continue
		var plate := _area(_pos(p) + Vector2(0, -8), Vector2(30, 16))
		plate.add_child(_sprite(148))
		plates.get_or_add(p[2], []).append(plate)
	for dr in d["doors"]:
		if dr[4] and not coop:
			continue
		var door := _block(dr[0], dr[1], 1, dr[2], false, 28)
		doors.get_or_add(dr[3], []).append(door)
	for s in d["signs"]:
		_tile(86, s[0], s[1] - 1)
		var text := Label.new()
		text.text = s[2]
		text.add_theme_font_size_override("font_size", 10)
		text.position = _pos(s) + Vector2(-20, -110)
		add_child(text)
	if d.has("goal"):
		goal_pos = _pos(d["goal"])
		_tile(150, d["goal"][0], d["goal"][1] - 1)
		_tile(130, d["goal"][0], d["goal"][1] - 2)
	if d.has("boss"):
		boss = BossScript.new()
		boss.position = _pos(d["boss"])
		boss.level = self
		add_child(boss)


## A solid block drawn with tiles. Mushrooms use the red cap tiles.
func _block(x: int, y: int, w: int, h: int, mushroom: bool = false, tile: int = -1) -> StaticBody2D:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.shape.size = Vector2(w, h) * T
	cs.position = Vector2(x + w / 2.0, y + h / 2.0) * T
	body.add_child(cs)
	add_child(body)
	for i in w:
		for j in h:
			var t: int = THEMES[theme]["top"] if h > 1 else THEMES[theme]["thin"]
			if j > 0:
				t = 6 if theme == "castle" else 122
			if mushroom:
				t = 12 if i == w / 2 else (14 if i == 0 else (15 if i == w - 1 else 13))
			if tile >= 0:
				t = tile
				var spr := _sprite(t)
				spr.position = Vector2(x + i + 0.5, y + j + 0.5) * T
				body.add_child(spr)
				continue
			_tile(t, x + i, y + j)
	if mushroom:  # stem down to the ground
		for j in range(y + 1, 16):
			if tiles.get_cell_source_id(Vector2i(x + w / 2, j)) != -1:
				break
			_tile(52, x + w / 2, j)
	return body


func _tile(idx: int, x: int, y: int) -> void:
	tiles.set_cell(Vector2i(x, y), 0, Vector2i(idx % 20, idx / 20))


func _tex(idx: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = TILES
	a.region = Rect2(idx % 20 * 18, idx / 20 * 18, 18, 18)
	return a


func _sprite(idx: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(idx)
	s.scale = Vector2(2, 2)
	return s


func _area(pos: Vector2, size: Vector2) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 2
	a.collision_mask = 4
	a.position = pos
	var cs := CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.shape.size = size
	a.add_child(cs)
	add_child(a)
	return a


func _coin(body: Node, coin: Area2D) -> void:
	if body in players:
		body.coins += 1
		Game.sfx("coin")
		coin.queue_free()


func _star(body: Node, gem: Area2D) -> void:
	if body in players and gem.visible:
		body.star = PlayerScript.STAR_TIME
		Game.sfx("powerup")
		show_message("BOUNCE GEM!", 1.5)
		gem.visible = false
		await get_tree().create_timer(10.0).timeout
		if is_instance_valid(gem):
			gem.visible = true


func _checkpoint(body: Node, pos: Vector2, flag: Sprite2D) -> void:
	if body in players and checkpoint != pos:
		checkpoint = pos
		flag.modulate = Color.WHITE
		_set_spawns()
		Game.sfx("checkpoint")


func _set_spawns() -> void:
	for i in players.size():
		players[i].spawn_point = checkpoint + Vector2(i * 28, 0)


func show_message(text: String, seconds: float) -> void:
	message.text = text
	await get_tree().create_timer(seconds).timeout
	if message.text == text:
		message.text = ""


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("back"):
		Game.goto_menu()
	if done:
		return
	time += delta
	var total_coins := 0
	var all_home := true
	for p in players:
		total_coins += p.coins
		if p.position.y > 20 * T:
			p.die()
		if p.position.distance_to(goal_pos) > 40:
			all_home = false
	# doors open while every plate is held, or for good once the lever is pulled
	for id in doors:
		var open: bool = levers.get(id, false)
		if plates.has(id):
			open = open or plates[id].all(func(a: Area2D) -> bool: return not a.get_overlapping_bodies().is_empty())
		for door in doors[id]:
			door.visible = not open
			door.get_child(0).set_deferred("disabled", open)
	if all_home and goal_pos.x > 0:
		finish("LEVEL CLEAR!")
	if Game.mode == Game.Mode.TIME_TRIAL:
		_trial(delta)
		hud.text = "TIME %d   DISTANCE %d M   COINS %d" % [ceili(trial_left), int(distance), total_coins]
	else:
		hud.text = "TIME %.1f   COINS %d   DEATHS %d" % [time, total_coins, deaths]


func _process(_delta: float) -> void:
	var center := Vector2.ZERO
	for p in players:
		center += p.position
	cam.position = cam.position.lerp(center / players.size() + Vector2(0, -80), 0.1)


func finish(text: String) -> void:
	done = true
	for p in players:
		p.frozen = true
	Game.sfx("goal")
	show_message(text, 3.0)
	await get_tree().create_timer(3.0).timeout
	Game.level_done()


#time trial

func _countdown() -> void:
	for p in players:
		p.frozen = true
	for n in ["3", "2", "1"]:
		show_message(n, 0.6)
		Game.sfx("tick")
		await get_tree().create_timer(0.6).timeout
	show_message("GO!", 0.8)
	Game.sfx("go")
	for p in players:
		p.frozen = false


func _trial(delta: float) -> void:
	if players[0].frozen:
		return
	trial_left -= delta
	distance = maxf(distance, (players[0].position.x - start_x) / T)
	while next_x * T < players[0].position.x + 40 * T:
		var d := Levels.empty()
		next_x = Levels.add_piece(d, Levels.TRIAL_PIECES.pick_random(), next_x, next_x)
		build(d)
	if trial_left <= 0.0:
		trial_left = 0.0
		var best := Game.best_distance()
		var record := Game.save_distance(int(distance))
		finish("TIME'S UP!  %d M\n%s" % [int(distance), "NEW RECORD!" if record else "BEST %d M" % best])

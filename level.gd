extends Node2D
## da levels

const Levels := preload("res://levels.gd")
const PlayerScript := preload("res://player.gd")
const BossScript := preload("res://boss.gd")
const TILES := preload("res://kenney_pixel-platformer/Tilemap/tilemap_packed.png")

const T := 36
## Each tile row is [single, left, middle, right]; "thin" is a 1-tall ledge, "top" is the
## grassy top of a taller block. The dirt below uses the shared FILL / BOTTOM rows.
const THEMES := {
	"grass": {"thin": 0, "top": 20, "sky": Color(0.5, 0.85, 0.95), "clouds": Color(1, 1, 1)},
	"sand": {"thin": 40, "top": 60, "sky": Color(0.98, 0.8, 0.55), "clouds": Color(1, 0.97, 0.9)},
	"snow": {"thin": 80, "top": 100, "sky": Color(0.8, 0.9, 0.95), "clouds": Color(1, 1, 1)},
	"castle": {"sky": Color(0.25, 0.2, 0.35), "clouds": Color(0.55, 0.5, 0.65, 0.7)},
}
const FILL := 120
const BOTTOM := 140
const WORLD_ROWS := 16   # ground blocks run off the bottom of the world, so no bottom edge there

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
var wiping := false   # true while a death is taking the rest of the team down
var done := false

# juice
var floaters: Array = []   # [sprite, base_y, spins] for coins and gems
var shake_amt := 0.0
var look := 0.0            # camera leans ahead of where the players are running

var tiles := TileMapLayer.new()
var solid := {}      # Vector2i cells of ground blocks, so edges and corners can join up
var clouds: Array = []   # [sprite, x, y, depth, drift speed]
var cloud_layer := CanvasLayer.new()
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
	_make_clouds()
	Game.music("boss" if boss else "level")

	checkpoint = _pos(data["spawn"])
	start_x = checkpoint.x
	for i in Game.player_schemes.size():
		var p: CharacterBody2D = PlayerScript.new()
		p.schemes = Game.player_schemes[i]
		add_child(p)
		p.sprite.modulate = Game.TINTS[i]
		p.tag.text = "P%d" % (i + 1) if Game.player_schemes.size() > 1 else ""
		p.died.connect(_on_died.bind(p))
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
		var spr := _sprite(151)
		coin.add_child(spr)
		floaters.append([spr, 0.0, true])
		coin.body_entered.connect(_coin.bind(coin))
	for s in d["stars"]:
		var gem := _area(_pos(s) + Vector2(0, -18), Vector2(28, 28))
		var spr := _sprite(67)
		spr.modulate = Color(1.6, 0.7, 1.4)
		gem.add_child(spr)
		floaters.append([spr, 0.0, false])
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
			if levers.get(l[2], false):
				return
			levers[l[2]] = true
			spr.texture = _tex(66)
			_pop(spr)
			shake(2.0)
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
		door.set_meta("open", false)
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
	if not mushroom and tile < 0:
		for i in w:
			for j in h:
				solid[Vector2i(x + i, y + j)] = true
		# retile the block and its neighbours so touching blocks merge into one shape
		for i in range(-1, w + 1):
			for j in range(-1, h + 1):
				_autotile(Vector2i(x + i, y + j))
	for i in w:
		for j in h:
			if mushroom:
				_tile(12 if i == w / 2 else (14 if i == 0 else (15 if i == w - 1 else 13)), x + i, y + j)
			elif tile >= 0:
				var spr := _sprite(tile)
				spr.position = Vector2(x + i + 0.5, y + j + 0.5) * T
				body.add_child(spr)
	if mushroom:  # stem down to the ground
		for j in range(y + 1, 16):
			if tiles.get_cell_source_id(Vector2i(x + w / 2, j)) != -1:
				break
			_tile(52, x + w / 2, j)
	return body


func _tile(idx: int, x: int, y: int) -> void:
	tiles.set_cell(Vector2i(x, y), 0, Vector2i(idx % 20, idx / 20))


## Picks the edge / corner tile for a ground cell from which neighbours are solid.
func _autotile(c: Vector2i) -> void:
	if not solid.has(c):
		return
	var up := solid.has(c + Vector2i.UP)
	var down := solid.has(c + Vector2i.DOWN) or c.y >= WORLD_ROWS - 1
	if theme == "castle":
		_tile(6 if up else 29, c.x, c.y)
		return
	var left := solid.has(c + Vector2i.LEFT)
	var right := solid.has(c + Vector2i.RIGHT)
	var col := 2                      # middle
	if not left and not right:
		col = 0                       # single column, edges on both sides
	elif not left:
		col = 1                       # left edge / corner
	elif not right:
		col = 3                       # right edge / corner
	var row: int
	if not up:
		row = THEMES[theme]["top"] if down else THEMES[theme]["thin"]
	else:
		row = FILL if down else BOTTOM
	_tile(row + col, c.x, c.y)


## Puffy pixel clouds behind everything, drifting slowly with a bit of parallax.
func _make_clouds() -> void:
	cloud_layer.layer = -1
	add_child(cloud_layer)
	var tint: Color = THEMES[theme]["clouds"]
	for i in 9:
		var spr := Sprite2D.new()
		spr.texture = _cloud_texture()
		var depth := randf_range(0.15, 0.45)        # far clouds are smaller and move less
		spr.scale = Vector2.ONE * roundf(lerpf(2.0, 4.0, depth / 0.45))
		spr.modulate = Color(tint, tint.a * lerpf(0.6, 1.0, depth / 0.45))
		cloud_layer.add_child(spr)
		clouds.append([spr, i * 160.0 + randf_range(0, 100), randf_range(30, 300), depth, randf_range(6, 16)])


func _cloud_texture() -> ImageTexture:
	var n := randi_range(3, 5)
	var w := n * 9 + 14
	var h := 22
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var puffs := []
	for k in n:
		var r := randf_range(5, 7) if k in [0, n - 1] else randf_range(7, 9.5)
		puffs.append([lerpf(7, w - 8, k / float(n - 1)), h - 3 - r * 0.8, r])
	var shade := Color(0.82, 0.88, 0.97)
	var edge := Color(0.62, 0.72, 0.88)
	for y in h:
		for x in w:
			var inside := false
			for p in puffs:
				if Vector2(x - p[0], (y - p[1]) * 1.15).length() <= p[2]:
					inside = true
			if y >= h - 8 and x >= 4 and x < w - 4:   # flat base so the puffs always join up
				inside = true
			if inside and y < h - 2:
				img.set_pixel(x, y, Color.WHITE if y < h - 7 else shade)
	# dark outline around the shape, matching the tile art
	var out := img.duplicate()
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0:
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and img.get_pixelv(q).a > 0:
					out.set_pixel(x, y, edge)
					break
	return ImageTexture.create_from_image(out)


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
	if body in players and not coin.is_queued_for_deletion():
		body.coins += 1
		Game.sfx("coin")
		# a copy of the coin jumps up and fades, with a little sparkle
		var ghost := _sprite(151)
		ghost.position = coin.position
		add_child(ghost)
		var tw := ghost.create_tween().set_parallel()
		tw.tween_property(ghost, "position:y", coin.position.y - 40.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(ghost, "scale", Vector2(2.8, 2.8), 0.35)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.35).set_delay(0.1)
		tw.chain().tween_callback(ghost.queue_free)
		Game.burst(self, coin.position, 8, Color(1.0, 0.9, 0.3), 110.0, Vector2.UP, 180.0, 150.0, 3.0, 0.4)
		coin.queue_free()


func _star(body: Node, gem: Area2D) -> void:
	if body in players and gem.visible:
		body.star = PlayerScript.STAR_TIME
		Game.sfx("powerup")
		show_message("BOUNCE GEM!", 1.5)
		Game.burst(self, gem.position, 24, Color(1.0, 0.55, 1.0), 200.0, Vector2.UP, 180.0, 100.0, 5.0, 0.6)
		shake(3.0)
		gem.visible = false
		await get_tree().create_timer(10.0).timeout
		if is_instance_valid(gem):
			gem.visible = true


func _checkpoint(body: Node, pos: Vector2, flag: Sprite2D) -> void:
	if body in players and checkpoint != pos:
		checkpoint = pos
		flag.modulate = Color.WHITE
		_pop(flag)
		Game.burst(self, flag.global_position, 14, Color(1.0, 0.95, 0.5), 140.0, Vector2.UP, 120.0, 250.0, 4.0, 0.5)
		_set_spawns()
		Game.sfx("checkpoint")


## In co-op, one bear dying takes the whole team down (counts as one death).
func _on_died(who: Node) -> void:
	if wiping:
		return
	deaths += 1
	wiping = true
	for p in players:
		if p != who:
			p.die(true)
	wiping = false


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
			if door.get_meta("open") == open:
				continue
			door.set_meta("open", open)
			door.get_child(0).set_deferred("disabled", open)
			var tw: Tween = door.create_tween()
			tw.tween_property(door, "modulate:a", 0.15 if open else 1.0, 0.2)
			if open:
				Game.burst(self, door.get_child(0).global_position, 10, Color(0.8, 0.7, 0.6), 80.0, Vector2.UP, 180.0, 200.0, 4.0, 0.4)
	if all_home and goal_pos.x > 0:
		finish("LEVEL CLEAR!")
	if Game.mode == Game.Mode.TIME_TRIAL:
		_trial(delta)
		hud.text = "TIME %d   DISTANCE %d M   COINS %d" % [ceili(trial_left), int(distance), total_coins]
	else:
		hud.text = "TIME %.1f   COINS %d   DEATHS %d" % [time, total_coins, deaths]


func _process(delta: float) -> void:
	var center := Vector2.ZERO
	var vx := 0.0
	for p in players:
		center += p.position
		vx += p.velocity.x
	vx /= players.size()
	look = lerpf(look, clampf(vx * 0.3, -90.0, 90.0), 1.0 - exp(-3.0 * delta))
	var target := center / players.size() + Vector2(look, -80)
	cam.position = cam.position.lerp(target, 1.0 - exp(-6.0 * delta))
	shake_amt = move_toward(shake_amt, 0.0, 30.0 * delta)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt

	# clouds: screen space, scroll at a fraction of the camera and wrap around
	var view := get_viewport().get_visible_rect().size
	var span := view.x + 300.0
	for c in clouds:
		c[1] += c[4] * delta
		var spr: Sprite2D = c[0]
		spr.position = Vector2(fposmod(c[1] - cam.position.x * c[3], span) - 150.0, c[2] - cam.position.y * c[3] * 0.3 + 60.0)

	# coins spin and bob, gems bob and glow
	var now := Time.get_ticks_msec() / 1000.0
	var i := floaters.size() - 1
	while i >= 0:
		var f: Array = floaters[i]
		if not is_instance_valid(f[0]):   # check before typing it: collected coins are freed
			floaters.remove_at(i)
		else:
			var s: Sprite2D = f[0]
			var phase := now * 3.0 + s.global_position.x * 0.03
			s.position.y = f[1] + sin(phase) * 3.0
			if f[2]:
				s.scale.x = 2.0 * maxf(absf(cos(phase * 0.8)), 0.15)
			else:
				s.self_modulate = Color.WHITE * (1.0 + 0.25 * sin(phase * 2.0))
		i -= 1


## Shake the camera. Bigger hits win over smaller ones.
func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


## Quick bounce-scale on a sprite (flags, levers).
func _pop(s: Node2D) -> void:
	var base := s.scale
	s.scale = base * Vector2(1.4, 0.6)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", base, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func finish(text: String) -> void:
	done = true
	for p in players:
		p.frozen = true
		for c in [Color(1, 0.4, 0.4), Color(1, 0.9, 0.3), Color(0.4, 0.8, 1), Color(0.5, 1, 0.5)]:
			Game.burst(self, p.position + Vector2(0, -30), 10, c, 320.0, Vector2.UP, 60.0, 500.0, 5.0, 1.2)
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

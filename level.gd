extends Node2D
## Builds and runs a level: story levels, boss fights, bootcamp (tutorial) and rush mode
## (time trial). Levels are text chunks from levels.gd; see the legend at the top of that file.

const Levels := preload("res://levels.gd")
const PlayerScript := preload("res://player.gd")
const EnemyScript := preload("res://enemy.gd")
const BossScript := preload("res://boss.gd")
const HudScript := preload("res://hud.gd")
const DialogScript := preload("res://dialog.gd")
const Cast := preload("res://cast.gd")
const TILES := preload("res://kenney_pixel-platformer/Tilemap/tilemap_packed.png")
const BackdropScript := preload("res://backdrop.gd")
const Ui := preload("res://ui.gd")
const Powers := preload("res://powers.gd")
const PixelArt := preload("res://pixel_art.gd")

const T := 36
const GROUND := 12      # row of the ground's top
const DEEP := 17        # ground runs down to this row, off the bottom of the screen
const FILL := 120
const BOTTOM := 140
const ENEMY_CHARS := {"a": "bot", "f": "bat", "d": "drill", "R": "bigbot", "p": "shooter", "q": "ghost",
	"T": "thwomp", "k": "spark", "s": "saw_h", "z": "saw_v", "F": "jet", "E": "arc", "i": "icicle"}
const DUST := Color(0.96, 0.93, 0.86, 0.9)
const FADE_PERIOD := 4.0     # fading platforms: seconds for one on / blink / off cycle
const FADE_ON := 0.6         # part of the cycle that is solid and steady
const FADE_BLINK := 0.75     # ...then blinks until here, then is gone until the cycle ends
const MAGNET_RANGE := 190.0

var players: Array = []
var enemies: Array = []
var boss: Node2D = null
var theme := "grass"
var slippery := false
var title := ""
var uses_gems := false
var done := false
var done_building := false
var cinematic := false      # a cutscene is playing inside the level
var paused := false
var time := 0.0
var deaths := 0
var kills := 0
var checkpoint := Vector2.ZERO
var goal_pos := Vector2(-99999, 0)
var width := 0
var spawn_cell := Vector2i(2, 11)
var boss_cell := Vector2i(24, 11)

# what is in each tile
var solid := {}         # Vector2i -> theme name
var fresh: Array = []   # solid cells still waiting for colliders and tiles
var ledges := {}
var pickups := {}       # Vector2i -> {"type", "node", ...}
var spikes := {}        # Vector2i -> 1 (floor) or -1 (ceiling)
var springs := {}
var liquid := {}        # column -> true
var crates := {}
var crumbles := {}      # Vector2i -> body (meta "gone" while fallen)
var levers := {}
var doors := {}         # id -> Array of bodies
var door_cells := {}    # Vector2i -> body
var flags := {}         # Vector2i -> {"pos", "flag", "on"}
var used := {}
var chunk_theme := "grass"
var last_cp := 0
var gem_spots := 0      # 'g' characters seen so far
var gem_keep: Array = []
var gems_got := 0
var coach_marks: Array = []
var coach_next := 0

var movers: Array = []
var faders: Array = []     # fading platforms {"body", "shape", "art", "phase", "on"}
var fallers: Array = []    # falling platforms {"body", "shape", "art", "origin", "state", "t", "vy"}
var shots: Array = []
var zones: Array = []
var floaters: Array = []   # [sprite, base_y] coins bobbing
var flag_sprites: Array = []
var flag_frames: Array = []
var coin_chain := 0
var coin_chain_t := 0.0
var cull_t := 0.0
var shake_amt := 0.0
var look := 0.0
var storm_t := 6.0

var ground_layers := {}    # theme -> TileMapLayer (each tinted for its theme)
var tileset: TileSet
var objects: TileMapLayer
var liquid_layer: TileMapLayer
var cam := Camera2D.new()
var hud: CanvasLayer
var dialog: CanvasLayer

var backdrop: Node
var look_theme := ""

# rush mode
var trial_left := 60.0
var trial_running := false
var next_x := 0
var start_x := 0.0
var distance := 0.0
var tier := 0
var last_chunk := ""
var zone_marks: Array = []   # [x in pixels, tier]
var last_tick := 11


func _ready() -> void:
	Game.pause_handler = toggle_pause
	tileset = TileSet.new()
	tileset.tile_size = Vector2i(18, 18)
	var src := TileSetAtlasSource.new()
	src.texture = TILES
	src.texture_region_size = Vector2i(18, 18)
	for y in 9:
		for x in 20:
			src.create_tile(Vector2i(x, y))
	tileset.add_source(src)
	liquid_layer = _layer(-1)
	objects = _layer(1)
	# pits read as pits: everything below ground level is in shadow
	var depth := Polygon2D.new()
	depth.polygon = PackedVector2Array([Vector2(-4000, GROUND * T), Vector2(400000, GROUND * T), Vector2(400000, (DEEP + 4) * T), Vector2(-4000, (DEEP + 4) * T)])
	depth.vertex_colors = PackedColorArray([Color(0.05, 0.03, 0.12, 0.25), Color(0.05, 0.03, 0.12, 0.25), Color(0.05, 0.03, 0.12, 0.9), Color(0.05, 0.03, 0.12, 0.9)])
	depth.z_index = -3
	add_child(depth)

	var chunks: Array = []
	var big := ""
	var sub := ""
	var color := Color(1, 0.96, 0.84)
	var song := "level"
	var pitch := 1.0
	match Game.mode:
		Game.Mode.TUTORIAL:
			title = "BOOTCAMP"
			sub = "MISS BEAR'S"
			for step in Levels.TUTORIAL:
				chunks.append(step[0])
		Game.Mode.STORY:
			var info: Dictionary = Levels.LEVELS[Game.level]
			var world: Dictionary = Levels.WORLDS[Levels.world_of(Game.level)]
			title = info["name"]
			big = Levels.label(Game.level)
			sub = world["name"]
			color = world["color"]
			theme = world["theme"]
			song = world["music"]
			pitch = world["pitch"]
			chunks = info["chunks"]
			uses_gems = not info.has("boss")
		_:
			title = "RUSH MODE"
			sub = "HOW FAR CAN YOU GET?"
			chunks = ["start"]
	chunk_theme = theme
	slippery = Levels.THEMES[theme].get("slippery", false)
	backdrop = BackdropScript.new()
	add_child(backdrop)
	_apply_look(theme)

	# pick which 3 gem spots are real gems
	if uses_gems:
		var total := 0
		for c in chunks:
			for row: String in Levels.CHUNKS[c]:
				total += row.count("g")
		for k in 3:
			gem_keep.append(int((k + 0.5) * total / 3.0))

	var x := 0
	for i in chunks.size():
		if Game.mode == Game.Mode.TUTORIAL:
			coach_marks.append([x * T, Levels.TUTORIAL[i][1]])
		x += place_chunk(chunks[i], x, i + 1)
	width = x
	next_x = x
	_commit_solids()

	if Game.debug_col > 0:
		spawn_cell = Vector2i(Game.debug_col, 4)
	checkpoint = _feet(spawn_cell)
	start_x = checkpoint.x
	for i in Game.player_schemes.size():
		var p: CharacterBody2D = PlayerScript.new()
		p.schemes = Game.player_schemes[i]
		p.level = self
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
	if Game.mode != Game.Mode.TIME_TRIAL:
		cam.limit_right = maxi(width * T, 1152)
	add_child(cam)
	cam.position = checkpoint + Vector2(0, -80)
	cam.make_current()

	hud = HudScript.new()
	add_child(hud)
	hud.setup(self)
	dialog = DialogScript.new()
	add_child(dialog)
	_ambient()
	done_building = true

	if Game.mode == Game.Mode.STORY and Levels.LEVELS[Game.level].has("boss"):
		boss = BossScript.new()
		boss.kind = Levels.LEVELS[Game.level]["boss"]
		boss.level = self
		boss.position = _feet(boss_cell)
		add_child(boss)
		Game.music("menu", 0.7)
		hud.name_label.text = "%s  %s" % [big, title]
		_boss_intro()
	elif Game.mode == Game.Mode.TIME_TRIAL:
		Game.music(song, 1.12)
		hud.name_label.text = "BEST %d M" % Game.best_distance()
		_countdown()
	else:
		Game.music(song, pitch)
		hud.title_card(big, title, sub, color)
		Game.touch.set_active(true)
		for p in players:
			Fx.play(self, "respawn", p.position, {"z": 8, "speed": 1.8})


func _exit_tree() -> void:
	Game.pause_handler = Callable()
	Game.touch.set_active(false)
	Engine.time_scale = 1.0


func _layer(z: int) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = tileset
	l.scale = Vector2(2, 2)
	l.z_index = z
	l.collision_enabled = false
	add_child(l)
	return l


func _ground(th: String) -> TileMapLayer:
	if not ground_layers.has(th):
		var l := _layer(0)
		l.modulate = Levels.THEMES[th]["tint"]
		ground_layers[th] = l
	return ground_layers[th]


## Bottom-centre of a tile: where something standing in that tile has its feet.
func _feet(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * T, (cell.y + 1) * T)


func _mid(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * T, (cell.y + 0.5) * T)


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / T), floori(pos.y / T))


func solid_at(pos: Vector2) -> bool:
	var c := cell_of(pos)
	return solid.has(c) or crates.has(c) or door_cells.has(c)


func floor_at(pos: Vector2) -> bool:
	var c := cell_of(pos)
	if solid.has(c) or ledges.has(c) or crates.has(c):
		return true
	return crumbles.has(c) and not crumbles[c].get_meta("gone", false)


func tile(idx: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = TILES
	a.region = Rect2(idx % 20 * 18, idx / 20 * 18, 18, 18)
	return a


func _sprite(idx: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tile(idx)
	s.scale = Vector2(2, 2)
	return s


func _set_tile(layer: TileMapLayer, idx: int, x: int, y: int, alt: int = 0) -> void:
	layer.set_cell(Vector2i(x, y), 0, Vector2i(idx % 20, idx / 20), alt)


# ---------------------------------------------------------------- building

## Places one chunk with its left edge at column x0. Returns its width in tiles.
func place_chunk(chunk: String, x0: int, id: int) -> int:
	var rows: Array = Levels.CHUNKS[chunk]
	var n := rows.size()
	var w := Levels.chunk_width(chunk)
	var last: String = rows[n - 1]
	# a checkpoint every so often, where a chunk starts on open ground
	if not chunk.begins_with("arena") and chunk not in ["start", "goal"] and x0 - last_cp >= 40 \
			and last.begins_with("##") and (n < 2 or rows[n - 2].substr(0, 3).strip_edges() == ""):
		_add_flag(Vector2i(x0 + 1, GROUND - 1))
		last_cp = x0
	for r in n:
		var y := GROUND - (n - 1) + r
		var row: String = rows[r]
		var c := 0
		while c < row.length():
			var ch := row[c]
			var cell := Vector2i(x0 + c, y)
			match ch:
				" ":
					pass
				"#":
					if r == n - 1:
						for yy in range(GROUND, DEEP + 1):
							_add_solid(Vector2i(x0 + c, yy))
					else:
						_add_solid(cell)
				"~":
					_add_liquid(x0 + c)
				"=", "M", ":", ";", "_":
					var k := 1
					while c + k < row.length() and row[c + k] == ch:
						k += 1
					match ch:
						"=":
							_add_ledge(cell, k)
						"M":
							_add_mushroom(cell, k)
						":", ";":
							_add_fader(cell, k, 0.0 if ch == ":" else 0.5)
						"_":
							_add_faller(cell, k)
							if r == n - 1 and row.substr(maxi(c - 1, 0), k + 2).contains("~"):
								for i in k:
									_add_liquid(x0 + c + i)
					c += k - 1
				">", "<", "|":
					_add_mover(cell, ch)
					if r == n - 1 and (row.substr(maxi(c - 1, 0), 3).contains("~")):
						_add_liquid(x0 + c)
				"o":
					_add_pickup(cell, "coin")
				"g":
					if Game.mode == Game.Mode.TIME_TRIAL:
						_add_pickup(cell, "clock")
					elif uses_gems and gem_spots in gem_keep:
						_add_pickup(cell, "gem", gem_keep.find(gem_spots))
					else:
						_add_pickup(cell, "coin")
					gem_spots += 1
				"h":
					_add_pickup(cell, "heart")
				"*":
					_add_pickup(cell, "star")
				"J":
					var spr := _sprite(107)
					spr.position = _mid(cell)
					add_child(spr)
					springs[cell] = spr
					used[cell] = true
				"B":
					_add_crate(cell)
				"x":
					_add_crumble(cell)
				"^":
					_set_tile(objects, 68, cell.x, cell.y)
					spikes[cell] = 1
					used[cell] = true
				"v":
					_set_tile(objects, 68, cell.x, cell.y, TileSetAtlasSource.TRANSFORM_FLIP_V)
					spikes[cell] = -1
					used[cell] = true
				"L":
					var spr := _sprite(64)
					spr.position = _mid(cell)
					add_child(spr)
					levers[cell] = {"id": id, "spr": spr, "on": false}
					used[cell] = true
				"D":
					if r == 0 or c >= rows[r - 1].length() or rows[r - 1][c] != "D":
						var k := 1
						while r + k < n and c < rows[r + k].length() and rows[r + k][c] == "D":
							k += 1
						_add_door(cell, k, id)
				"S":
					spawn_cell = cell
					used[cell] = true
				"G":
					goal_pos = _feet(cell)
					used[cell] = true
					Fx.play(self, "rune", goal_pos + Vector2(0, 4), {"scale": 1.6, "z": 1})
					Fx.play(self, "portal", goal_pos, {"scale": 1.5, "z": 1})
				"X":
					boss_cell = cell
				_:
					if ENEMY_CHARS.has(ch):
						_add_enemy(ENEMY_CHARS[ch], cell)
						used[cell] = true
					elif Powers.by_char(ch) != "":
						_add_pickup(cell, "power", 0, Powers.by_char(ch))
			c += 1
	return w


func _add_solid(cell: Vector2i) -> void:
	if not solid.has(cell):
		solid[cell] = chunk_theme
		fresh.append(cell)


## Turns the solid cells added since last time into colliders (merged into big rectangles,
## so there are no seams to snag on), tiles them and sprinkles decorations on top.
func _commit_solids() -> void:
	if fresh.is_empty():
		return
	var by_row := {}
	for c: Vector2i in fresh:
		by_row.get_or_add(c.y, []).append(c.x)
	var ys: Array = by_row.keys()
	ys.sort()
	var open := {}   # Vector2i(x0, x1) -> [y0, y1]
	var rects: Array = []
	for y: int in ys:
		var xs: Array = by_row[y]
		xs.sort()
		var i := 0
		while i < xs.size():
			var j := i
			while j + 1 < xs.size() and xs[j + 1] == xs[j] + 1:
				j += 1
			var key := Vector2i(xs[i], xs[j])
			if open.has(key) and open[key][1] == y - 1:
				open[key][1] = y
			else:
				if open.has(key):
					rects.append([key, open[key]])
				open[key] = [y, y]
			i = j + 1
	for key: Vector2i in open:
		rects.append([key, open[key]])
	for r in rects:
		var key: Vector2i = r[0]
		var span: Array = r[1]
		var body := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(key.y - key.x + 1, span[1] - span[0] + 1) * T
		cs.shape = shape
		cs.position = Vector2(key.x + key.y + 1, span[0] + span[1] + 1) * T / 2.0
		body.add_child(cs)
		add_child(body)
	# tiles: each new cell and its neighbours, so touching blocks join up
	var todo := {}
	for c: Vector2i in fresh:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				todo[c + Vector2i(dx, dy)] = true
	for c: Vector2i in todo:
		_autotile(c)
	if boss == null and not (Game.mode == Game.Mode.STORY and Levels.LEVELS[Game.level].has("boss")):
		for c: Vector2i in fresh:
			_decorate(c)
	fresh.clear()


## Picks the edge / corner tile for a ground cell from which neighbours are solid.
func _autotile(c: Vector2i) -> void:
	if not solid.has(c):
		return
	var th: Dictionary = Levels.THEMES[solid[c]]
	var up := solid.has(c + Vector2i.UP)
	var down := solid.has(c + Vector2i.DOWN) or c.y >= DEEP
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
		row = th["top"] if down else th["thin"]
	else:
		row = FILL if down else BOTTOM
	_set_tile(_ground(solid[c]), row + col, c.x, c.y)


## Bushes, cacti, snowmen... on some open ground tops. Same every time for the same tile.
func _decorate(c: Vector2i) -> void:
	var above := c + Vector2i.UP
	if solid.has(above) or used.has(above) or c.y > GROUND:
		return
	var decor: Array = Levels.THEMES[solid[c]]["decor"]
	var roll := absi(hash(c * 7 + Vector2i(13, 5))) % 100
	if solid[c] == "castle":
		if c.x % 11 == 5 and c.y == GROUND and not solid.has(above + Vector2i.UP):
			Fx.play(self, "torch", _feet(above) + Vector2(0, -30), {"z": -1})
		return
	if decor.is_empty() or roll >= 18:
		return
	var spr := _sprite(decor[roll % decor.size()])
	spr.position = _mid(above)
	spr.z_index = -1
	add_child(spr)


func _add_liquid(x: int) -> void:
	liquid[x] = true
	_set_tile(liquid_layer, 33, x, GROUND)
	for yy in range(GROUND + 1, DEEP + 1):
		_set_tile(liquid_layer, 53, x, yy)


func _static(cell: Vector2i, size: Vector2, one_way: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	cs.one_way_collision = one_way
	body.add_child(cs)
	body.position = Vector2(cell.x * T + size.x / 2.0, cell.y * T + size.y / 2.0)
	add_child(body)
	return body


func _ledge_tiles(k: int) -> Array:
	var t3: Array = Levels.THEMES[chunk_theme]["ledge"]
	var out: Array = []
	for i in k:
		out.append(t3[1] if (i > 0 and i < k - 1) else (t3[0] if i == 0 else t3[2]))
	return out


func _add_ledge(cell: Vector2i, k: int) -> void:
	_static(cell, Vector2(k * T, 12), true)
	var tiles := _ledge_tiles(k)
	for i in k:
		_set_tile(objects, tiles[i], cell.x + i, cell.y)
		ledges[cell + Vector2i(i, 0)] = true
		used[cell + Vector2i(i, 0)] = true


func _add_mushroom(cell: Vector2i, k: int) -> void:
	var body := _static(cell, Vector2(k * T, T))
	body.set_meta("bouncy", true)
	for i in k:
		var idx := 12 if i == k / 2 else (14 if i == 0 else (15 if i == k - 1 else 13))
		_set_tile(objects, idx, cell.x + i, cell.y)
		used[cell + Vector2i(i, 0)] = true
	var sx := cell.x + k / 2
	for yy in range(cell.y + 1, DEEP + 1):   # stem down to the ground
		if solid.has(Vector2i(sx, yy)) or objects.get_cell_source_id(Vector2i(sx, yy)) != -1:
			break
		_set_tile(objects, 52, sx, yy)


func _add_mover(cell: Vector2i, ch: String) -> void:
	var body := AnimatableBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(3 * T, 12)
	cs.shape = shape
	cs.one_way_collision = true
	cs.position = Vector2(1.5 * T, 6)
	body.add_child(cs)
	var tiles := _ledge_tiles(3)
	for i in 3:
		var spr := _sprite(tiles[i])
		spr.position = Vector2((i + 0.5) * T, T / 2.0)
		body.add_child(spr)
	body.position = Vector2(cell.x * T, cell.y * T)
	add_child(body)
	var axis := Vector2(4 * T, 0)
	if ch == "<":
		axis = Vector2(-4 * T, 0)
	elif ch == "|":
		axis = Vector2(0, -5 * T)
	movers.append({"body": body, "origin": body.position, "axis": axis, "period": 5.0 if ch == "|" else 4.4})
	used[cell] = true


## A row of ledge tiles as children of a platform body, in a holder so they can fade or shake.
func _platform_art(body: Node2D, k: int, at: Vector2, tint: Color) -> Node2D:
	var art := Node2D.new()
	art.position = at
	var tiles := _ledge_tiles(k)
	for i in k:
		var spr := _sprite(tiles[i])
		spr.position = Vector2((i + 0.5) * T, T / 2.0)
		spr.modulate = tint
		art.add_child(spr)
	body.add_child(art)
	return art


## Fading platform: solid, blinks, vanishes, comes back. ':' and ';' are out of step, so one
## of them is always there.
func _add_fader(cell: Vector2i, k: int, phase: float) -> void:
	var body := _static(cell, Vector2(k * T, 12), true)
	var art := _platform_art(body, k, Vector2(-k * T / 2.0, -6.0), Color(0.75, 1.1, 1.5))
	faders.append({"body": body, "shape": body.get_child(0), "art": art, "phase": phase, "on": true})
	for i in k:
		used[cell + Vector2i(i, 0)] = true


## Falling platform: shakes when you land on it, then drops away. Comes back a bit later.
func _add_faller(cell: Vector2i, k: int) -> void:
	var body := AnimatableBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(k * T, 12)
	cs.shape = shape
	cs.one_way_collision = true
	cs.position = Vector2(k * T / 2.0, 6)
	body.add_child(cs)
	body.position = Vector2(cell.x * T, cell.y * T)
	add_child(body)
	var art := _platform_art(body, k, Vector2.ZERO, Color(1.3, 0.85, 0.6))
	var f := {"body": body, "shape": cs, "art": art, "origin": body.position, "state": 0, "t": 0.0, "vy": 0.0}
	body.set_meta("crumble", _faller_step.bind(f))
	fallers.append(f)
	for i in k:
		used[cell + Vector2i(i, 0)] = true


func _faller_step(f: Dictionary) -> void:
	if f["state"] != 0:
		return
	f["state"] = 1
	f["t"] = 0.45
	Game.sfx("tick", 0.7, 0.5)


func _update_platforms(delta: float) -> void:
	for f in faders:
		var c := fposmod(time / FADE_PERIOD + f["phase"], 1.0)
		var on := c < FADE_BLINK
		var a := 1.0
		if c >= FADE_ON and on:
			a = 0.3 if int(c * 70.0) % 2 == 0 else 0.95
		elif not on:
			a = 0.12
		f["art"].modulate.a = a
		if on != f["on"]:
			f["on"] = on
			f["shape"].set_deferred("disabled", not on)
			if on:
				Fx.burst(self, f["body"].position, 6, Color(0.7, 0.9, 1.0), 60.0, Vector2.UP, 180.0, 0.0, 4.0, 0.35)
	for f in fallers:
		var body: AnimatableBody2D = f["body"]
		var art: Node2D = f["art"]
		match f["state"]:
			1:
				f["t"] -= delta
				art.position.x = sin(f["t"] * 90.0) * 2.0
				if f["t"] <= 0.0:
					art.position.x = 0.0
					f["state"] = 2
					f["vy"] = 0.0
			2:
				f["vy"] = minf(f["vy"] + 1500.0 * delta, 760.0)
				body.position.y += f["vy"] * delta
				var drop: float = body.position.y - f["origin"].y
				art.modulate.a = clampf(1.0 - (drop - 3.0 * T) / (3.0 * T), 0.0, 1.0)
				if drop > 7.0 * T:
					f["state"] = 3
					f["t"] = 2.5
					f["shape"].set_deferred("disabled", true)
			3:
				f["t"] -= delta
				if f["t"] <= 0.0:
					f["state"] = 0
					body.position = f["origin"]
					f["shape"].set_deferred("disabled", false)
					art.modulate.a = 0.0
					art.create_tween().tween_property(art, "modulate:a", 1.0, 0.3)


## Coins (and rush mode clocks) fly to a bear with the coin magnet.
func _update_magnets(delta: float) -> void:
	for p in players:
		if p.dead or p.magnet_t <= 0.0:
			continue
		var c: Vector2 = p.center()
		for cell in pickups.keys():
			if not pickups.has(cell):
				continue
			var item: Dictionary = pickups[cell]
			if item["type"] not in ["coin", "clock"] or not is_instance_valid(item["node"]):
				continue
			var node: Node2D = item["node"]
			var d := node.position.distance_to(c)
			if d > MAGNET_RANGE:
				continue
			if not item.get("pulled", false):
				item["pulled"] = true
				floaters = floaters.filter(func(f: Array) -> bool: return f[0] != node)
			node.position = node.position.move_toward(c, (360.0 + (MAGNET_RANGE - d) * 5.0) * delta)
			if node.position.distance_to(c) < 22.0:
				_collect(p, cell)


## Active power-ups of all bears, for the HUD.
func _power_list() -> Array:
	var best := {}
	var order: Array = []
	for p in players:
		for pw in p.powers():
			if not best.has(pw[0]):
				order.append(pw[0])
				best[pw[0]] = pw[1]
			elif pw[1].is_valid_int() and best[pw[0]].is_valid_int() and int(pw[1]) > int(best[pw[0]]):
				best[pw[0]] = pw[1]
	var out: Array = []
	for k in order:
		out.append([k, best[k]])
	return out


func _add_pickup(cell: Vector2i, type: String, bit: int = 0, kind: String = "") -> void:
	var node: Node2D
	var at := _feet(cell)
	match type:
		"coin":
			node = _sprite(151)
			node.position = _mid(cell)
			add_child(node)
			floaters.append([node, node.position.y])
		"gem":
			node = Fx.play(self, "gem", at + Vector2(0, -2), {"scale": 1.3, "z": 2})
		"heart":
			node = Fx.play(self, "heart", at, {"z": 2})
		"star":
			node = Fx.play(self, "star", at, {"z": 2})
		"clock":
			node = Fx.play(self, "orb", at + Vector2(0, -4), {"z": 2, "tint": Color(0.6, 1.4, 0.8)})
		"shard":
			node = Fx.play(self, "shard", at, {"scale": 2.0, "z": 2})
		"power":
			var info: Dictionary = Powers.POWERS[kind]
			node = Node2D.new()
			node.position = at
			node.z_index = 2
			add_child(node)
			Fx.play(node, "orb", Vector2(0, -2), {"z": 0, "tint": info["tint"], "alpha": 0.85})
			# a soap bubble around the icon, so power-ups stand out from coins and gems
			var ring := PackedVector2Array()
			for i in 20:
				ring.append(Vector2(0, -21) + Vector2.from_angle(TAU * i / 20.0) * 19.0)
			var fill := Polygon2D.new()
			fill.polygon = ring
			fill.color = Color(info["tint"].clamp(), 0.28)
			node.add_child(fill)
			var edge := Line2D.new()
			edge.points = ring
			edge.closed = true
			edge.width = 3.0
			edge.default_color = Color(1, 1, 1, 0.85)
			node.add_child(edge)
			var icon: Node2D = PixelArt.make(info["art"], Vector2(-4, -4))
			icon.position = Vector2(0, -22)
			icon.scale = Vector2(3, 3)
			icon.bob = 1.0
			icon.z_index = 1
			node.add_child(icon)
	pickups[cell] = {"type": type, "node": node, "bit": bit, "kind": kind}
	used[cell] = true


func _add_crate(cell: Vector2i) -> void:
	var body := _static(cell, Vector2(T, T))
	body.add_child(_sprite(26))
	crates[cell] = body
	used[cell] = true


func _add_crumble(cell: Vector2i) -> void:
	var body := _static(cell, Vector2(T, T))
	var spr := _sprite(29)
	spr.modulate = Color(0.95, 0.85, 0.78)
	body.add_child(spr)
	body.set_meta("gone", false)
	body.set_meta("crumble", _crumble.bind(body, spr))
	crumbles[cell] = body
	used[cell] = true


func _crumble(body: StaticBody2D, spr: Sprite2D) -> void:
	if body.get_meta("gone") or body.has_meta("shaking"):
		return
	body.set_meta("shaking", true)
	Game.sfx("tick", 0.8, 0.4)
	var tw := body.create_tween()
	for i in 5:
		tw.tween_property(spr, "position:x", 3.0 if i % 2 == 0 else -3.0, 0.08)
	tw.tween_callback(func() -> void:
		body.set_meta("gone", true)
		body.get_child(0).set_deferred("disabled", true)
		Fx.burst(self, body.position, 6, Color(0.7, 0.55, 0.4), 80.0, Vector2.DOWN, 60.0, 500.0, 6.0, 0.5))
	tw.tween_property(spr, "position", Vector2(0, 90), 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(spr, "modulate:a", 0.0, 0.35)
	tw.tween_interval(3.0)
	tw.tween_callback(func() -> void:
		spr.position = Vector2.ZERO
		body.set_meta("gone", false)
		body.remove_meta("shaking")
		body.get_child(0).set_deferred("disabled", false))
	tw.tween_property(spr, "modulate:a", 1.0, 0.25)


func _add_door(cell: Vector2i, k: int, id: int) -> void:
	var body := _static(cell, Vector2(T, k * T))
	for i in k:
		var spr := _sprite(28)
		spr.position = Vector2(0, (i - (k - 1) / 2.0) * T)
		body.add_child(spr)
		door_cells[cell + Vector2i(0, i)] = body
		used[cell + Vector2i(0, i)] = true
	doors.get_or_add(id, []).append(body)


func _add_flag(cell: Vector2i) -> void:
	var holder := Node2D.new()
	holder.position = _mid(cell)
	holder.z_index = -1
	add_child(holder)
	holder.add_child(_sprite(131))
	var flag := _sprite(111)
	flag.position.y = -T
	flag.modulate = Color(0.5, 0.5, 0.5)
	holder.add_child(flag)
	flag_sprites.append(flag)
	var data := {"pos": _feet(cell), "flag": flag, "on": false}
	flags[cell] = data
	flags[cell + Vector2i.UP] = data
	used[cell] = true
	used[cell + Vector2i.UP] = true


func _add_enemy(kind: String, cell: Vector2i) -> Node2D:
	var e: Node2D = EnemyScript.new()
	e.kind = kind
	e.level = self
	e.position = _feet(cell)
	if kind == "icicle":
		e.position = Vector2((cell.x + 0.5) * T, cell.y * T + 30.0)
	add_child(e)
	enemies.append(e)
	return e


# ---------------------------------------------------------------- scenery

## Sky, hills and weather for a theme. Rush mode calls this again in each new zone.
func _apply_look(th: String) -> void:
	look_theme = th
	backdrop.set_theme(th)
	liquid_layer.modulate = Color(3.4, 0.7, 0.22) if Levels.THEMES[th].get("lava", false) else Color(1, 1, 1, 0.85)


## Butterflies, birds, bats and wisps drifting about, for life.
func _ambient() -> void:
	if Game.mode == Game.Mode.TIME_TRIAL or width < 40:
		return
	var critter: String = {"grass": "butterfly", "sand": "bird", "snow": "bird", "storm": "bat", "castle": "wisp"}[theme]
	var count := clampi(width / 28, 2, 9)
	for i in count:
		var x := (i + randf_range(0.2, 0.8)) * width * T / count
		var y := GROUND * T - (randf_range(50, 110) if critter in ["butterfly", "wisp"] else randf_range(220, 330))
		Fx.play(self, critter, Vector2(x, y), {"z": -1, "flip": randf() < 0.5, "alpha": 0.9})


# ---------------------------------------------------------------- running

func _physics_process(delta: float) -> void:
	if not done_building:
		return
	for m in movers:
		var k := 0.5 - 0.5 * cos(TAU * (time + m["origin"].x * 0.0007) / m["period"])
		m["body"].position = m["origin"] + m["axis"] * k
	_update_platforms(delta)
	_update_magnets(delta)
	_update_shots(delta)
	_update_zones(delta)
	if not done and not cinematic:
		time += delta
	coin_chain_t -= delta
	if coin_chain_t <= 0.0:
		coin_chain = 0

	var total_coins := 0
	var all_home := true
	for p in players:
		total_coins += p.coins
		if p.dead:
			all_home = false
			continue
		if p.position.y > (DEEP + 1) * T:
			p.die(true)
		elif p.position.y > GROUND * T + 20 and liquid.has(floori(p.position.x / T)):
			Fx.play(self, "boom" if look_theme == "castle" else "splash", Vector2(p.position.x, GROUND * T + 8), {"z": 6, "scale": 0.7 if look_theme == "castle" else 1.0, "speed": 1.6})
			Game.sfx("explosion" if look_theme == "castle" else "splash")
			p.die(true)
		else:
			_check_cells(p)
		if p.position.distance_to(goal_pos) > 46.0:
			all_home = false
	if all_home and not done and not cinematic:
		_enter_portal()

	if Game.mode == Game.Mode.TIME_TRIAL:
		_trial(delta)
		hud.set_counts(total_coins, "TIME %d    %d M" % [ceili(maxf(trial_left, 0.0)), int(distance)])
	else:
		hud.set_counts(total_coins, "%d:%04.1f" % [int(time) / 60, fmod(time, 60.0)])
	hud.set_powers(_power_list())
	if Game.mode == Game.Mode.TUTORIAL and coach_next < coach_marks.size() and players[0].position.x >= coach_marks[coach_next][0] + 30.0:
		if coach_next > 0:
			Fx.play(self, "collect", players[0].center(), {"z": 8})
		hud.coach(Game.fill_hints(coach_marks[coach_next][1]))
		coach_next += 1

	cull_t -= delta
	if cull_t <= 0.0:
		cull_t = 0.5
		var keep: Array = []
		for e in enemies:
			if not is_instance_valid(e) or e.dead:
				continue
			if Game.mode == Game.Mode.TIME_TRIAL and e.position.x < cam.position.x - 1500.0:
				e.queue_free()
				continue
			keep.append(e)
		enemies = keep


## Everything a bear can touch by standing in a tile: coins, spikes, springs, flags.
func _check_cells(p: CharacterBody2D) -> void:
	var r: Rect2 = p.rect()
	for cx in range(floori(r.position.x / T), floori((r.end.x - 0.01) / T) + 1):
		for cy in range(floori(r.position.y / T), floori((r.end.y - 0.01) / T) + 1):
			var cell := Vector2i(cx, cy)
			if pickups.has(cell):
				_collect(p, cell)
			if spikes.has(cell):
				var top: float = cy * T + (18.0 if spikes[cell] == 1 else 0.0)
				if r.intersects(Rect2(cx * T + 6.0, top, 24.0, 18.0)):
					p.hurt(p.position.x - p.facing * 10.0)
					if p.velocity.y > 0.0 and spikes[cell] == 1 and not p.dead:
						p.velocity.y = -360.0
			if springs.has(cell) and p.velocity.y >= 0.0 and p.position.y > cy * T + 14.0:
				p.bounce(p.SPRING_VELOCITY, "spring")
				var spr: Sprite2D = springs[cell]
				spr.texture = tile(108)
				Fx.burst(self, _feet(cell), 8, DUST, 160.0, Vector2.UP, 60.0, 300.0, 4.0, 0.4)
				var tw := spr.create_tween()
				tw.tween_interval(0.25)
				tw.tween_callback(func() -> void: spr.texture = tile(107))
			if flags.has(cell) and not flags[cell]["on"]:
				_checkpoint(flags[cell])


func _collect(p: CharacterBody2D, cell: Vector2i) -> void:
	var item: Dictionary = pickups[cell]
	var node: Node2D = item["node"]
	var at := node.position if item.get("pulled", false) else _mid(cell)
	match item["type"]:
		"coin":
			p.coins += 1
			coin_chain = mini(coin_chain + 1, 12)
			coin_chain_t = 0.6
			Game.sfx("coin", 1.0 + coin_chain * 0.04)
			Fx.burst(self, at, 6, Color(1.0, 0.9, 0.3), 110.0, Vector2.UP, 180.0, 150.0, 4.0, 0.4)
			var tw := node.create_tween().set_parallel()
			tw.tween_property(node, "position:y", at.y - 40.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(node, "modulate:a", 0.0, 0.3)
			tw.chain().tween_callback(node.queue_free)
			floaters = floaters.filter(func(f: Array) -> bool: return f[0] != node)
		"gem":
			gems_got |= 1 << int(item["bit"])
			hud.set_gems(gems_got)
			Game.sfx("gem")
			Fx.play(self, "collect", at + Vector2(0, 14), {"scale": 1.4, "z": 8})
			_float_text(at, "GEM!", Color(1.0, 0.4, 0.5))
			Game.hitstop(0.05)
			node.queue_free()
		"heart":
			if p.hp >= p.MAX_HP:
				return
			p.heal(1)
			hud.update_hearts()
			Game.sfx("heart")
			Fx.play(self, "heal", p.position, {"z": 8, "follow": p})
			node.queue_free()
		"star":
			p.star = p.STAR_TIME
			Game.sfx("powerup")
			show_message("POWER STAR!", 1.4)
			Fx.play(self, "collect", at + Vector2(0, 14), {"scale": 1.6, "z": 8})
			Fx.play(self, "levelup", p.position, {"z": 8, "follow": p, "speed": 1.5})
			shake(3.0)
			node.queue_free()
		"power":
			var info: Dictionary = Powers.POWERS[item["kind"]]
			p.power_up(item["kind"])
			Game.sfx("powerup", 1.15)
			var text: String = info["name"] + "!"
			if item["kind"] == "jump":
				text = "DOUBLE JUMP!" if p.air_jumps == 1 else "TRIPLE JUMP!"
			show_message(text, 1.2)
			Fx.play(self, "collect", at + Vector2(0, 14), {"scale": 1.4, "z": 8, "tint": info["tint"]})
			Fx.burst(self, at, 12, info["tint"].clamp(), 160.0, Vector2.UP, 180.0, 200.0, 5.0, 0.5)
			node.queue_free()
		"clock":
			trial_left += 3.0
			Game.sfx("gem", 1.3)
			Fx.play(self, "collect", at + Vector2(0, 14), {"z": 8})
			_float_text(at, "+3 SEC", Color(0.5, 1.0, 0.6))
			node.queue_free()
		"shard":
			node.queue_free()
			pickups.erase(cell)
			_shard_got(p)
			return
	pickups.erase(cell)


func _float_text(at: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.2))
	l.add_theme_constant_override("outline_size", 6)
	l.position = at + Vector2(-30, -30)
	l.z_index = 9
	add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 46.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


func _checkpoint(data: Dictionary) -> void:
	for cell in flags:
		flags[cell]["on"] = false
		flags[cell]["flag"].modulate = Color(0.5, 0.5, 0.5)
	data["on"] = true
	checkpoint = data["pos"]
	var flag: Sprite2D = data["flag"]
	flag.modulate = Color.WHITE
	_pop(flag)
	Fx.play(self, "respawn", checkpoint, {"z": 1, "speed": 1.6, "alpha": 0.8})
	Fx.burst(self, flag.global_position, 14, Color(1.0, 0.95, 0.5), 140.0, Vector2.UP, 120.0, 250.0, 4.0, 0.5)
	for p in players:
		p.heal()
	hud.update_hearts()
	_set_spawns()
	Game.sfx("checkpoint")
	_float_text(checkpoint + Vector2(0, -70), "CHECKPOINT", Color(1.0, 0.95, 0.5))


## Levers next to the bear get pulled.
func interact(p: CharacterBody2D) -> void:
	var here := cell_of(p.center())
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var cell: Vector2i = here + Vector2i(dx, dy)
			if not levers.has(cell) or levers[cell]["on"]:
				continue
			var lever: Dictionary = levers[cell]
			lever["on"] = true
			var spr: Sprite2D = lever["spr"]
			spr.texture = tile(66)
			_pop(spr)
			shake(3.0)
			Game.sfx("lever")
			Fx.play(self, "hit", spr.position, {"z": 8, "scale": 0.7})
			for door: StaticBody2D in doors.get(lever["id"], []):
				door.get_child(0).set_deferred("disabled", true)
				for cell2 in door_cells.keys():
					if door_cells[cell2] == door:
						door_cells.erase(cell2)
				var tw := door.create_tween().set_parallel()
				tw.tween_property(door, "position:y", door.position.y - 60.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tw.tween_property(door, "modulate:a", 0.0, 0.4)
				Fx.burst(self, door.position, 12, Color(1.0, 0.85, 0.3), 120.0, Vector2.UP, 180.0, 300.0, 5.0, 0.5)
				Game.sfx("door")


## Claws and ground pounds: hurt every enemy, boss and crate inside the box.
## hit_ids remembers what one swing has already hit. Returns how many things it hit.
func strike(box: Rect2, dmg: int, dir: int, _who: Node, hit_ids: Array, how: String) -> int:
	var n := 0
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var id: int = e.get_instance_id()
		if id in hit_ids or not box.intersects(e.rect()):
			continue
		hit_ids.append(id)
		if e.hit(dmg, dir, how):
			n += 1
	if boss != null and is_instance_valid(boss) and not boss.dead and box.intersects(boss.rect()):
		var id := boss.get_instance_id()
		if id not in hit_ids:
			hit_ids.append(id)
			if boss.hit(dmg, dir, how):
				n += 1
	for cx in range(floori(box.position.x / T), floori(box.end.x / T) + 1):
		for cy in range(floori(box.position.y / T), floori(box.end.y / T) + 1):
			var cell := Vector2i(cx, cy)
			if crates.has(cell):
				_break_crate(cell, dir)
				n += 1
	# claws swat projectiles out of the air
	if how != "pound":
		for s in shots:
			if not s["dead"] and box.has_point(s["node"].position):
				s["dead"] = true
				Fx.play(self, "hit", s["node"].position, {"z": 8, "scale": 0.8})
				Game.sfx("tick", 1.5, 0.7)
	return n


func _break_crate(cell: Vector2i, dir: int) -> void:
	var body: StaticBody2D = crates[cell]
	crates.erase(cell)
	body.queue_free()
	var at := _mid(cell)
	Fx.play(self, "hit", at, {"z": 8})
	Fx.burst(self, at, 12, Color(0.78, 0.55, 0.36), 220.0, Vector2(dir * 0.6, -1.0), 70.0, 600.0, 7.0, 0.6)
	Game.sfx("break")
	for i in 2:
		players[0].coins += 1
		var coin := _sprite(151)
		coin.position = at
		coin.z_index = 6
		add_child(coin)
		var tw := coin.create_tween().set_parallel()
		tw.tween_property(coin, "position", at + Vector2((i * 2 - 1) * 26.0, -54.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "modulate:a", 0.0, 0.2).set_delay(0.3)
		tw.chain().tween_callback(coin.queue_free)
	Game.sfx("coin", 1.2, 0.7)


func mushroom_bounced(_body: Node, at: Vector2) -> void:
	Fx.burst(self, at, 10, Color(1, 0.85, 0.85), 140.0, Vector2.UP, 60.0, 400.0, 4.0, 0.45)
	Fx.play(self, "thud", at, {"z": 6, "scale": 0.8, "tint": Color(1.0, 0.8, 0.8)})


func enemy_died(e: Node2D) -> void:
	kills += 1
	if not e.minion:
		players[0].coins += 1
		_float_text(e.center(), "+1", Color(1.0, 0.9, 0.3))


func minion_count() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.minion:
			n += 1
	return n


## A projectile that hurts on touch and pops on walls. fx art points right.
func shoot(at: Vector2, vel: Vector2, fx: String, opts: Dictionary = {}) -> void:
	var holder := Node2D.new()
	holder.position = at
	holder.z_index = 4
	add_child(holder)
	var spr := Fx.play(holder, fx, Vector2.ZERO, {"scale": opts.get("scale", 1.0)})
	spr.rotation = opts.get("rot", vel.angle())
	shots.append({"node": holder, "vel": vel, "life": opts.get("life", 4.0), "radius": opts.get("radius", 11.0), "dead": false})


func _update_shots(delta: float) -> void:
	var i := shots.size() - 1
	while i >= 0:
		var s: Dictionary = shots[i]
		var node: Node2D = s["node"]
		s["life"] -= delta
		node.position += s["vel"] * delta
		var r: float = s["radius"]
		var box := Rect2(node.position - Vector2(r, r), Vector2(r, r) * 2.0)
		if not s["dead"]:
			for p in players:
				if not p.dead and box.intersects(p.rect()):
					p.hurt(node.position.x - signf(s["vel"].x) * 10.0)
					s["dead"] = true
					Fx.play(self, "hit", node.position, {"z": 8})
			if solid_at(node.position) or s["life"] <= 0.0:
				s["dead"] = true
				Fx.burst(self, node.position, 6, Color(1, 0.9, 0.7), 120.0, -s["vel"].normalized(), 60.0, 200.0, 4.0, 0.3)
		if s["dead"]:
			node.queue_free()
			shots.remove_at(i)
		i -= 1


## A patch of danger that switches on after `from` seconds and off after `to` (boss attacks).
func zone(box: Rect2, from: float, to: float, source_x: float) -> void:
	zones.append({"rect": box, "t": 0.0, "from": from, "to": to, "x": source_x})


func _update_zones(delta: float) -> void:
	var i := zones.size() - 1
	while i >= 0:
		var z: Dictionary = zones[i]
		z["t"] += delta
		if z["t"] > z["to"]:
			zones.remove_at(i)
		elif z["t"] >= z["from"]:
			for p in players:
				if not p.dead and z["rect"].intersects(p.rect()):
					p.hurt(z["x"])
		i -= 1


func player_hurt(p: CharacterBody2D) -> void:
	Game.hitstop(0.07)
	shake(6.0)
	hud.heart_lost(players.find(p))


func player_respawned(_p: CharacterBody2D) -> void:
	hud.update_hearts()


## In co-op, one bear dying takes the whole team back to the checkpoint.
func _on_died(who: Node) -> void:
	if who.has_meta("wiping"):
		return
	deaths += 1
	hud.update_hearts()
	for p in players:
		if p != who and not p.dead:
			p.set_meta("wiping", true)
			p.die(true)
			p.remove_meta("wiping")


func _set_spawns() -> void:
	for i in players.size():
		players[i].spawn_point = checkpoint + Vector2(i * 28, 0)


func show_message(text: String, seconds: float) -> void:
	hud.message(text, seconds)


func flash_screen(color: Color) -> void:
	hud.flash(color)


func _process(delta: float) -> void:
	if not done_building or players.is_empty():
		return
	var center := Vector2.ZERO
	var vx := 0.0
	for p in players:
		center += p.position
		vx += p.velocity.x
	vx /= players.size()
	look = lerpf(look, clampf(vx * 0.3, -90.0, 90.0), 1.0 - exp(-3.0 * delta))
	var target := center / players.size() + Vector2(look, -80)
	if boss != null:
		target = Vector2(17 * T, 5.5 * T)
	cam.position = cam.position.lerp(target, 1.0 - exp(-6.0 * delta))
	shake_amt = move_toward(shake_amt, 0.0, 30.0 * delta)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt

	backdrop.scroll(cam.get_screen_center_position().x, cam.get_screen_center_position().y, delta)

	# coins spin and bob
	var now := Time.get_ticks_msec() / 1000.0
	for f in floaters:
		var s: Sprite2D = f[0]
		if not is_instance_valid(s):
			continue
		var phase := now * 3.0 + s.position.x * 0.03
		s.position.y = f[1] + sin(phase) * 3.0
		s.scale.x = 2.0 * maxf(absf(cos(phase * 0.8)), 0.15)
	liquid_layer.position.y = sin(now * 2.0) * 2.0
	if flag_frames.is_empty():
		flag_frames = [tile(111), tile(112)]
	for f in flag_sprites:   # flags flutter
		f.texture = flag_frames[int(now * 6.0) % 2]

	if look_theme == "storm" and not done:
		storm_t -= delta
		if storm_t <= 0.0:
			storm_t = randf_range(5.0, 11.0)
			hud.flash(Color(1, 1, 1, 0.22), 0.5)
			Game.sfx("zap", 0.45, 0.35)


## Shake the camera. Bigger hits win over smaller ones.
func shake(amount: float) -> void:
	if Game.setting("shake"):
		shake_amt = maxf(shake_amt, amount)


## Quick bounce-scale on a sprite (flags, levers).
func _pop(s: Node2D) -> void:
	var base := s.scale
	s.scale = base * Vector2(1.4, 0.6)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", base, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, false).timeout


## Waits in real time, so it still works during slow motion.
func _wait_real(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, false, false, true).timeout


func _talk(lines: Array) -> void:
	dialog.say(lines)
	await dialog.done
	await _wait(0.15)


# ---------------------------------------------------------------- pausing and leaving

func toggle_pause() -> void:
	if done or cinematic or Game.busy() or dialog.open:
		return
	paused = not paused
	get_tree().paused = paused
	Game.sfx("menu_select", 0.8 if paused else 1.2)
	Game.touch.set_active(not paused)
	hud.pause(paused, "EXIT TO MAP" if Game.mode == Game.Mode.STORY else "EXIT TO MENU")


func exit_level() -> void:
	Game.goto_menu("map" if Game.mode == Game.Mode.STORY else "")


# ---------------------------------------------------------------- finishing

func _enter_portal() -> void:
	done = true
	Game.touch.set_active(false)
	Game.sfx("goal")
	for p in players:
		p.frozen = true
		p.velocity = Vector2.ZERO
		p.set_physics_process(false)
		var tw: Tween = p.create_tween().set_parallel()
		tw.tween_property(p, "position", goal_pos + Vector2(0, -30), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "scale", Vector2(0.05, 0.05), 0.5).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "rotation", TAU * 2.0, 0.5)
	await _wait(0.5)
	Fx.play(self, "mana_burst", goal_pos + Vector2(0, -6), {"z": 8, "scale": 1.3})
	Fx.play(self, "collect", goal_pos + Vector2(0, -10), {"z": 8, "scale": 2.0})
	shake(6.0)
	_finish()


func _rank(boss_fight: bool) -> String:
	var hits := 0
	for p in players:
		hits += p.hits_taken
	if boss_fight:
		if deaths == 0 and hits <= 1:
			return "S"
		if deaths == 0:
			return "A"
		return "B" if deaths <= 2 else "C"
	var gems := (gems_got & 1) + ((gems_got >> 1) & 1) + ((gems_got >> 2) & 1)
	if deaths == 0 and gems == 3:
		return "S"
	if deaths <= 1 and gems >= 2:
		return "A"
	return "B" if deaths <= 3 else "C"


func _finish() -> void:
	done = true
	Game.touch.set_active(false)
	var total_coins := 0
	for p in players:
		total_coins += p.coins
	var clock := "%d:%04.1f" % [int(time) / 60, fmod(time, 60.0)]
	Game.bank_coins(total_coins)    # coins go to the bank, to spend in the Bear Shop
	var bank := "%d  (BANK %d)" % [total_coins, Game.wallet()]
	Game.sfx("victory")
	hud.party()
	if Game.mode == Game.Mode.TUTORIAL:
		hud.banner("banner_clear")
		Game.mark_seen("tutorial")
		await _wait(1.8)
		hud.results({"title": "BOOTCAMP COMPLETE!", "rows": [["TIME", clock], ["COINS", bank]],
			"note": "YOU ARE READY FOR THE REAL THING!",
			"buttons": [["STORY", func() -> void: Game.goto_menu("story")], ["AGAIN", func() -> void: Game.restart_level()],
				["MENU", func() -> void: Game.goto_menu()]]})
		return
	var is_boss := boss != null
	hud.banner("banner_boss" if is_boss else "banner_clear")
	var rank := _rank(is_boss)
	var before: Dictionary = Game.level_stat(Game.level)
	var saved: Dictionary = Game.record_level(Game.level, time, gems_got, rank)
	var note := ""
	if before["done"] and saved["best_time"]:
		note = "NEW BEST TIME!"
	elif Game.level == Game.LEVEL_COUNT - 1:
		note = "THE CRYSTAL IS WHOLE AGAIN!"
	await _wait(1.8)
	hud.results({"title": "%s  %s" % [Levels.label(Game.level), title], "rows": [["TIME", clock], ["COINS", bank], ["TUMBLES", deaths]],
		"gems": -1 if is_boss else gems_got, "rank": rank, "note": note,
		"buttons": [["NEXT", func() -> void: Game.next_level()], ["RETRY", func() -> void: Game.restart_level()],
			["MAP", func() -> void: Game.goto_menu("map")]]})


# ---------------------------------------------------------------- boss fights

func _boss_intro() -> void:
	cinematic = true
	for p in players:
		p.frozen = true
	hud.bars(true)
	var home := boss.position
	match boss.kind:
		"clank", "block", "king":
			boss.position.y -= 700.0
			await _wait(0.8)
			var tw := boss.create_tween()
			tw.tween_property(boss, "position:y", home.y, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await tw.finished
			boss._land_fx(1.2)
			if boss.kind == "block":
				await _wait(0.7)
				var up := boss.create_tween()
				up.tween_property(boss, "position:y", boss.hover_y, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		"drill":
			boss.actor.visible = false
			await _wait(0.8)
			Fx.play(self, "quake", home, {"z": 6, "speed": 1.5})
			shake(5.0)
			await _wait(0.7)
			Fx.play(self, "dirt_boom", home, {"scale": 1.4, "z": 6, "speed": 1.4})
			Fx.play(self, "earth_spike", home, {"scale": 1.6, "z": 1, "speed": 1.8})
			Game.sfx("slam", 1.2)
			shake(11.0)
			boss.actor.visible = true
			boss.squash = Vector2(0.6, 1.5)
		"flap":
			boss.position = Vector2(home.x + 500.0, home.y - 700.0)
			await _wait(0.6)
			Game.sfx("whoosh", 0.7)
			var tw := boss.create_tween()
			tw.tween_property(boss, "position", Vector2(home.x, home.y - 5.0 * T), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			await tw.finished
	Game.sfx("roar")
	shake(6.0)
	await _wait(0.9)
	await _talk(boss.info["intro"])
	Game.music("boss", 0.9 if boss.kind == "king" else 1.0)
	await hud.versus(boss.info["who"], boss.info["name"], boss.info["title"])
	hud.bars(false)
	hud.boss_bar(boss.info["name"])
	for p in players:
		p.frozen = false
	cinematic = false
	Game.touch.set_active(true)
	boss.start_fight()
	show_message("FIGHT!", 0.9)
	Game.sfx("go")


func boss_hurt(b: Node2D, _dmg: int) -> void:
	hud.boss_set(b.hp / float(b.max_hp))
	Game.hitstop(0.05)


func _clear_danger() -> void:
	for s in shots:
		s["dead"] = true
	zones.clear()
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.minion:
			e.die()


func boss_defeated(b: Node2D) -> void:
	cinematic = true
	_clear_danger()
	hud.boss_set(0.0)
	for p in players:
		p.invuln = 99.0
	var v: Vector2 = hud.view()
	Fx.play(hud.fx_holder, "impact_frame", v / 2.0, {"scale": maxf(v.x / 320.0, v.y / 180.0), "real_time": true, "alpha": 0.9})
	Game.sfx("boss_hit", 0.6)
	Game.slowmo(0.15)
	b.state = "dying"
	await _wait_real(0.5)
	Game.slowmo(0.4)
	for i in 9:
		var at: Vector2 = b.center() + Vector2(randf_range(-60, 60), randf_range(-50, 50))
		Fx.play(self, "boom" if i % 3 == 0 else "plasma_boom", at + Vector2(0, 40 if i % 3 == 0 else 0), {"z": 8, "scale": 0.8, "speed": 1.6})
		Game.sfx("explosion", randf_range(0.9, 1.3))
		shake(7.0)
		b.flash = 0.08
		b.actor.rotation = randf_range(-0.2, 0.2)
		await _wait_real(0.22)
	Game.slowmo(1.0)
	Fx.play(self, "big_boom", b.position, {"z": 8, "scale": 1.4, "speed": 1.3})
	Game.sfx("explosion", 0.6)
	hud.flash(Color(1, 1, 1, 0.9), 0.6)
	shake(18.0)
	b.visible = false
	Game.music("menu", 1.0)
	await _wait(1.6)
	hud.boss_hide()
	for p in players:
		p.frozen = true
		p.invuln = 0.0
	hud.bars(true)
	await _talk(b.info["outro"])
	hud.bars(false)
	# the shard floats down into the arena
	var cell := Vector2i(17, GROUND - 2)
	_add_pickup(cell, "shard")
	Fx.play(self, "holy_pillar", _feet(Vector2i(17, GROUND - 1)), {"z": 1, "scale": 1.5})
	Game.sfx("powerup", 0.8)
	show_message("GRAB THE CRYSTAL SHARD!", 2.0)
	for p in players:
		p.frozen = false
	cinematic = false
	Game.touch.set_active(true)


func _shard_got(p: CharacterBody2D) -> void:
	done = true
	for q in players:
		q.frozen = true
	Fx.play(self, "holy_pillar", p.position, {"z": 1, "scale": 1.5})
	Fx.play(self, "levelup", p.position, {"z": 8, "follow": p})
	Game.sfx("powerup")
	Game.hitstop(0.12)
	hud.flash(Color(1, 0.9, 1, 0.5), 0.5)
	var n := Levels.world_of(Game.level) + 1
	show_message("CRYSTAL SHARD %d OF 5!" % n, 1.8)
	await _wait(1.6)
	_finish()


## King Bear reaches half health: he takes the crystal's power for round two.
func king_transform(b: Node2D) -> void:
	cinematic = true
	_clear_danger()
	for p in players:
		p.frozen = true
	hud.bars(true)
	await _wait(0.6)
	await _talk(b.info["mid"])
	Fx.play(self, "charge", b.center(), {"z": 8, "scale": 2.0, "tint": Color(1.3, 0.6, 1.5)})
	Game.sfx("roar", 0.7)
	for i in 6:
		shake(4.0 + i * 2.0)
		await _wait(0.2)
	Fx.play(self, "dark_boom", b.position, {"z": 8, "scale": 1.6, "speed": 1.2})
	Game.sfx("explosion", 0.7)
	hud.flash(Color(0.8, 0.4, 1.0, 0.8), 0.7)
	shake(16.0)
	b.powered_up()
	hud.boss_bar("REBOUND KING BEAR")
	Game.music("final")
	await _wait(1.3)
	hud.bars(false)
	for p in players:
		p.frozen = false
	cinematic = false
	show_message("FINAL ROUND!", 1.4)
	Game.sfx("go")


# ---------------------------------------------------------------- rush mode (time trial)

func _countdown() -> void:
	cinematic = true
	for p in players:
		p.frozen = true
	await _wait(0.5)
	var v: Vector2 = hud.view()
	Fx.play(hud.fx_holder, "countdown", v / 2.0 + Vector2(0, -40), {"scale": 3.0, "real_time": true})
	for i in 3:
		Game.sfx("tick")
		await _wait(0.62)
	Game.sfx("go")
	for p in players:
		p.frozen = false
	cinematic = false
	trial_running = true
	Game.touch.set_active(true)


func _trial(delta: float) -> void:
	var lead: CharacterBody2D = players[0]
	while next_x * T < lead.position.x + 46 * T:
		_trial_extend()
	if not trial_running or done:
		return
	trial_left -= delta
	distance = maxf(distance, (lead.position.x - start_x) / T)
	# respawn point follows you: the last place you stood on solid ground
	if lead.is_on_floor() and not lead.dead and lead.position.x > checkpoint.x + 300.0:
		var c := cell_of(lead.position + Vector2(0, 8))
		if solid.has(c) and solid.has(c + Vector2i.LEFT) and solid.has(c + Vector2i.RIGHT) and not spikes.has(c + Vector2i.UP):
			checkpoint = Vector2(lead.position.x, c.y * T)
			_set_spawns()
	if not zone_marks.is_empty() and lead.position.x > zone_marks[0][0]:
		var z: int = zone_marks.pop_front()[1]
		trial_left += 12.0
		_apply_look(Levels.TRIAL_THEMES[z])
		slippery = Levels.THEMES[Levels.TRIAL_THEMES[z]].get("slippery", false)
		hud.flash(Color(1, 1, 1, 0.6), 0.5)
		show_message("ZONE %d: %s\n+12 SEC" % [z + 1, Levels.TRIAL_ZONES[z]], 2.0)
		Game.sfx("checkpoint")
	var sec := ceili(trial_left)
	if sec <= 10 and sec < last_tick and sec > 0:
		Game.sfx("tick", 1.0 + (10 - sec) * 0.04)
		hud.time_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		Ui.pop(hud.time_label, 1.5, 0.15)
	last_tick = sec
	if sec > 10:
		hud.time_label.add_theme_color_override("font_color", Color(1, 0.96, 0.84))
	if trial_left <= 0.0:
		_trial_end()


func _trial_extend() -> void:
	var meters := next_x - int(start_x / T)
	var new_tier := mini(meters / 170, Levels.TRIAL_TIERS.size() - 1)
	var chunk := ""
	if new_tier != tier:
		tier = new_tier
		chunk = "rest"
		zone_marks.append([next_x * T, tier])
	else:
		var pool: Array = Levels.TRIAL_TIERS[tier].duplicate()
		if tier > 0 and randf() < 0.25:
			pool = Levels.TRIAL_TIERS[tier - 1].duplicate()
		pool.erase(last_chunk)
		chunk = pool.pick_random()
	last_chunk = chunk
	chunk_theme = Levels.TRIAL_THEMES[tier]
	last_cp = next_x + 9999   # no flags in rush mode
	next_x += place_chunk(chunk, next_x, next_x)
	_commit_solids()


func _trial_end() -> void:
	done = true
	trial_left = 0.0
	Game.touch.set_active(false)
	for p in players:
		p.frozen = true
	Game.sfx("timeup")
	var meters := int(distance)
	var best := Game.best_distance()
	var record := Game.save_distance(meters)
	var total_coins := 0
	for p in players:
		total_coins += p.coins
	Game.bank_coins(total_coins)
	var medal := "NO MEDAL YET - REACH 150 M"
	if meters >= 600:
		medal = "GOLD MEDAL!"
	elif meters >= 350:
		medal = "SILVER MEDAL!"
	elif meters >= 150:
		medal = "BRONZE MEDAL!"
	show_message("TIME'S UP!", 1.5)
	if record:
		hud.banner("banner_record")
		hud.party()
	await _wait(1.6)
	hud.results({"title": "RUSH MODE", "rows": [["DISTANCE", "%d M" % meters], ["BEST", "%d M" % maxi(best, meters)],
			["COINS", "%d  (BANK %d)" % [total_coins, Game.wallet()]], ["BADDIES BOPPED", kills]],
		"note": medal,
		"buttons": [["RETRY", func() -> void: Game.restart_level()], ["MENU", func() -> void: Game.goto_menu()]]})

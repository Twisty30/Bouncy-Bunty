extends Control
## Title screen and menus: main, story, the 50-level world map and options.
## Everything is built in code. Controller: stick / d-pad moves, (A) presses, (B) goes back.

const Cast := preload("res://cast.gd")
const Ui := preload("res://ui.gd")
const Levels := preload("res://levels.gd")
const BackdropScript := preload("res://backdrop.gd")
const TILES := preload("res://kenney_pixel-platformer/Tilemap/tilemap_packed.png")
const WALK := preload("res://little-bear-walk.png")
const Skins := preload("res://skins.gd")
const PixelArt := preload("res://pixel_art.gd")
## Menu text and buttons draw above the scenery and every effect (effects use z 4-5).
const UI_Z := 20

var backdrop: Node
var world := Node2D.new()       # the little running-bear scene behind the buttons
var ground: TileMapLayer
var bunty := Sprite2D.new()
var bunty_y := 0.0
var bunty_vy := 0.0
var props: Array = []           # scenery sliding past [node, x]
var scroll := 0.0
var t := 0.0
var fx_layer := Node2D.new()

var logo := Control.new()
var logo_top: Label
var logo_bottom: Label
var content := CenterContainer.new()
var page := ""
var back_to := Callable()
var players := 1
var map_world := 0
var info_label: Label
var erase_armed := false
var wallet_label: Label
var shop_info: Label
var shop_coins: Label
var shop_bear: Sprite2D
var shop_buttons := {}      # id -> Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.music("title")
	backdrop = BackdropScript.new()
	backdrop.horizon = 0.42
	add_child(backdrop)
	backdrop.set_theme("grass")
	backdrop.weather_layer.layer = -4     # petals fall behind the menu, not over it
	players = Game.player_schemes.size()

	# running bear diorama
	add_child(world)
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
	for x in range(-2, 80):
		ground.set_cell(Vector2i(x, 0), 0, Vector2i(2, 1))
		for y in range(1, 6):
			ground.set_cell(Vector2i(x, y), 0, Vector2i(2, 6))
	world.add_child(ground)
	bunty.texture = WALK
	bunty.hframes = 4
	bunty.centered = false
	bunty.offset = Vector2(-16.5, -32)
	bunty.scale = Vector2(3, 3)
	Skins.dress(bunty)
	world.add_child(bunty)
	for i in 7:
		_add_prop(i * 260.0 + randf_range(0, 120))
	add_child(fx_layer)

	# logo
	logo.anchor_right = 1.0
	logo.offset_top = 36
	logo.offset_bottom = 230
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.z_index = UI_Z
	add_child(logo)
	var glow := Control.new()
	glow.anchor_left = 0.5
	glow.anchor_right = 0.5
	glow.offset_top = 96
	logo.add_child(glow)
	Fx.play(glow, "sunburst", Vector2.ZERO, {"scale": 4.0, "alpha": 0.55, "z": -UI_Z})
	logo_top = Ui.label("BOUNCY BUNTY", 58, Ui.CREAM, 18)
	logo_top.anchor_right = 1.0
	logo_top.offset_top = 6
	logo_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(logo_top)
	logo_bottom = Ui.label("REBOUND", 46, Ui.GOLD, 16)
	logo_bottom.anchor_right = 1.0
	logo_bottom.offset_top = 96
	logo_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(logo_bottom)

	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 190
	content.offset_bottom = -30
	content.z_index = UI_Z
	add_child(content)

	var credit := Ui.label("ART: KENNEY.NL   FX: PIXELFX   FONT: MARIO WORLD PIXEL BY RIPOOF", 10, Color(1, 1, 1, 0.75), 4)
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_left = 12
	credit.offset_top = -22
	credit.z_index = UI_Z
	add_child(credit)
	wallet_label = Ui.label("COINS %d" % Game.wallet(), 12, Ui.GOLD, 4)
	wallet_label.anchor_left = 1.0
	wallet_label.anchor_right = 1.0
	wallet_label.anchor_top = 1.0
	wallet_label.anchor_bottom = 1.0
	wallet_label.offset_left = -220
	wallet_label.offset_right = -12
	wallet_label.offset_top = -44
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet_label.z_index = UI_Z
	add_child(wallet_label)
	var gems := Ui.label("GEMS %d / 135" % Game.total_gems(), 12, Ui.PINK, 4)
	gems.anchor_left = 1.0
	gems.anchor_right = 1.0
	gems.anchor_top = 1.0
	gems.anchor_bottom = 1.0
	gems.offset_left = -220
	gems.offset_right = -12
	gems.offset_top = -24
	gems.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gems.z_index = UI_Z
	add_child(gems)

	match Game.menu_page:
		"map":
			map_world = Levels.world_of(Game.level)
			show_map()
		"story":
			show_story()
		"options":
			show_options()
		"shop":
			show_shop()
		_:
			show_main()
			_logo_in()
	Game.menu_page = ""


func _logo_in() -> void:
	logo_top.pivot_offset = Vector2(get_viewport_rect().size.x / 2.0, 40)
	logo_top.scale = Vector2(0.2, 0.2)
	logo_top.modulate.a = 0.0
	logo_bottom.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(logo_top, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(logo_top, "modulate:a", 1.0, 0.2)
	tw.tween_callback(func() -> void:
		Ui.pop(logo_bottom, 3.0, 0.25)
		Game.sfx("slash", 0.8)
		var v := get_viewport_rect().size
		Fx.play(fx_layer, "xslash", Vector2(v.x / 2.0 - 150, 190), {"scale": 3.0})
		Fx.play(fx_layer, "crit", Vector2(v.x / 2.0, 190), {"scale": 2.5, "alpha": 0.8}))


func _add_prop(x: float) -> void:
	var idx: int = [124, 125, 126, 128, 124, 125, 126].pick_random()
	var s := Sprite2D.new()
	var a := AtlasTexture.new()
	a.atlas = TILES
	a.region = Rect2(idx % 20 * 18, idx / 20 * 18, 18, 18)
	s.texture = a
	s.scale = Vector2(3, 3)
	s.offset = Vector2(0, -9)
	world.add_child(s)
	world.move_child(s, 0)
	props.append([s, x])


func _process(delta: float) -> void:
	t += delta
	var v := get_viewport_rect().size
	scroll += 150.0 * delta
	backdrop.scroll(scroll, 252.0, delta)
	var floor_y := v.y - 86.0
	world.position = Vector2.ZERO
	ground.position = Vector2(-fposmod(scroll, 36.0) - 36.0, floor_y)
	# the bear runs on the spot and hops now and then
	bunty.frame = int(t * 10.0) % 4
	if shop_bear != null and is_instance_valid(shop_bear):
		shop_bear.frame = int(t * 8.0) % 4
	bunty_vy += 1500.0 * delta
	bunty_y = minf(bunty_y + bunty_vy * delta, 0.0)
	if bunty_y >= 0.0 and fmod(t, 2.6) < delta:
		bunty_vy = -520.0
		Fx.burst(world, Vector2(v.x * 0.2, floor_y), 6, Color(0.96, 0.93, 0.86, 0.9), 70.0, Vector2.UP, 75.0, 120.0, 5.0, 0.4)
	bunty.position = Vector2(v.x * 0.2, floor_y + bunty_y)
	if fmod(t, 0.25) < delta and bunty_y >= 0.0:
		Fx.burst(world, bunty.position, 2, Color(0.96, 0.93, 0.86, 0.9), 40.0, Vector2(-1, -0.6), 40.0, 120.0, 5.0, 0.4)
	for p in props:
		p[1] -= 150.0 * delta
		if p[1] < -80.0:
			p[1] += v.x + 400.0 + randf_range(0, 200)
		p[0].position = Vector2(p[1], floor_y)
	# logo bob
	logo_top.rotation = sin(t * 1.3) * 0.015
	logo_bottom.pivot_offset = Vector2(v.x / 2.0, 30)
	logo_bottom.rotation = -0.04 + sin(t * 2.0) * 0.02
	logo.position.y = sin(t * 2.0) * 5.0
	if randf() < delta * 0.25:
		Fx.play(fx_layer, "butterfly", Vector2(randf_range(0.3, 0.9) * v.x, floor_y - randf_range(60, 160)), {"loop": false, "alpha": 0.9})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back") and back_to.is_valid() and not Game.busy():
		get_viewport().set_input_as_handled()
		Game.sfx("menu_select", 0.8)
		back_to.call()


# ---------------------------------------------------------------- pages

func _begin(name_: String, back: Callable, show_logo: bool = true) -> VBoxContainer:
	page = name_
	back_to = back
	erase_armed = false
	logo.visible = show_logo
	content.offset_top = 190 if show_logo else 20
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	content.add_child(box)
	Game.quiet_until = Time.get_ticks_msec() + 200
	return box


## Buttons drop in one after another; the first one gets focus.
func _finish(box: Control, focus: Control = null) -> void:
	var i := 0
	for c in box.get_children():
		if c is Control:
			c.modulate.a = 0.0
			var tw: Tween = c.create_tween()
			tw.tween_interval(i * 0.05)
			tw.tween_property(c, "modulate:a", 1.0, 0.15)
			i += 1
	if focus == null:
		for c in box.get_children():
			if c is Button and not c.disabled:
				focus = c
				break
	if focus != null:
		focus.grab_focus.call_deferred()


func show_main() -> void:
	var box := _begin("main", Callable())
	box.add_theme_constant_override("separation", 8)
	box.add_child(_main_btn("STORY", show_story))
	box.add_child(_main_btn("RUSH MODE", Game.start_time_trial))
	box.add_child(_main_btn("BOOTCAMP", Game.start_tutorial))
	box.add_child(_main_btn("BEAR SHOP", show_shop))
	box.add_child(_main_btn("OPTIONS", show_options))
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		box.add_child(_main_btn("QUIT", func() -> void: get_tree().quit()))
	_finish(box)


## Main page buttons: a bit shorter than the default so six fit under the logo.
func _main_btn(text: String, action: Callable) -> Button:
	return Ui.button(text, action, 22, Vector2(300, 0), 8)


func show_story() -> void:
	var box := _begin("story", show_main)
	var next := Game.unlocked()
	var started: bool = Game.level_stat(0)["done"] or Game.seen("intro")
	if started:
		box.add_child(Ui.button("CONTINUE  %s" % Levels.label(next), _play.bind(next)))
		box.add_child(Ui.button("WORLD MAP", func() -> void:
			map_world = Levels.world_of(next)
			show_map()))
	else:
		box.add_child(Ui.button("NEW GAME", _play.bind(0)))
	var holder := []
	var pb := Ui.button("PLAYERS: %d" % players, func() -> void:
		players = players % 3 + 1
		holder[0].text = "PLAYERS: %d" % players)
	holder.append(pb)
	box.add_child(pb)
	if started:
		box.add_child(Ui.button("WATCH THE INTRO", func() -> void:
			Game.play_cutscene("intro", func() -> void: Game.goto_menu("story"))))
	box.add_child(Ui.button("BACK", show_main))
	_finish(box)


func _play(lv: int) -> void:
	Game.set_players(players)
	Game.start_story(lv)


func show_map() -> void:
	var box := _begin("map", show_story, false)
	box.add_theme_constant_override("separation", 14)
	var w: Dictionary = Levels.WORLDS[map_world]
	backdrop.set_theme(w["theme"])
	var unlocked := Game.unlocked()

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	box.add_child(head)
	var go_prev := func() -> void:
		map_world = (map_world + 4) % 5
		show_map()
	var go_next := func() -> void:
		map_world = (map_world + 1) % 5
		show_map()
	var prev := Ui.button("<", go_prev, 26, Vector2(64, 60))
	head.add_child(prev)
	var titles := VBoxContainer.new()
	titles.custom_minimum_size = Vector2(560, 0)
	head.add_child(titles)
	var small := Ui.label("WORLD %d" % (map_world + 1), 16, w["color"], 6)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titles.add_child(small)
	var big := Ui.label(w["name"], 38, Ui.CREAM, 12)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titles.add_child(big)
	var next := Ui.button(">", go_next, 26, Vector2(64, 60))
	head.add_child(next)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	var focus: Button = null
	var want := map_world * 10
	if Levels.world_of(Game.level) == map_world and Game.level <= unlocked:
		want = Game.level
	elif Levels.world_of(unlocked) == map_world:
		want = unlocked
	for i in 10:
		var lv := map_world * 10 + i
		var stat := Game.level_stat(lv)
		var is_boss := Levels.is_boss(lv)
		var tile := Ui.button("BOSS" if is_boss else Levels.label(lv), _play.bind(lv), 22, Vector2(150, 96))
		tile.disabled = lv > unlocked
		if is_boss and not tile.disabled:
			tile.add_theme_stylebox_override("normal", Ui.box(Color(0.45, 0.1, 0.2, 0.95), Ui.GOLD))
		elif stat["done"]:
			tile.add_theme_stylebox_override("normal", Ui.box(Color(0.14, 0.3, 0.3, 0.95), Ui.CREAM))
		tile.focus_entered.connect(_describe.bind(lv))
		# rank and gems under the number
		if stat["done"]:
			var mark := ""
			if not is_boss:
				var mask: int = stat["gems"]
				mark = "%d/3  " % ((mask & 1) + ((mask >> 1) & 1) + ((mask >> 2) & 1))
			var tag := Ui.label(mark + str(stat["rank"]), 12, Ui.GOLD if stat["rank"] == "S" else Ui.CREAM, 4)
			tag.anchor_right = 1.0
			tag.anchor_top = 1.0
			tag.anchor_bottom = 1.0
			tag.offset_top = -26
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(tag)
		grid.add_child(tile)
		if lv == want and not tile.disabled:
			focus = tile
	info_label = Ui.label("", 16, Ui.CREAM, 6)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.custom_minimum_size = Vector2(0, 52)
	box.add_child(info_label)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(foot)
	foot.add_child(Ui.button("BACK", show_story, 20, Vector2(220, 50)))
	_finish(grid, focus if focus != null else prev)
	if focus == null:
		info_label.text = "BEAT WORLD %d TO OPEN THIS WORLD" % map_world


func _describe(lv: int) -> void:
	if info_label == null or not is_instance_valid(info_label):
		return
	var stat := Game.level_stat(lv)
	var text: String = "%s  %s" % [Levels.label(lv), Levels.LEVELS[lv]["name"]]
	if stat["done"]:
		var s: float = stat["time"]
		text += "\nBEST %d:%04.1f   RANK %s" % [int(s) / 60, fmod(s, 60.0), stat["rank"]]
	else:
		text += "\nNOT CLEARED YET"
	info_label.text = text


func show_options() -> void:
	var box := _begin("options", show_main)
	box.add_theme_constant_override("separation", 8)
	var touch_names := ["AUTO", "ON", "OFF"]
	var refs := {}
	refs["touch"] = _opt("TOUCH CONTROLS: %s" % touch_names[Game.setting("touch")], func() -> void:
		Game.set_setting("touch", (int(Game.setting("touch")) + 1) % 3)
		refs["touch"].text = "TOUCH CONTROLS: %s" % touch_names[Game.setting("touch")])
	box.add_child(refs["touch"])
	refs["music"] = _opt("MUSIC: %d" % Game.setting("music"), func() -> void:
		Game.set_setting("music", (int(Game.setting("music")) + 1) % 11)
		refs["music"].text = "MUSIC: %d" % Game.setting("music"))
	box.add_child(refs["music"])
	refs["sfx"] = _opt("SOUND: %d" % Game.setting("sfx"), func() -> void:
		Game.set_setting("sfx", (int(Game.setting("sfx")) + 1) % 11)
		refs["sfx"].text = "SOUND: %d" % Game.setting("sfx")
		Game.sfx("coin"))
	box.add_child(refs["sfx"])
	refs["shake"] = _opt("SCREEN SHAKE: %s" % ("ON" if Game.setting("shake") else "OFF"), func() -> void:
		Game.set_setting("shake", not Game.setting("shake"))
		refs["shake"].text = "SCREEN SHAKE: %s" % ("ON" if Game.setting("shake") else "OFF"))
	box.add_child(refs["shake"])
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		refs["full"] = _opt("FULLSCREEN: %s" % ("ON" if Game.setting("fullscreen") else "OFF"), func() -> void:
			Game.set_setting("fullscreen", not Game.setting("fullscreen"))
			refs["full"].text = "FULLSCREEN: %s" % ("ON" if Game.setting("fullscreen") else "OFF"))
		box.add_child(refs["full"])
	refs["erase"] = _opt("ERASE SAVE", func() -> void:
		if not erase_armed:
			erase_armed = true
			refs["erase"].text = "PRESS AGAIN TO ERASE!"
		else:
			Game.erase_save()
			erase_armed = false
			refs["erase"].text = "SAVE ERASED")
	box.add_child(refs["erase"])
	box.add_child(_opt("BACK", show_main))
	_finish(box)


func _opt(text: String, action: Callable) -> Button:
	return Ui.button(text, action, 16, Vector2(400, 0), 5)


# ---------------------------------------------------------------- bear shop

var preview_skin := ""
var preview_hat := ""


func show_shop() -> void:
	var box := _begin("shop", _leave_shop, false)
	box.add_theme_constant_override("separation", 10)
	shop_buttons = {}
	preview_skin = Game.equipped("skin")
	preview_hat = Game.equipped("hat")

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 40)
	box.add_child(head)
	head.add_child(Ui.label("BEAR SHOP", 36, Ui.CREAM, 12))
	shop_coins = Ui.label("", 22, Ui.GOLD, 8)
	head.add_child(shop_coins)

	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 24)
	box.add_child(body)

	# the bear trying things on
	var stage := Ui.panel(Color(0.11, 0.09, 0.2, 0.85), Ui.CREAM)
	body.add_child(stage)
	var spot := Control.new()
	spot.custom_minimum_size = Vector2(230, 300)
	stage.add_child(spot)
	var floor_line := ColorRect.new()
	floor_line.color = Color(0.36, 0.75, 0.4)
	floor_line.position = Vector2(10, 262)
	floor_line.size = Vector2(210, 8)
	spot.add_child(floor_line)
	shop_bear = Sprite2D.new()
	shop_bear.texture = WALK
	shop_bear.hframes = 4
	shop_bear.centered = false
	shop_bear.offset = Vector2(-16.5, -32)
	shop_bear.scale = Vector2(7, 7)
	shop_bear.position = Vector2(115, 262)
	spot.add_child(shop_bear)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	var first: Button = null
	for section in [["FUR", Skins.SKINS], ["HATS", Skins.HATS]]:
		right.add_child(Ui.label(section[0], 16, Ui.GOLD, 6))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		right.add_child(grid)
		for it: Dictionary in section[1]:
			var id: String = it["id"]
			var b := Ui.button(it["name"], _shop_press.bind(id), 14, Vector2(200, 0), 7)
			b.focus_entered.connect(_shop_try.bind(id))
			grid.add_child(b)
			shop_buttons[id] = b
			if id == preview_skin:
				first = b

	shop_info = Ui.label("", 16, Ui.CREAM, 6)
	shop_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_info.custom_minimum_size = Vector2(0, 26)
	box.add_child(shop_info)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(foot)
	foot.add_child(Ui.button("BACK", _leave_shop, 18, Vector2(220, 0), 8))
	_shop_refresh()
	_shop_try(preview_skin)
	_finish(box, first)


func _leave_shop() -> void:
	Skins.dress(bunty)
	wallet_label.text = "COINS %d" % Game.wallet()
	show_main()


func _shop_refresh() -> void:
	shop_coins.text = "COINS: %d" % Game.wallet()
	for id: String in shop_buttons:
		var it := Skins.item(id)
		var b: Button = shop_buttons[id]
		var slot := "hat" if Skins.is_hat(id) else "skin"
		if Game.equipped(slot) == id:
			b.text = "> %s <" % it["name"]
			b.add_theme_stylebox_override("normal", _shop_box(Color(0.14, 0.32, 0.3, 0.95), Ui.GOLD))
		elif Game.owns(id):
			b.text = it["name"]
			b.add_theme_stylebox_override("normal", _shop_box(Color(0.16, 0.14, 0.3, 0.95), Ui.CREAM))
		else:
			b.text = "%s  %d" % [it["name"], it["price"]]
			b.add_theme_stylebox_override("normal", _shop_box(Color(0.1, 0.09, 0.18, 0.95), Color(0.55, 0.5, 0.65)))


func _shop_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := Ui.box(bg, border)
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s


## Focus on an item: the bear tries it on.
func _shop_try(id: String) -> void:
	if shop_bear == null or not is_instance_valid(shop_bear):
		return
	var it := Skins.item(id)
	if Skins.is_hat(id):
		preview_hat = id
	else:
		preview_skin = id
	Skins.dress(shop_bear, preview_skin, preview_hat)
	var slot := "hat" if Skins.is_hat(id) else "skin"
	if Game.equipped(slot) == id:
		shop_info.text = "%s  -  WEARING IT" % it["name"]
	elif Game.owns(id):
		shop_info.text = "%s  -  PRESS TO WEAR" % it["name"]
	elif Game.wallet() >= it["price"]:
		shop_info.text = "%s  -  BUY FOR %d COINS" % [it["name"], it["price"]]
	else:
		shop_info.text = "%s  -  %d COINS  (NEED %d MORE)" % [it["name"], it["price"], it["price"] - Game.wallet()]


func _shop_press(id: String) -> void:
	var it := Skins.item(id)
	var slot := "hat" if Skins.is_hat(id) else "skin"
	var b: Button = shop_buttons[id]
	if not Game.owns(id):
		if not Game.buy(id, it["price"]):
			Game.sfx("hurt", 1.4, 0.5)
			var tw := b.create_tween()
			for i in 4:
				tw.tween_property(b, "position:x", b.position.x + (6.0 if i % 2 == 0 else -6.0), 0.04)
			tw.tween_property(b, "position:x", b.position.x, 0.04)
			_shop_try(id)
			return
		Game.sfx("powerup", 1.2, 0.7)
		var at := b.global_position + b.size / 2.0
		Fx.burst(fx_layer, at, 16, Ui.GOLD, 200.0, Vector2.UP, 180.0, 400.0, 5.0, 0.6)
	else:
		Game.sfx("coin", 1.2)
	Game.equip(slot, id)
	Ui.pop(b, 1.25, 0.2)
	shop_bear.scale = Vector2(9, 5)
	shop_bear.create_tween().tween_property(shop_bear, "scale", Vector2(7, 7), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_shop_refresh()
	_shop_try(id)

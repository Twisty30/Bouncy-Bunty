extends CanvasLayer
## Everything drawn over the level: hearts, coins, gems, timer, boss bar, messages,
## the coach banner, the VS splash, the pause menu and the results screen.

const Cast := preload("res://cast.gd")
const Ui := preload("res://ui.gd")
const FxData := preload("res://fx_data.gd")
const TILES := preload("res://kenney_pixel-platformer/Tilemap/tilemap_packed.png")
const Powers := preload("res://powers.gd")
const PixelArt := preload("res://pixel_art.gd")

var level: Node
var root := Control.new()
var heart_rows: Array = []      # per player: Array of TextureRect
var coin_label: Label
var time_label: Label
var gem_icons: Array = []
var name_label: Label
var message_label: Label
var flash_rect := ColorRect.new()
var bar_top := ColorRect.new()
var bar_bottom := ColorRect.new()
var boss_box: Control
var boss_fill: ColorRect
var boss_ghost: ColorRect
var boss_name: Label
var boss_frac := 1.0
var coach_panel: PanelContainer
var coach_label: Label
var pause_panel: Control
var fx_holder := Node2D.new()     # effects drawn BEHIND the HUD text and menus
var fx_front := Node2D.new()      # the few that belong on top (a heart breaking on the HUD)
var power_row: HBoxContainer
var power_key := ""
var message_id := 0


func tile(idx: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = TILES
	a.region = Rect2(idx % 20 * 18, idx / 20 * 18, 18, 18)
	return a


func setup(lv: Node) -> void:
	level = lv
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	fx_holder.z_index = -10
	add_child(fx_holder)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# cinematic bars
	for b: ColorRect in [bar_top, bar_bottom]:
		b.color = Color(0.05, 0.04, 0.1)
		b.anchor_right = 1.0
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(b)
	bar_top.offset_bottom = 0
	bar_bottom.anchor_top = 1.0
	bar_bottom.anchor_bottom = 1.0
	bar_bottom.offset_top = 0

	# top left: hearts (one row per player), coins, gems
	var left := VBoxContainer.new()
	left.position = Vector2(18, 12)
	left.add_theme_constant_override("separation", 4)
	root.add_child(left)
	for i in level.players.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		if level.players.size() > 1:
			var tag := Ui.label("P%d" % (i + 1), 14, Game.TINTS[i].clamp())
			row.add_child(tag)
		var hearts: Array = []
		for h in level.players[i].MAX_HP:
			var tr := TextureRect.new()
			tr.texture = tile(44)
			tr.custom_minimum_size = Vector2(36, 36)
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			row.add_child(tr)
			hearts.append(tr)
		heart_rows.append(hearts)
		left.add_child(row)
	var counts := HBoxContainer.new()
	counts.add_theme_constant_override("separation", 6)
	left.add_child(counts)
	var coin := TextureRect.new()
	coin.texture = tile(151)
	coin.custom_minimum_size = Vector2(32, 32)
	coin.stretch_mode = TextureRect.STRETCH_SCALE
	counts.add_child(coin)
	coin_label = Ui.label("0", 20, Ui.GOLD)
	counts.add_child(coin_label)
	if level.uses_gems:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(14, 0)
		counts.add_child(gap)
		for g in 3:
			var icon := TextureRect.new()
			var d: Array = FxData.DATA["gem"]
			var a := AtlasTexture.new()
			a.atlas = Fx.tex("gem")
			a.region = Rect2(0, 0, d[3], d[4] - 8)
			icon.texture = a
			icon.custom_minimum_size = Vector2(34, 32)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.modulate = Color(0.2, 0.2, 0.3, 0.8)
			counts.add_child(icon)
			gem_icons.append(icon)
	# active power-ups: icon + seconds left
	power_row = HBoxContainer.new()
	power_row.add_theme_constant_override("separation", 10)
	left.add_child(power_row)

	# top centre: timer
	time_label = Ui.label("0.0", 24, Ui.CREAM)
	time_label.anchor_left = 0.5
	time_label.anchor_right = 0.5
	time_label.offset_left = -200
	time_label.offset_right = 200
	time_label.offset_top = 10
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(time_label)

	# top right: level name (kept clear of the touch pause button)
	name_label = Ui.label("", 14, Ui.CREAM)
	name_label.anchor_left = 1.0
	name_label.anchor_right = 1.0
	name_label.offset_left = -520
	name_label.offset_right = -96
	name_label.offset_top = 14
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(name_label)

	message_label = Ui.label("", 34, Ui.CREAM, 10)
	message_label.anchor_right = 1.0
	message_label.offset_top = 150
	message_label.offset_bottom = 260
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(message_label)

	# boss health bar
	boss_box = Control.new()
	boss_box.anchor_left = 0.5
	boss_box.anchor_right = 0.5
	boss_box.offset_left = -270
	boss_box.offset_right = 270
	boss_box.offset_top = 52
	boss_box.offset_bottom = 110
	boss_box.visible = false
	root.add_child(boss_box)
	boss_name = Ui.label("", 16, Ui.GOLD)
	boss_name.size = Vector2(540, 22)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	var back := Panel.new()
	back.add_theme_stylebox_override("panel", Ui.box(Color(0.1, 0.08, 0.18), Ui.CREAM, 4, 4))
	back.position = Vector2(0, 26)
	back.size = Vector2(540, 26)
	boss_box.add_child(back)
	boss_ghost = ColorRect.new()
	boss_ghost.color = Color(1, 1, 1)
	boss_ghost.position = Vector2(6, 32)
	boss_ghost.size = Vector2(528, 14)
	boss_box.add_child(boss_ghost)
	boss_fill = ColorRect.new()
	boss_fill.color = Color(0.95, 0.25, 0.35)
	boss_fill.position = Vector2(6, 32)
	boss_fill.size = Vector2(528, 14)
	boss_box.add_child(boss_fill)

	# coach banner (bootcamp)
	coach_panel = Ui.panel(Color(0.09, 0.07, 0.18, 0.92), Ui.PINK)
	coach_panel.anchor_left = 0.5
	coach_panel.anchor_right = 0.5
	coach_panel.offset_left = -430
	coach_panel.offset_right = 430
	coach_panel.offset_top = 64
	coach_panel.visible = false
	coach_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(coach_panel)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 14)
	coach_panel.add_child(crow)
	var face := Control.new()
	face.custom_minimum_size = Vector2(64, 60)
	crow.add_child(face)
	var miss := Cast.actor("MISS BEAR", 2.6)
	miss.position = Vector2(32, 62)
	face.add_child(miss)
	coach_label = Ui.label("", 16, Ui.CREAM, 0)
	coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	coach_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coach_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coach_label.add_theme_constant_override("line_spacing", 6)
	crow.add_child(coach_label)

	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)
	add_child(fx_front)
	update_hearts()


func view() -> Vector2:
	return get_viewport().get_visible_rect().size


# ---------------------------------------------------------------- counters

func update_hearts() -> void:
	for i in heart_rows.size():
		var hp: int = level.players[i].hp
		for h in heart_rows[i].size():
			heart_rows[i][h].texture = tile(44 if h < hp else 46)


## A heart breaks on the HUD.
func heart_lost(player_index: int) -> void:
	update_hearts()
	var hp: int = level.players[player_index].hp
	if hp < 0 or hp >= heart_rows[player_index].size():
		return
	var tr: TextureRect = heart_rows[player_index][hp]
	Fx.play(fx_front, "heart_lost", tr.global_position + Vector2(18, 18), {"scale": 2.0, "real_time": true})
	flash(Color(1, 0.1, 0.1, 0.22))


func set_counts(coins: int, time_text: String) -> void:
	if coin_label.text != str(coins):
		coin_label.text = str(coins)
		Ui.pop(coin_label, 1.4, 0.15)
	time_label.text = time_text


## powers: [[kind, text]] from the level. Rebuilds the row only when the set changes.
func set_powers(powers: Array) -> void:
	var key := ""
	for pw in powers:
		key += pw[0] + ","
	if key != power_key:
		var was := power_key
		power_key = key
		for c in power_row.get_children():
			power_row.remove_child(c)
			c.queue_free()
		for pw in powers:
			var item := HBoxContainer.new()
			item.add_theme_constant_override("separation", 4)
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(26, 26)
			var icon: Node2D = PixelArt.make(Powers.POWERS[pw[0]]["art"])
			icon.scale = Vector2(3, 3)
			icon.position = Vector2(1, 1)
			holder.add_child(icon)
			item.add_child(holder)
			item.add_child(Ui.label("", 16, Ui.CREAM, 6))
			power_row.add_child(item)
			if not was.contains(pw[0] + ","):
				Ui.pop.call_deferred(item, 2.0, 0.3)
	for i in powers.size():
		var item: Node = power_row.get_child(i)
		var l: Label = item.get_child(1)
		var text: String = powers[i][1]
		if l.text != text:
			l.text = text
			# the last 3 seconds turn red
			var warn: bool = text.is_valid_int() and int(text) <= 3
			l.add_theme_color_override("font_color", Color(1, 0.45, 0.45) if warn else Ui.CREAM)


func set_gems(mask: int) -> void:
	for g in gem_icons.size():
		var got := (mask >> g) & 1 == 1
		var icon: TextureRect = gem_icons[g]
		if got and icon.modulate != Color.WHITE:
			icon.modulate = Color.WHITE
			Ui.pop(icon, 2.5, 0.35)


func message(text: String, seconds: float) -> void:
	message_id += 1
	var id := message_id
	message_label.text = text
	Ui.pop(message_label, 1.6, 0.25)
	await get_tree().create_timer(seconds, true, false, true).timeout
	if id == message_id:
		var tw := message_label.create_tween()
		tw.tween_property(message_label, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func() -> void:
			if id == message_id:
				message_label.text = "")


func flash(color: Color, time: float = 0.3) -> void:
	flash_rect.color = color
	var tw := flash_rect.create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, time)


func bars(on: bool) -> void:
	var h := 64.0 if on else 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(bar_top, "offset_bottom", h, 0.3)
	tw.tween_property(bar_bottom, "offset_top", -h, 0.3)


func coach(text: String) -> void:
	coach_panel.visible = true
	coach_label.text = text
	coach_panel.pivot_offset = coach_panel.size / 2
	coach_panel.scale = Vector2(1.0, 0.0)
	var tw := coach_panel.create_tween()
	tw.tween_property(coach_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Game.sfx("menu_select", 1.3)


## Level name sliding in at the start.
func title_card(big: String, title: String, sub: String, color: Color) -> void:
	name_label.text = "%s  %s" % [big, title] if big != "" else title
	var box := VBoxContainer.new()
	box.anchor_right = 1.0
	box.offset_top = 170
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var l1 := Ui.label(sub, 18, color, 8)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l1)
	var l2 := Ui.label(("%s  %s" % [big, title]) if big != "" else title, 40, Ui.CREAM, 12)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l2)
	box.position.x = -view().x
	var tw := box.create_tween()
	tw.tween_property(box, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.5)
	tw.tween_property(box, "position:x", view().x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(box.queue_free)


# ---------------------------------------------------------------- bosses

func boss_bar(title: String) -> void:
	boss_name.text = title
	boss_box.visible = true
	boss_frac = 1.0
	boss_fill.size.x = 0.0
	boss_ghost.size.x = 0.0
	var tw := create_tween()
	tw.tween_property(boss_fill, "size:x", 528.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: boss_ghost.size.x = 528.0)
	Ui.pop(boss_name, 1.8, 0.3)


func boss_set(frac: float) -> void:
	boss_frac = clampf(frac, 0.0, 1.0)
	boss_fill.size.x = 528.0 * boss_frac
	# the bar jolts when the boss is hit
	var tw := create_tween()
	tw.tween_property(boss_box, "offset_top", 60.0, 0.04)
	tw.tween_property(boss_box, "offset_top", 47.0, 0.04)
	tw.tween_property(boss_box, "offset_top", 52.0, 0.04)
	tw.tween_interval(0.25)
	tw.tween_property(boss_ghost, "size:x", 528.0 * boss_frac, 0.3)


func boss_hide() -> void:
	var tw := create_tween()
	tw.tween_property(boss_box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		boss_box.visible = false
		boss_box.modulate.a = 1.0)


## Fighting-game splash: BUNTY vs the boss. Await it.
func versus(who: String, title: String, sub: String) -> void:
	var v := view()
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.1, 0.0)
	holder.add_child(dim)
	var band := ColorRect.new()
	band.color = Cast.color(who)
	band.size = Vector2(v.x, 190)
	band.position = Vector2(-v.x, v.y / 2.0 - 95)
	holder.add_child(band)
	var band2 := ColorRect.new()
	band2.color = Color(0.09, 0.07, 0.18)
	band2.size = Vector2(v.x, 170)
	band2.position = Vector2(v.x, v.y / 2.0 - 85)
	holder.add_child(band2)
	var left := Cast.actor("BUNTY", 7.0)
	left.position = Vector2(-200, v.y / 2.0 + 80)
	holder.add_child(left)
	var right := Cast.actor(who, 8.0)
	right.position = Vector2(v.x + 240, v.y / 2.0 + 84)
	right.get_node("spr").flip_h = Cast.CAST[who].get("bear", false)
	holder.add_child(right)
	var vs := Ui.label("VS", 64, Ui.GOLD, 16)
	vs.size = Vector2(v.x, 100)
	vs.position = Vector2(0, v.y / 2.0 - 50)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.modulate.a = 0.0
	holder.add_child(vs)
	var name1 := Ui.label(title, 34, Ui.CREAM, 12)
	name1.size = Vector2(v.x, 50)
	name1.position = Vector2(0, v.y / 2.0 + 104)
	name1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name1.modulate.a = 0.0
	holder.add_child(name1)
	var name2 := Ui.label(sub, 16, Cast.color(who), 8)
	name2.size = Vector2(v.x, 30)
	name2.position = Vector2(0, v.y / 2.0 + 162)
	name2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name2.modulate.a = 0.0
	holder.add_child(name2)

	Game.sfx("whoosh", 0.8)
	var tw := holder.create_tween().set_parallel()
	tw.tween_property(dim, "color:a", 0.55, 0.2)
	tw.tween_property(band, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(band2, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(left, "position:x", v.x * 0.24, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)
	tw.tween_property(right, "position:x", v.x * 0.76, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)
	await get_tree().create_timer(0.45).timeout
	Fx.play(fx_holder, "impact_frame", v / 2.0, {"scale": maxf(v.x / 320.0, v.y / 180.0), "alpha": 0.9, "real_time": true})
	Fx.play(fx_holder, "crit", v / 2.0 + Vector2(0, 40), {"scale": 4.0, "real_time": true})
	Game.sfx("boss_hit", 0.7)
	Game.sfx("roar", 1.0, 0.8)
	Ui.pop(vs, 3.0, 0.25)
	Ui.pop(name1, 1.6, 0.3)
	Ui.pop(name2, 1.6, 0.3)
	level.shake(8.0)
	await get_tree().create_timer(1.7).timeout
	var out := holder.create_tween().set_parallel()
	out.tween_property(band, "position:x", v.x, 0.2)
	out.tween_property(band2, "position:x", -v.x, 0.2)
	out.tween_property(left, "position:x", -300.0, 0.2)
	out.tween_property(right, "position:x", v.x + 300.0, 0.2)
	out.tween_property(holder, "modulate:a", 0.0, 0.25)
	await out.finished
	holder.queue_free()


## One of the pixelfx ribbon banners ("banner_clear", "banner_boss", "banner_record").
func banner(fx: String, y: float = 150.0) -> void:
	Fx.play(fx_holder, fx, Vector2(view().x / 2.0, y), {"scale": 4.0, "real_time": true, "speed": 0.85})


func party() -> void:
	var v := view()
	Fx.side_confetti(fx_holder, Vector2(20, v.y + 10), -1)
	Fx.side_confetti(fx_holder, Vector2(v.x - 20, v.y + 10), 1)
	for i in 4:
		# left and right of the screen, so they don't sit on the results panel
		var fx_x := randf_range(0.06, 0.22) if i % 2 == 0 else randf_range(0.78, 0.94)
		get_tree().create_timer(0.3 + i * 0.35).timeout.connect(func() -> void:
			Fx.play(fx_holder, "firework", Vector2(fx_x * v.x, randf_range(0.2, 0.45) * v.y),
				{"scale": 2.0, "real_time": true, "tint": Color.from_hsv(randf(), 0.35, 1.0)})
			Game.sfx("explosion", randf_range(1.3, 1.7), 0.35))


# ---------------------------------------------------------------- results and pause

## data: title, rows [[label, value]], gems (mask, or -1 for none), rank ("" for none),
## note (extra line), buttons [[text, Callable]].
func results(data: Dictionary) -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.1, 0.0)
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.6, 0.3)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := Ui.panel()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var title := Ui.label(data["title"], 30, Ui.GOLD, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var rows: Array = []
	for r in data["rows"]:
		var row := HBoxContainer.new()
		var a := Ui.label(r[0], 20, Ui.CREAM, 0)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(a)
		row.add_child(Ui.label(str(r[1]), 20, Ui.GOLD, 0))
		row.modulate.a = 0.0
		col.add_child(row)
		rows.append(row)
	var gem_row: HBoxContainer = null
	if data.get("gems", -1) >= 0:
		gem_row = HBoxContainer.new()
		gem_row.alignment = BoxContainer.ALIGNMENT_CENTER
		gem_row.add_theme_constant_override("separation", 22)
		gem_row.custom_minimum_size = Vector2(0, 70)
		col.add_child(gem_row)
	var rank_label: Label = null
	if data.get("rank", "") != "":
		rank_label = Ui.label("RANK  %s" % data["rank"], 44,
			{"S": Ui.GOLD, "A": Color(0.5, 1.0, 0.6), "B": Ui.SKY, "C": Ui.CREAM}[data["rank"]], 12)
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_label.modulate.a = 0.0
		col.add_child(rank_label)
	var note: Label = null
	if data.get("note", "") != "":
		note = Ui.label(data["note"], 18, Ui.PINK, 6)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.modulate.a = 0.0
		col.add_child(note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	buttons.modulate.a = 0.0
	col.add_child(buttons)
	var first: Button = null
	for b in data["buttons"]:
		var btn := Ui.button(b[0], b[1], 18, Vector2(170, 52))
		btn.disabled = true
		buttons.add_child(btn)
		if first == null:
			first = btn
	Ui.pop(panel, 0.6, 0.3)

	var wait := func(s: float) -> Signal:
		return get_tree().create_timer(s).timeout
	await wait.call(0.35)
	for row in rows:
		row.modulate.a = 1.0
		Ui.pop(row, 1.3, 0.15)
		Game.sfx("tick", 1.2)
		await wait.call(0.22)
	if gem_row != null:
		var mask: int = data["gems"]
		for g in 3:
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(64, 64)
			gem_row.add_child(holder)
			if (mask >> g) & 1 == 1:
				Fx.play(holder, "gem", Vector2(32, 60), {"scale": 1.5, "real_time": true})
				Fx.play(holder, "collect", Vector2(32, 44), {"scale": 1.0, "real_time": true})
				Game.sfx("gem", 1.0 + g * 0.12)
			else:
				var dot := Ui.label("-", 30, Color(0.4, 0.4, 0.5), 0)
				dot.size = Vector2(64, 64)
				dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				holder.add_child(dot)
				Game.sfx("tick", 0.7)
			await wait.call(0.3)
	if rank_label != null:
		await wait.call(0.15)
		Ui.pop(rank_label, 4.0, 0.3)
		Game.sfx("boss_hit", 1.3)
		level.shake(6.0)
		flash(Color(1, 1, 1, 0.3))
		Fx.play(fx_holder, "crit", view() / 2.0 + Vector2(0, 60), {"scale": 3.0, "real_time": true, "alpha": 0.8})
		await wait.call(0.4)
	if note != null:
		Ui.pop(note, 1.6, 0.25)
		Game.sfx("powerup")
		await wait.call(0.3)
	buttons.modulate.a = 1.0
	for b in buttons.get_children():
		b.disabled = false
	Game.quiet_until = Time.get_ticks_msec() + 200
	if first != null:
		first.grab_focus()


func pause(on: bool, exit_label: String) -> void:
	if pause_panel != null:
		pause_panel.queue_free()
		pause_panel = null
	if not on:
		return
	pause_panel = Control.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(pause_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.1, 0.65)
	pause_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(center)
	var panel := Ui.panel()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var title := Ui.label("PAUSED", 32, Ui.GOLD, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var resume := Ui.button("RESUME", level.toggle_pause)
	col.add_child(resume)
	col.add_child(Ui.button("RESTART", func() -> void: Game.restart_level()))
	var touch_names := ["AUTO", "ON", "OFF"]
	var holder := []   # lambdas copy locals, so the button reaches itself through this
	var touch_btn := Ui.button("TOUCH: %s" % touch_names[Game.setting("touch")], func() -> void:
		Game.set_setting("touch", (int(Game.setting("touch")) + 1) % 3)
		holder[0].text = "TOUCH: %s" % touch_names[Game.setting("touch")])
	holder.append(touch_btn)
	col.add_child(touch_btn)
	col.add_child(Ui.button(exit_label, level.exit_level))
	Ui.pop(panel, 0.7, 0.2)
	Game.quiet_until = Time.get_ticks_msec() + 200
	resume.grab_focus.call_deferred()

extends Control
## The first thing you see: a loading bar (it really is loading the effect sheets), then the
## logo crashes in, and any button takes you to the menu.

const Ui := preload("res://ui.gd")
const BackdropScript := preload("res://backdrop.gd")
const WALK := preload("res://little-bear-walk.png")
const Skins := preload("res://skins.gd")
## The title and text draw above every effect (effects use z 4-5).
const UI_Z := 20

## Effects used all the time: loaded up front so the first hit in a level never stutters.
const CORE := ["t_pixel", "t_diamond", "t_iris", "t_star", "t_slash", "claw", "uppercut", "xslash", "hit", "crit",
	"thud", "landing", "pow", "poof", "respawn", "collect", "gem", "heart", "star", "portal", "rune", "sunburst",
	"levelup", "confetti", "firework", "banner_clear", "heart_lost", "impact_frame", "butterfly", "slam"]
const TIPS := ["TAP CLAW THREE TIMES FOR A COMBO FINISHER.", "GROUND POUNDS HIT HARDEST. JUMP, THEN DOWN!",
	"JUMP AT A WALL, THEN JUMP AGAIN TO KICK OFF IT.", "DASHING THROUGH A BADDIE HURTS IT, NOT YOU.",
	"EVERY LEVEL HIDES 3 GEMS.", "DRILLS HAVE SPIKY HATS. DO NOT STOMP THEM!", "A DIZZY BOSS TAKES EXTRA DAMAGE."]

var black := ColorRect.new()
var fx_layer := Node2D.new()
var bar_fill := ColorRect.new()
var runner := Sprite2D.new()
var load_box := Control.new()
var backdrop: Node
var t := 0.0
var ready_for_input := false
var leaving := false
var press_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop = BackdropScript.new()
	backdrop.horizon = 0.5
	add_child(backdrop)
	backdrop.set_theme("grass")
	backdrop.weather_layer.layer = -4
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0.07, 0.05, 0.13)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	add_child(fx_layer)

	load_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	load_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	load_box.z_index = UI_Z
	add_child(load_box)
	var v := get_viewport_rect().size
	var title := Ui.label("LOADING", 22, Ui.CREAM, 8)
	title.size = Vector2(v.x, 30)
	title.position = Vector2(0, v.y / 2.0 - 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_box.add_child(title)
	var back := Panel.new()
	back.add_theme_stylebox_override("panel", Ui.box(Color(0.12, 0.1, 0.22), Ui.CREAM, 4, 4))
	back.position = Vector2(v.x / 2.0 - 250, v.y / 2.0 + 40)
	back.size = Vector2(500, 30)
	load_box.add_child(back)
	bar_fill.color = Ui.GOLD
	bar_fill.position = back.position + Vector2(6, 6)
	bar_fill.size = Vector2(0, 18)
	load_box.add_child(bar_fill)
	runner.texture = WALK
	runner.hframes = 4
	runner.centered = false
	runner.offset = Vector2(-16.5, -32)
	runner.scale = Vector2(2, 2)
	Skins.dress(runner)
	runner.position = back.position + Vector2(0, -2)
	load_box.add_child(runner)
	var tip := Ui.label(TIPS.pick_random(), 12, Color(0.8, 0.8, 0.95), 4)
	tip.size = Vector2(v.x, 20)
	tip.position = Vector2(0, v.y / 2.0 + 96)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_box.add_child(tip)
	_run()


func _process(delta: float) -> void:
	t += delta
	backdrop.scroll(t * 30.0, 252.0, delta)
	runner.frame = int(t * 12.0) % 4
	if press_label != null:
		press_label.modulate.a = 0.55 + 0.45 * sin(t * 5.0)


func _input(event: InputEvent) -> void:
	if not ready_for_input or leaving:
		return
	var go := false
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch:
		go = event.is_pressed()
	if go:
		leaving = true
		Game.sfx("menu_select")
		Game.go("res://menu.tscn", "t_star")


func _run() -> void:
	var v := get_viewport_rect().size
	# 1. load the effect sheets, a couple per frame, with a real progress bar
	var started := Time.get_ticks_msec()
	for i in CORE.size():
		Fx.tex(CORE[i])
		var k := (i + 1) / float(CORE.size())
		bar_fill.size.x = 488.0 * k
		runner.position.x = bar_fill.position.x + 488.0 * k
		if i % 2 == 1:
			await get_tree().process_frame
			if not is_inside_tree():
				return
	while Time.get_ticks_msec() - started < 900:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	Game.sfx("checkpoint", 1.2, 0.6)
	Fx.play(fx_layer, "collect", runner.position + Vector2(0, -10), {"scale": 2.0})
	await get_tree().create_timer(0.35).timeout
	load_box.visible = false

	# 2. the dark screen shatters into pixels and the hills appear
	Fx.play(fx_layer, "mana_burst", v / 2.0 + Vector2(0, 60), {"scale": 4.0})
	Game.sfx("whoosh", 0.8)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 0.0, 0.5)
	await get_tree().create_timer(0.45).timeout
	Game.music("title")

	# 3. BOUNCY BUNTY drops in letter by letter
	var glow := Fx.play(fx_layer, "sunburst", Vector2(v.x / 2.0, 250), {"scale": 6.0, "alpha": 0.0, "z": -1})
	glow.create_tween().tween_property(glow, "modulate:a", 0.7, 0.6)
	var word := "BOUNCY BUNTY"
	var size := 76
	var font: Font = Game.FONT
	var total := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := v.x / 2.0 - total / 2.0
	for i in word.length():
		var ch := word[i]
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if ch != " ":
			var l := Ui.label(ch, size, Ui.CREAM, 20)
			l.position = Vector2(x, -160)
			l.z_index = UI_Z
			add_child(l)
			var drop := l.create_tween()
			drop.tween_property(l, "position:y", 150.0, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			drop.tween_callback(Fx.burst.bind(self, Vector2(x + w / 2.0, 240), 6, Color(1, 0.96, 0.84), 120.0, Vector2.UP, 80.0, 400.0, 6.0, 0.4))
			Game.sfx("bounce", 0.9 + i * 0.04, 0.6)
			await get_tree().create_timer(0.07).timeout
		x += w
	await get_tree().create_timer(0.45).timeout

	# 4. REBOUND slams in with a claw slash
	var re := Ui.label("REBOUND", 64, Ui.GOLD, 20)
	re.size = Vector2(v.x, 90)
	re.position = Vector2(0, 258)
	re.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	re.z_index = UI_Z
	add_child(re)
	Ui.pop(re, 5.0, 0.22)
	re.rotation = -0.04
	Fx.play(fx_layer, "impact_frame", v / 2.0, {"scale": maxf(v.x / 320.0, v.y / 180.0), "alpha": 0.85})
	Fx.play(fx_layer, "xslash", Vector2(v.x / 2.0 - 230, 380), {"scale": 4.0})
	Fx.play(fx_layer, "crit", Vector2(v.x / 2.0, 330), {"scale": 3.5})
	Game.sfx("slash", 0.7)
	Game.sfx("boss_hit", 0.8)
	await get_tree().create_timer(0.5).timeout
	Fx.side_confetti(fx_layer, Vector2(20, v.y + 10), -1)
	Fx.side_confetti(fx_layer, Vector2(v.x - 20, v.y + 10), 1)
	# fireworks on the left and right only, clear of the title in the middle
	for i in 2:
		Fx.play(fx_layer, "firework", Vector2(v.x * (0.12 if i == 0 else 0.88), 170 + i * 50), {"scale": 2.2, "flip": i == 1})
		Game.sfx("explosion", 1.4 + i * 0.15, 0.35)
		await get_tree().create_timer(0.25).timeout

	press_label = Ui.label("PRESS ANY BUTTON", 24, Ui.CREAM, 8)
	press_label.size = Vector2(v.x, 40)
	press_label.position = Vector2(0, v.y - 150)
	press_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press_label.z_index = UI_Z
	add_child(press_label)
	Game.booted = true
	ready_for_input = true

extends Node
## Autoload "Game": controls, game modes, saving, sound, and scene changes that play a
## pixelfx screen transition.

enum Mode { TUTORIAL, TIME_TRIAL, STORY }

const FONT := preload("res://fonts/mario/mario_world_pixel.ttf")
const FxData := preload("res://fx_data.gd")
const Levels := preload("res://levels.gd")
const TouchScript := preload("res://touch.gd")
const TINTS := [Color(1, 1, 1), Color(0.95, 1.3, 1.9), Color(1.15, 1.65, 0.95)]
const SAVE_PATH := "user://rebound.cfg"
const LEVEL_COUNT := 50
## Frame on which each transition sheet covers the whole screen (that is when the scene swaps).
const HOLD := {"t_iris": 16, "t_star": 16, "t_diamond": 14, "t_pixel": 15, "t_slash": 11}

const HINTS := {
	"keys": {"move": "A / D OR THE ARROWS", "jump": "W OR SPACE", "crouch": "S OR DOWN", "dash": "Q OR CTRL",
		"attack": "F OR J", "interact": "E"},
	"pad": {"move": "THE LEFT STICK", "jump": "(A)", "crouch": "STICK DOWN", "dash": "(B)",
		"attack": "(X)", "interact": "(Y)"},
	"touch": {"move": "THE ARROW BUTTONS", "jump": "JUMP", "crouch": "THE DOWN BUTTON", "dash": "DASH",
		"attack": "CLAW", "interact": "USE"},
}

var mode: int = Mode.TUTORIAL
var player_schemes: Array = [[1, 2, 3]]   # one entry per bear; single player = every scheme
var level := 0                            # story level being played, 0..49
var cutscene := "intro"
var cutscene_then := Callable()
var menu_page := ""                       # which page the menu opens on next time
var booted := false

var save := ConfigFile.new()
var sounds := {}
var speakers: Array = []
var tracks := {}
var track := ""
var music_player := AudioStreamPlayer.new()
var quiet_until := 0       # no "move" blip for focus we grab ourselves
var last_device := "keys"

# screen transition
var trans_layer := CanvasLayer.new()
var trans := Sprite2D.new()
var trans_style := ""
var trans_t := 0.0
var trans_phase := 0       # 0 idle, 1 closing, 2 covered (scene swaps), 3 opening
var trans_frames := 0
var trans_action := Callable()

var stop_left := 0.0       # hit-stop time left (real seconds)
var last_us := 0
var touch: CanvasLayer
var pause_handler := Callable()   # the level's toggle_pause while a level is running


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	save.load(SAVE_PATH)
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 20
	ThemeDB.get_default_theme().merge_with(theme)

	for f in DirAccess.get_files_at("res://sfx"):
		if f.ends_with(".wav") or f.ends_with(".wav.import"):
			var n := f.get_basename().get_basename() if f.ends_with(".import") else f.get_basename()
			sounds[n] = load("res://sfx/%s.wav" % n)
	for i in 12:
		speakers.append(AudioStreamPlayer.new())
		add_child(speakers[i])
	for f in DirAccess.get_files_at("res://music"):
		if f.ends_with(".wav") or f.ends_with(".wav.import"):
			var n := f.get_basename().get_basename() if f.ends_with(".import") else f.get_basename()
			var stream: AudioStreamWAV = load("res://music/%s.wav" % n)
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
			tracks[n] = stream
	add_child(music_player)
	apply_settings()
	_setup_inputs()

	trans_layer.layer = 100
	add_child(trans_layer)
	trans.centered = false
	trans.visible = false
	trans_layer.add_child(trans)

	touch = TouchScript.new()
	add_child(touch)
	last_us = Time.get_ticks_usec()
	_debug_args()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf((now - last_us) / 1000000.0, 0.1)
	last_us = now
	if stop_left > 0.0:
		stop_left -= dt
		if stop_left <= 0.0:
			Engine.time_scale = 1.0
	if trans_phase == 0:
		return
	var d: Array = FxData.DATA[trans_style]
	var hold: int = HOLD[trans_style]
	var view := get_viewport().get_visible_rect().size
	var k := maxf(view.x / d[3], view.y / d[4])
	trans.scale = Vector2(k, k)
	trans.position = (view - Vector2(d[3], d[4]) * k) / 2.0
	match trans_phase:
		1:
			trans_t += dt * 1.6
			var f := int(trans_t * d[0])
			if f >= hold:
				f = hold
				trans_phase = 2
				trans_frames = 0
				Engine.time_scale = 1.0
				stop_left = 0.0
				get_tree().paused = false
				trans_action.call()
			trans.frame = f
		2:
			trans_frames += 1
			if trans_frames >= 4:
				trans_phase = 3
				trans_t = hold / float(d[0])
		3:
			trans_t += dt * 1.6
			var f := int(trans_t * d[0])
			if f >= d[2]:
				trans_phase = 0
				trans.visible = false
			else:
				trans.frame = f


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and pause_handler.is_valid() and trans_phase == 0:
		pause_handler.call()
	if event is InputEventKey:
		last_device = "keys"
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		last_device = "pad"


# ---------------------------------------------------------------- scene changes

func busy() -> bool:
	return trans_phase != 0


## Play a transition and run action while the screen is covered.
func swap(action: Callable, style: String = "") -> void:
	if trans_phase != 0:
		return
	if style == "":
		style = ["t_pixel", "t_diamond", "t_iris", "t_star"].pick_random()
	trans_style = style
	var d: Array = FxData.DATA[style]
	trans.texture = Fx.tex(style)
	trans.hframes = d[7]
	trans.vframes = ceili(d[2] / float(d[7]))
	trans.frame = 0
	trans.visible = true
	trans_t = 0.0
	trans_phase = 1
	trans_action = action
	sfx("whoosh", 1.0, 0.6)


func go(path: String, style: String = "") -> void:
	swap(func() -> void: get_tree().change_scene_to_file(path), style)


func goto_menu(page: String = "") -> void:
	menu_page = page
	go("res://menu.tscn", "t_diamond")


func start_tutorial() -> void:
	mode = Mode.TUTORIAL
	player_schemes = [[1, 2, 3]]
	go("res://level.tscn", "t_star")


func start_time_trial() -> void:
	mode = Mode.TIME_TRIAL
	player_schemes = [[1, 2, 3]]
	go("res://level.tscn", "t_slash")


func set_players(players: int) -> void:
	player_schemes = [[[1, 2, 3]], [[1], [2]], [[1], [2], [3]]][clampi(players, 1, 3) - 1]


## Start (or continue) the story at a level. Plays the story scenes the first time.
func start_story(lv: int) -> void:
	mode = Mode.STORY
	level = clampi(lv, 0, LEVEL_COUNT - 1)
	var scene := ""
	if level == 0:
		scene = "intro"
	elif level % 10 == 0:
		scene = "world%d" % (level / 10 + 1)
	if scene != "" and not seen(scene):
		mark_seen(scene)
		play_cutscene(scene, func() -> void: go("res://level.tscn", "t_iris"))
	else:
		go("res://level.tscn", "t_slash" if Levels.is_boss(level) else "t_iris")


func play_cutscene(which: String, then: Callable) -> void:
	cutscene = which
	cutscene_then = then
	go("res://cutscene.tscn", "t_pixel")


func cutscene_done() -> void:
	if cutscene_then.is_valid():
		var c := cutscene_then
		cutscene_then = Callable()
		c.call()
	else:
		goto_menu()


## Called by the level when the player leaves the results screen with "next".
func next_level() -> void:
	if mode != Mode.STORY:
		goto_menu()
	elif level >= LEVEL_COUNT - 1:
		play_cutscene("ending", func() -> void: goto_menu())
	else:
		start_story(level + 1)


func restart_level() -> void:
	go("res://level.tscn", "t_pixel")


# ---------------------------------------------------------------- saving

func unlocked() -> int:
	return clampi(save.get_value("story", "unlocked", 0), 0, LEVEL_COUNT - 1)


func story_finished() -> bool:
	return save.get_value("story", "finished", false)


func level_stat(lv: int) -> Dictionary:
	return {
		"done": save.get_value("levels", "done%d" % lv, false),
		"time": save.get_value("levels", "time%d" % lv, 0.0),
		"gems": save.get_value("levels", "gems%d" % lv, 0),      # bit mask of the 3 gems
		"rank": save.get_value("levels", "rank%d" % lv, ""),
	}


func total_gems() -> int:
	var n := 0
	for lv in LEVEL_COUNT:
		var mask: int = save.get_value("levels", "gems%d" % lv, 0)
		n += (mask & 1) + ((mask >> 1) & 1) + ((mask >> 2) & 1)
	return n


## Save a cleared level. Returns {"best_time": bool, "new_gems": int}.
func record_level(lv: int, time: float, gems: int, rank: String) -> Dictionary:
	var old := level_stat(lv)
	var out := {"best_time": not old["done"] or time < old["time"], "new_gems": 0}
	var merged: int = old["gems"] | gems
	for b in 3:
		if (gems >> b) & 1 == 1 and (old["gems"] >> b) & 1 == 0:
			out["new_gems"] += 1
	save.set_value("levels", "done%d" % lv, true)
	save.set_value("levels", "gems%d" % lv, merged)
	if out["best_time"]:
		save.set_value("levels", "time%d" % lv, time)
	var order := "CBAS"
	if old["rank"] == "" or order.find(rank) > order.find(old["rank"]):
		save.set_value("levels", "rank%d" % lv, rank)
	if lv + 1 > unlocked():
		save.set_value("story", "unlocked", mini(lv + 1, LEVEL_COUNT - 1))
	if lv >= LEVEL_COUNT - 1:
		save.set_value("story", "finished", true)
	save.save(SAVE_PATH)
	return out


func seen(what: String) -> bool:
	return save.get_value("seen", what, false)


func mark_seen(what: String) -> void:
	save.set_value("seen", what, true)
	save.save(SAVE_PATH)


func best_distance() -> int:
	return save.get_value("trial", "best", 0)


func save_distance(meters: int) -> bool:
	if meters <= best_distance():
		return false
	save.set_value("trial", "best", meters)
	save.save(SAVE_PATH)
	return true


# ---------------------------------------------------------------- coins and the bear shop

## Coins in the bank. Coins picked up in a level are banked when the level ends.
func wallet() -> int:
	return save.get_value("shop", "coins", 0)


func bank_coins(n: int) -> void:
	if n <= 0:
		return
	save.set_value("shop", "coins", wallet() + n)
	save.save(SAVE_PATH)


func owns(id: String) -> bool:
	return id in ["classic", "none"] or id in save.get_value("shop", "owned", [])


## Buy something from the shop. Returns false if it costs more than the wallet holds.
func buy(id: String, price: int) -> bool:
	if owns(id):
		return true
	if wallet() < price:
		return false
	var owned: Array = save.get_value("shop", "owned", [])
	owned.append(id)
	save.set_value("shop", "owned", owned)
	save.set_value("shop", "coins", wallet() - price)
	save.save(SAVE_PATH)
	return true


## slot: "skin" or "hat"
func equipped(slot: String) -> String:
	return save.get_value("shop", slot, "classic" if slot == "skin" else "none")


func equip(slot: String, id: String) -> void:
	save.set_value("shop", slot, id)
	save.save(SAVE_PATH)


func erase_save() -> void:
	var keep := {}
	for k in ["touch", "music", "sfx", "shake", "fullscreen"]:
		keep[k] = setting(k)
	save = ConfigFile.new()
	for k in keep:
		save.set_value("settings", k, keep[k])
	save.save(SAVE_PATH)


# ---------------------------------------------------------------- settings

const DEFAULTS := {"touch": 0, "music": 7, "sfx": 8, "shake": true, "fullscreen": false}


func setting(key: String) -> Variant:
	return save.get_value("settings", key, DEFAULTS[key])


func set_setting(key: String, value: Variant) -> void:
	save.set_value("settings", key, value)
	save.save(SAVE_PATH)
	apply_settings()


func apply_settings() -> void:
	var m: int = setting("music")
	music_player.volume_db = linear_to_db(maxf(m / 10.0 * 0.5, 0.0001))
	var want_full: bool = setting("fullscreen")
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		var is_full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if want_full != is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED)
	if touch != null:
		touch.refresh()


## Touch controls: 0 = auto (on when the device has a touchscreen), 1 = on, 2 = off.
func touch_on() -> bool:
	if debug_touch:
		return true
	var t: int = setting("touch")
	if t == 0:
		return DisplayServer.is_touchscreen_available()
	return t == 1


## The button to tell the player about, for whatever they are playing with.
func hint(action: String) -> String:
	var dev := "touch" if touch_on() else last_device
	return HINTS[dev].get(action, action)


func fill_hints(text: String) -> String:
	for a in ["move", "jump", "crouch", "dash", "attack", "interact"]:
		text = text.replace("{%s}" % a, hint(a))
	return text


# ---------------------------------------------------------------- sound and feel

func sfx(sound: String, pitch: float = 1.0, volume: float = 1.0) -> void:
	if not sounds.has(sound):
		return
	var s: int = setting("sfx")
	if s <= 0:
		return
	var p: AudioStreamPlayer = speakers.pop_front()
	speakers.append(p)
	p.stream = sounds[sound]
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(maxf(s / 10.0 * volume, 0.0001))
	p.play()


## Switch background music ("menu", "level", "boss", ...). Keeps playing if it's already on.
func music(song: String, pitch: float = 1.0) -> void:
	if song == track and music_player.playing and is_equal_approx(music_player.pitch_scale, pitch):
		return
	track = song
	music_player.stop()
	if tracks.has(song):
		music_player.stream = tracks[song]
		music_player.pitch_scale = pitch
		music_player.play()


## Freeze the action for a moment so a hit lands with weight.
func hitstop(seconds: float) -> void:
	if trans_phase != 0:
		return
	Engine.time_scale = 0.05
	stop_left = maxf(stop_left, seconds)


## Slow motion for big moments (boss finishers). Call with 1.0 to end it.
func slowmo(scale: float) -> void:
	stop_left = 0.0
	Engine.time_scale = scale


# ---------------------------------------------------------------- controls

func _setup_inputs() -> void:
	_keys(1, {"left": KEY_A, "right": KEY_D, "jump": KEY_W, "crouch": KEY_S, "interact": KEY_E, "dash": KEY_Q, "attack": KEY_F})
	_add_key("p1_jump", KEY_SPACE)
	_add_key("p1_attack", KEY_J)
	_add_key("p1_dash", KEY_K)
	_keys(2, {"left": KEY_LEFT, "right": KEY_RIGHT, "jump": KEY_UP, "crouch": KEY_DOWN, "interact": KEY_SHIFT, "dash": KEY_CTRL, "attack": KEY_ENTER})
	_add_key("p2_attack", KEY_SLASH)
	_axis("p3_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("p3_right", JOY_AXIS_LEFT_X, 1.0)
	_button("p3_left", JOY_BUTTON_DPAD_LEFT)
	_button("p3_right", JOY_BUTTON_DPAD_RIGHT)
	_button("p3_jump", JOY_BUTTON_A)
	_button("p3_attack", JOY_BUTTON_X)
	_button("p3_dash", JOY_BUTTON_B)
	_button("p3_dash", JOY_BUTTON_RIGHT_SHOULDER)
	_button("p3_interact", JOY_BUTTON_Y)
	_axis("p3_crouch", JOY_AXIS_LEFT_Y, 1.0, 0.6)
	_button("p3_crouch", JOY_BUTTON_DPAD_DOWN)
	_button("p3_crouch", JOY_BUTTON_LEFT_SHOULDER)
	_add_key("pause", KEY_ESCAPE)
	_add_key("pause", KEY_P)
	_button("pause", JOY_BUTTON_START)
	_add_key("back", KEY_ESCAPE)
	_button("back", JOY_BUTTON_B)
	for k in [KEY_ENTER, KEY_SPACE, KEY_W, KEY_UP, KEY_E, KEY_F, KEY_J]:
		_add_key("next", k)
	_button("next", JOY_BUTTON_A)
	_button("next", JOY_BUTTON_X)
	# Menu buttons listen to Godot's built-in ui_accept / ui_cancel, which have no controller
	# buttons by default. Bottom button = press, right button = back.
	_button("ui_accept", JOY_BUTTON_A)
	_button("ui_cancel", JOY_BUTTON_B)


func _keys(n: int, map: Dictionary) -> void:
	for a in map:
		_add_key("p%d_%s" % [n, a], map[a])
	if n == 2:  # player 2 interacts with the RIGHT shift key
		InputMap.action_get_events("p2_interact")[0].location = KEY_LOCATION_RIGHT


func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _axis(action: String, axis: JoyAxis, value: float, deadzone: float = 0.3) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- testing helpers
# Extra command line switches, after a "--":
#   --scene=menu | story:12 | trial | tutorial | cutscene:intro   jump straight somewhere
#   --bot            hold right, jump and claw on a timer (smoke test)
#   --shot=file.png --at=3.5      save a screenshot after that many seconds, then quit
#   --testall        build all 50 levels one after another, then quit
#   --coins=500 --wear=golden,crown   try out the bear shop (nothing is saved unless you buy)

var debug_shot := ""
var debug_at := 2.0
var debug_bot := false
var debug_col := 0
var debug_kill := 0.0
var debug_mode := "run"    # run | idle | wall
var debug_dir := 1
var debug_touch := false
var debug_hold := 0
var debug_t := 0.0


func _debug_args() -> void:
	var scene := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene = a.trim_prefix("--scene=")
		elif a.begins_with("--shot="):
			debug_shot = a.trim_prefix("--shot=")
		elif a.begins_with("--at="):
			debug_at = float(a.trim_prefix("--at="))
		elif a.begins_with("--col="):
			debug_col = int(a.trim_prefix("--col="))
		elif a.begins_with("--killboss="):
			debug_kill = float(a.trim_prefix("--killboss="))
		elif a == "--bot":
			debug_bot = true
		elif a.begins_with("--bot="):
			debug_bot = true
			debug_mode = a.trim_prefix("--bot=")
		elif a == "--touch":
			debug_touch = true
		elif a.begins_with("--coins="):   # test the shop: coins in the bank for this run only
			save.set_value("shop", "coins", int(a.trim_prefix("--coins=")))
		elif a.begins_with("--wear="):    # --wear=skin,hat for this run only
			var w := a.trim_prefix("--wear=").split(",")
			save.set_value("shop", "skin", w[0])
			if w.size() > 1:
				save.set_value("shop", "hat", w[1])
		elif a == "--testall":
			_test_all.call_deferred()
	if debug_mode == "wall":
		get_tree().physics_frame.connect(_debug_wall)
	if debug_shot != "" or debug_bot:
		var timer := Timer.new()
		timer.wait_time = 0.1
		timer.autostart = true
		timer.timeout.connect(_debug_tick)
		add_child(timer)
	if scene == "":
		return
	var parts := scene.split(":")
	var path := "res://menu.tscn"
	match parts[0]:
		"story":
			mode = Mode.STORY
			level = int(parts[1])
			path = "res://level.tscn"
		"trial":
			mode = Mode.TIME_TRIAL
			path = "res://level.tscn"
		"tutorial":
			mode = Mode.TUTORIAL
			path = "res://level.tscn"
		"cutscene":
			cutscene = parts[1]
			path = "res://cutscene.tscn"
		"map", "options", "shop":
			menu_page = parts[0]
	get_tree().change_scene_to_file.call_deferred(path)


## Test bot: run right and wall-kick up whatever it meets.
func _debug_wall() -> void:
	var sc := get_tree().current_scene
	if sc == null or sc.get("players") == null or sc.players.is_empty():
		return
	var p: CharacterBody2D = sc.players[0]
	# after a kick, keep heading for the opposite wall
	if p.lock_t > 0.1:
		debug_dir = int(signf(p.lock_dir))
	if p.is_on_floor():
		debug_dir = 1
	Input.action_release("p1_left" if debug_dir > 0 else "p1_right")
	Input.action_press("p1_right" if debug_dir > 0 else "p1_left")
	debug_hold -= 1
	if Input.is_action_pressed("p1_jump"):
		if debug_hold <= 0 and p.velocity.y > 0.0:
			Input.action_release("p1_jump")
	elif p.is_on_floor() or (p.wall_coyote > 0.0 and p.velocity.y > -60.0):
		Input.action_press("p1_jump")
		debug_hold = 12


func _debug_tick() -> void:
	debug_t += 0.1
	if debug_bot and debug_mode != "run":
		var sc := get_tree().current_scene
		if sc != null and sc.get("players") != null:
			var p: CharacterBody2D = sc.players[0]
			print("t=%.1f x=%.2f y=%.2f floor=%s wall=%s" % [debug_t, p.position.x / 36.0, p.position.y / 36.0, p.is_on_floor(), p.sliding])
	elif debug_bot:
		Input.action_press("p1_right")
		var step := int(debug_t * 10.0)
		if step % 8 == 0:
			Input.action_press("p1_jump")
		elif step % 8 == 3:
			Input.action_release("p1_jump")
		if step % 6 == 2:
			var ev := InputEventAction.new()
			ev.action = "next"
			ev.pressed = true
			Input.parse_input_event(ev)
		if step % 5 == 0:
			Input.action_press("p1_attack")
		elif step % 5 == 1:
			Input.action_release("p1_attack")
	var scene := get_tree().current_scene
	if debug_kill > 0.0 and debug_t >= debug_kill and scene != null and scene.get("boss") != null:
		# wear the boss down, then walk into the shard, to test the whole fight
		if not scene.boss.dead and scene.boss.active and int(debug_t * 10.0) % 4 == 0:
			scene.boss.take(4, 1, "claw")
		for cell in scene.pickups:
			if scene.pickups[cell]["type"] == "shard" and not scene.cinematic:
				scene.players[0].position = scene._feet(cell)
	if (debug_kill > 0.0 or debug_bot) and int(debug_t * 10.0) % 30 == 0 and scene != null and scene.get("players") != null:
		var b: Variant = scene.get("boss")
		print("t=%.0f x=%d hp=%d deaths=%d done=%s cine=%s boss=%s" % [debug_t, scene.players[0].position.x / 36.0, scene.players[0].hp,
			scene.deaths, scene.done, scene.cinematic, "-" if b == null else "%d/%d %s p%d" % [b.hp, b.max_hp, b.state, b.phase]])
	if debug_shot != "" and debug_t >= debug_at:
		get_viewport().get_texture().get_image().save_png(debug_shot)
		print("saved ", debug_shot)
		get_tree().quit()


func _test_all() -> void:
	mode = Mode.STORY
	for lv in LEVEL_COUNT:
		level = lv
		get_tree().change_scene_to_file("res://level.tscn")
		for i in 12:
			await get_tree().process_frame
		print("built level ", lv + 1, " ", Levels.LEVELS[lv]["name"], "  width ", get_tree().current_scene.width)
	for m in [Mode.TUTORIAL, Mode.TIME_TRIAL]:
		mode = m
		get_tree().change_scene_to_file("res://level.tscn")
		for i in 30:
			await get_tree().process_frame
		print("built mode ", m)
	for c in ["intro", "world2", "world3", "world4", "world5", "ending"]:
		cutscene = c
		get_tree().change_scene_to_file("res://cutscene.tscn")
		for i in 20:
			await get_tree().process_frame
		print("cutscene ", c)
	get_tree().change_scene_to_file("res://menu.tscn")
	for i in 20:
		await get_tree().process_frame
	print("TESTALL DONE")
	get_tree().quit()

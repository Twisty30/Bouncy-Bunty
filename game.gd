extends Node
## controllers and game stuff

enum Mode { TUTORIAL, TIME_TRIAL, STORY }

const FONT := preload("res://fonts/mario/mario_world_pixel.ttf")
const TINTS := [Color(1, 1, 1), Color(0.95, 1.3, 1.9), Color(1.15, 1.65, 0.95)]
const SAVE_PATH := "user://save.cfg"

var mode: int = Mode.TUTORIAL
var player_schemes: Array = [[1, 2, 3]]   # one entry per bear; singleplayer = every scheme
var story_level := 0
var cutscene := "intro"

var save := ConfigFile.new()
var sounds := {}
var speakers: Array = []
var tracks := {}
var track := ""
var music_player := AudioStreamPlayer.new()


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
	for i in 8:
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
	music_player.volume_db = -9.0
	add_child(music_player)
	_setup_inputs()


func sfx(name: String, pitch: float = 1.0) -> void:
	if not sounds.has(name):
		return
	var p: AudioStreamPlayer = speakers.pop_front()
	speakers.append(p)
	p.stream = sounds[name]
	p.pitch_scale = pitch
	p.play()


## Switch background music ("menu", "level", "boss"). Keeps playing if it's already on.
func music(name: String) -> void:
	if name == track and music_player.playing:
		return
	track = name
	music_player.stop()
	if tracks.has(name):
		music_player.stream = tracks[name]
		music_player.play()


## One-shot puff of square pixel particles (dust, sparkles, confetti). Frees itself.
func burst(parent: Node, pos: Vector2, amount: int, color: Color, speed: float = 90.0,
		dir: Vector2 = Vector2.UP, spread: float = 70.0, gravity: float = 300.0,
		size: float = 4.0, lifetime: float = 0.45) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.damping_min = speed * 0.5
	p.damping_max = speed
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	p.color_ramp = fade
	parent.add_child(p)
	p.emitting = true
	get_tree().create_timer(lifetime + 0.3, false).timeout.connect(p.queue_free)


func start_tutorial() -> void:
	mode = Mode.TUTORIAL
	player_schemes = [[1, 2, 3]]
	get_tree().change_scene_to_file("res://level.tscn")


func start_time_trial() -> void:
	mode = Mode.TIME_TRIAL
	player_schemes = [[1, 2, 3]]
	get_tree().change_scene_to_file("res://level.tscn")


## player 1 2 3
func start_story(players: int, level: int = -1) -> void:
	mode = Mode.STORY
	player_schemes = [[[1, 2, 3]], [[1], [2]], [[1], [2], [3]]][players - 1]
	if level < 0:
		story_level = 0
		play_cutscene("intro")
	else:
		story_level = level
		get_tree().change_scene_to_file("res://level.tscn")


func play_cutscene(which: String) -> void:
	cutscene = which
	get_tree().change_scene_to_file("res://cutscene.tscn")


func cutscene_done() -> void:
	if cutscene == "intro":
		get_tree().change_scene_to_file("res://level.tscn")
	else:
		goto_menu()


func level_done() -> void:
	if mode != Mode.STORY:
		goto_menu()
		return
	story_level += 1
	if story_level > progress():
		save.set_value("story", "level", mini(story_level, 14))
		save.save(SAVE_PATH)
	if story_level >= 15:
		play_cutscene("ending")
	else:
		get_tree().change_scene_to_file.call_deferred("res://level.tscn")


func goto_menu() -> void:
	get_tree().change_scene_to_file.call_deferred("res://menu.tscn")


func progress() -> int:
	return save.get_value("story", "level", 0)


func best_distance() -> int:
	return save.get_value("trial", "best", 0)


func save_distance(meters: int) -> bool:
	if meters <= best_distance():
		return false
	save.set_value("trial", "best", meters)
	save.save(SAVE_PATH)
	return true


# controls

func _setup_inputs() -> void:
	_keys(1, {"left": KEY_A, "right": KEY_D, "jump": KEY_W, "crouch": KEY_S, "interact": KEY_E, "dash": KEY_Q})
	_keys(2, {"left": KEY_LEFT, "right": KEY_RIGHT, "jump": KEY_UP, "crouch": KEY_DOWN, "interact": KEY_SHIFT, "dash": KEY_CTRL})
	_axis("p3_left", -1.0)
	_axis("p3_right", 1.0)
	_button("p3_jump", JOY_BUTTON_A)                 
	_button("p3_dash", JOY_BUTTON_X)                 
	_button("p3_interact", JOY_BUTTON_Y)            
	_button("p3_crouch", JOY_BUTTON_RIGHT_SHOULDER) 
	_button("back", JOY_BUTTON_B)                    
	_add_key("back", KEY_ESCAPE)
	for k in [KEY_ENTER, KEY_SPACE, KEY_W, KEY_UP, KEY_E]:
		_add_key("next", k)
	_button("next", JOY_BUTTON_A)
	# Menu buttons only listen to Godot's built-in ui_accept / ui_cancel, which have
	# no controller buttons by default. Bottom button = press, right button = back.
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


func _axis(action: String, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
	var ev := InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = value
	InputMap.action_add_event(action, ev)

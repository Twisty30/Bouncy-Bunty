extends Control
## Main menu. The layout lives in menu.tscn; the story submenus are built here
## into the Submenu box, which sits where the three main buttons are.
## Controller: stick / d-pad moves, bottom button (A) presses, right button (B) goes back.
## (A and B are added to ui_accept / back in game.gd.)

const FONT := preload("res://fonts/mario/mario_world_pixel.ttf")

@onready var main_buttons: Array[Button] = [$TutorialButton, $StoryButton, $TimeTrialButton]
@onready var submenu: VBoxContainer = $Submenu
@onready var title: Label = $Title
@onready var background: TextureRect = $Background
@onready var title_pos := title.position

var back_to := Callable()   # where Esc / B goes from the current submenu
var t := 0.0
var quiet_until := 0        # no "move" blip for focus we grab ourselves


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.36, 0.58, 0.99))
	Game.music("menu")
	_connect($TutorialButton, Game.start_tutorial)
	_connect($StoryButton, story_menu)
	_connect($TimeTrialButton, Game.start_time_trial)
	main_menu()


func _process(delta: float) -> void:
	t += delta
	title.pivot_offset = title.size / 2
	title.position.y = title_pos.y + sin(t * 2.0) * 6.0
	title.rotation = sin(t * 1.3) * 0.03
	background.pivot_offset = background.size / 2
	background.scale = Vector2.ONE * (1.04 + sin(t * 0.4) * 0.02)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back") and back_to.is_valid():
		get_viewport().set_input_as_handled()
		Game.sfx("menu_select")
		back_to.call()


func _connect(b: Button, action: Callable) -> void:
	b.pressed.connect(func() -> void:
		Game.sfx("menu_select")
		action.call())
	b.focus_entered.connect(func() -> void:
		if Time.get_ticks_msec() > quiet_until:
			Game.sfx("menu_move")
		_grow(b, 1.1))
	b.focus_exited.connect(_grow.bind(b, 1.0))


func _grow(b: Button, to: float) -> void:
	b.pivot_offset = b.size / 2
	var tw := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE * to, 0.18)


func _show_main(on: bool) -> void:
	quiet_until = Time.get_ticks_msec() + 150
	for b in main_buttons:
		b.visible = on
		b.scale = Vector2.ONE
	submenu.visible = not on
	for c in submenu.get_children():
		submenu.remove_child(c)
		c.queue_free()
	_fade_in.call_deferred(on)


## Buttons fade in one after another. Deferred, so the submenu buttons exist by then.
func _fade_in(main: bool) -> void:
	var buttons: Array = main_buttons if main else submenu.get_children()
	for i in buttons.size():
		var b: Control = buttons[i]
		b.modulate.a = 0.0
		var tw := b.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(b, "modulate:a", 1.0, 0.2)


func button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 32)
	_connect(b, action)
	submenu.add_child(b)
	if submenu.get_child_count() == 1:
		b.grab_focus.call_deferred()


func main_menu() -> void:
	back_to = Callable()
	_show_main(true)
	main_buttons[0].grab_focus.call_deferred()


func story_menu() -> void:
	back_to = main_menu
	_show_main(false)
	for n in 3:
		button("%d Player%s" % [n + 1, "s" if n > 0 else ""], start_menu.bind(n + 1))
	button("Back", main_menu)


func start_menu(players: int) -> void:
	if Game.progress() == 0:
		Game.start_story(players)
		return
	back_to = story_menu
	_show_main(false)
	button("New Game", Game.start_story.bind(players, -1))
	button("Continue: Level %d" % (Game.progress() + 1), Game.start_story.bind(players, Game.progress()))
	button("Back", story_menu)

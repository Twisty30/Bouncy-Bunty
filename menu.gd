extends Control
## Main menu. The layout lives in menu.tscn; the story submenus are built here
## into the Submenu box, which sits where the three main buttons are.

const FONT := preload("res://fonts/mario/mario_world_pixel.ttf")

@onready var main_buttons: Array[Button] = [$TutorialButton, $StoryButton, $TimeTrialButton]
@onready var submenu: VBoxContainer = $Submenu


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.36, 0.58, 0.99))
	_connect($TutorialButton, Game.start_tutorial)
	_connect($StoryButton, story_menu)
	_connect($TimeTrialButton, Game.start_time_trial)
	main_menu()


func _connect(b: Button, action: Callable) -> void:
	b.pressed.connect(func() -> void:
		Game.sfx("menu_select")
		action.call())


func _show_main(on: bool) -> void:
	for b in main_buttons:
		b.visible = on
	submenu.visible = not on
	for c in submenu.get_children():
		submenu.remove_child(c)
		c.queue_free()


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
	_show_main(true)
	main_buttons[0].grab_focus.call_deferred()


func story_menu() -> void:
	_show_main(false)
	for n in 3:
		button("%d Player%s" % [n + 1, "s" if n > 0 else ""], start_menu.bind(n + 1))
	button("Back", main_menu)


func start_menu(players: int) -> void:
	if Game.progress() == 0:
		Game.start_story(players)
		return
	_show_main(false)
	button("New Game", Game.start_story.bind(players, -1))
	button("Continue: Level %d" % (Game.progress() + 1), Game.start_story.bind(players, Game.progress()))
	button("Back", story_menu)

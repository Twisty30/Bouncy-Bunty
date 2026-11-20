extends CanvasLayer
## On-screen touch controls for phones and tablets. They press the same input actions as
## player 1's keys, so nothing else in the game needs to know about touch.
## Turned on/off in Options (AUTO = on when the device has a touchscreen).

const FONT := preload("res://fonts/mario/mario_world_pixel.ttf")
const ACTIONS := {"left": "p1_left", "right": "p1_right", "down": "p1_crouch", "jump": "p1_jump",
	"claw": "p1_attack", "dash": "p1_dash", "use": "p1_interact", "pause": "pause"}
const MOVE := ["left", "right", "down"]

var active := false          # the level turns this on while you can play
var fingers := {}            # touch index -> button name
var held := {}               # button name -> number of fingers on it
var pad := Control.new()


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.draw.connect(_draw_pad)
	add_child(pad)
	get_viewport().size_changed.connect(pad.queue_redraw)
	refresh()


func set_active(on: bool) -> void:
	active = on
	refresh()


func refresh() -> void:
	var on := active and Game.touch_on()
	if not on:
		_release_all()
	visible = on
	pad.queue_redraw()


## name -> Rect2, laid out from the corners of whatever screen we are on.
func _buttons() -> Dictionary:
	var v := get_viewport().get_visible_rect().size
	return {
		"left": Rect2(30, v.y - 160, 130, 130),
		"right": Rect2(175, v.y - 160, 130, 130),
		"down": Rect2(110, v.y - 275, 115, 100),
		"jump": Rect2(v.x - 165, v.y - 170, 140, 140),
		"claw": Rect2(v.x - 315, v.y - 150, 130, 120),
		"dash": Rect2(v.x - 160, v.y - 300, 125, 110),
		"use": Rect2(v.x - 300, v.y - 265, 110, 95),
		"pause": Rect2(v.x - 84, 16, 68, 60),
	}


func _button_at(pos: Vector2) -> String:
	var b := _buttons()
	for n in b:
		if b[n].grow(10).has_point(pos):
			return n
	return ""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var b := _button_at(event.position)
			if b != "":
				fingers[event.index] = b
				_press(b)
		elif fingers.has(event.index):
			_release(fingers[event.index])
			fingers.erase(event.index)
	elif event is InputEventScreenDrag and fingers.has(event.index):
		# slide a thumb between the arrow buttons without lifting it
		var old: String = fingers[event.index]
		var b := _button_at(event.position)
		if old in MOVE and b in MOVE and b != old:
			_release(old)
			fingers[event.index] = b
			_press(b)


func _press(b: String) -> void:
	held[b] = held.get(b, 0) + 1
	if held[b] == 1:
		Input.action_press(ACTIONS[b])
	pad.queue_redraw()


func _release(b: String) -> void:
	held[b] = maxi(held.get(b, 0) - 1, 0)
	if held[b] == 0:
		Input.action_release(ACTIONS[b])
	pad.queue_redraw()


func _release_all() -> void:
	for b in held:
		if held[b] > 0:
			Input.action_release(ACTIONS[b])
	held.clear()
	fingers.clear()


func _draw_pad() -> void:
	var b := _buttons()
	for n in b:
		var r: Rect2 = b[n]
		var down: bool = held.get(n, 0) > 0
		var fill := Color(1, 0.85, 0.3, 0.75) if down else Color(0.1, 0.08, 0.2, 0.42)
		var edge := Color(1, 1, 1, 0.9) if down else Color(1, 0.96, 0.84, 0.6)
		# chunky pixel button: cut corners, thick border
		var c := 10.0
		var shape := PackedVector2Array([r.position + Vector2(c, 0), r.position + Vector2(r.size.x - c, 0),
			r.position + Vector2(r.size.x, c), r.position + Vector2(r.size.x, r.size.y - c),
			r.end - Vector2(c, 0), r.position + Vector2(c, r.size.y), r.position + Vector2(0, r.size.y - c),
			r.position + Vector2(0, c)])
		pad.draw_colored_polygon(shape, fill)
		shape.append(shape[0])
		pad.draw_polyline(shape, edge, 5.0)
		var mid := r.get_center()
		var ink := Color(0.1, 0.08, 0.2, 0.95) if down else Color(1, 0.96, 0.84, 0.9)
		match n:
			"left":
				pad.draw_colored_polygon(PackedVector2Array([mid + Vector2(-26, 0), mid + Vector2(18, -28), mid + Vector2(18, 28)]), ink)
			"right":
				pad.draw_colored_polygon(PackedVector2Array([mid + Vector2(26, 0), mid + Vector2(-18, -28), mid + Vector2(-18, 28)]), ink)
			"down":
				pad.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, 22), mid + Vector2(-26, -16), mid + Vector2(26, -16)]), ink)
			"pause":
				pad.draw_rect(Rect2(mid + Vector2(-14, -14), Vector2(10, 28)), ink)
				pad.draw_rect(Rect2(mid + Vector2(4, -14), Vector2(10, 28)), ink)
			_:
				var text: String = n.to_upper()
				var size := 22 if n == "jump" else 18
				var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				pad.draw_string(FONT, mid + Vector2(-w / 2.0, size * 0.4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)

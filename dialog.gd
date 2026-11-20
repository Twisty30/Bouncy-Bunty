extends CanvasLayer
## Dialogue box: a portrait, a name and text that types itself out.
##   dialog.say([["BUNTY", "Hello!"], ["", "A line with no speaker."]])
##   await dialog.done

signal done
signal line_shown(who: String, index: int)

const Cast := preload("res://cast.gd")
const Ui := preload("res://ui.gd")

const SPEED := 45.0   # letters per second

var lines: Array = []
var index := 0
var shown := 0.0
var open := false
var blip_at := 0
var esc_closes := true   # Esc / Start skips the rest of the conversation

var root := Control.new()
var panel: PanelContainer
var face := Control.new()
var face_actor: Node2D
var name_label: Label
var text_label: Label
var arrow := Polygon2D.new()
var t := 0.0


func _ready() -> void:
	layer = 50
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = Ui.panel(Color(0.09, 0.07, 0.18, 0.94), Ui.CREAM)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	# the box sits at the top so it never covers the characters on the ground
	panel.offset_left = 70
	panel.offset_right = -70
	panel.offset_top = 72
	panel.offset_bottom = 242
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	face.custom_minimum_size = Vector2(124, 124)
	row.add_child(face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	name_label = Ui.label("", 20, Ui.GOLD, 6)
	col.add_child(name_label)
	text_label = Ui.label("", 18, Ui.CREAM, 0)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.add_theme_constant_override("line_spacing", 8)
	col.add_child(text_label)
	arrow.polygon = PackedVector2Array([Vector2(-10, -8), Vector2(10, -8), Vector2(0, 8)])
	arrow.color = Ui.GOLD
	root.add_child(arrow)
	root.visible = false


func say(new_lines: Array) -> void:
	lines = new_lines
	index = 0
	open = true
	root.visible = true
	panel.pivot_offset = Vector2(panel.size.x / 2.0, 0)
	panel.scale = Vector2(1.0, 0.0)
	var tw := panel.create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_line()


func _show_line() -> void:
	var who: String = lines[index][0]
	shown = 0.0
	blip_at = 0
	name_label.text = who
	name_label.add_theme_color_override("font_color", Cast.color(who))
	name_label.visible = who != ""
	text_label.text = Game.fill_hints(lines[index][1])
	text_label.visible_characters = 0
	if face_actor != null:
		face_actor.queue_free()
		face_actor = null
	face.visible = who != "" and Cast.CAST.has(who)
	if face.visible:
		var px := 4.5 if Cast.CAST[who].get("bear", false) else 5.0
		face_actor = Cast.actor(who, px)
		face_actor.position = Vector2(62, 118 if Cast.CAST[who].get("bear", false) else 122)
		face.add_child(face_actor)
		var spr: Node2D = face_actor.get_node("spr")
		var tw := face_actor.create_tween()
		face_actor.scale = Vector2(1.25, 0.75)
		tw.tween_property(face_actor, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		spr.visible = true
	line_shown.emit(who, index)


func _process(delta: float) -> void:
	if not open:
		return
	t += delta
	var total := text_label.text.length()
	if shown < total:
		shown = minf(shown + SPEED * delta, total)
		text_label.visible_characters = int(shown)
		if int(shown) >= blip_at:
			blip_at = int(shown) + 3
			Game.sfx("blip", randf_range(0.9, 1.15), 0.5)
	var v := get_viewport().get_visible_rect().size
	arrow.visible = shown >= total
	arrow.position = Vector2(v.x - 104, 216 + sin(t * 8.0) * 4.0)


func _input(event: InputEvent) -> void:
	if not open or Game.busy():
		return
	var press := event.is_action_pressed("next")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		press = true
	if esc_closes and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
		return
	if not press:
		return
	get_viewport().set_input_as_handled()
	if shown < text_label.text.length():
		shown = text_label.text.length()
		text_label.visible_characters = -1
		return
	index += 1
	if index >= lines.size():
		close()
	else:
		Game.sfx("menu_move")
		_show_line()


func close() -> void:
	if not open:
		return
	open = false
	root.visible = false
	done.emit()

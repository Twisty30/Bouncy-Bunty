extends RefCounted
## Chunky pixel UI pieces shared by the menus, the HUD and the dialogue box.

const INK := Color(0.11, 0.09, 0.2)
const CREAM := Color(1, 0.96, 0.84)
const GOLD := Color(1, 0.8, 0.25)
const PINK := Color(1.0, 0.45, 0.65)
const SKY := Color(0.45, 0.8, 1.0)


static func box(bg: Color, border: Color, width: int = 4, shadow: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 0
	s.shadow_offset = Vector2(shadow, shadow)
	if shadow > 0:
		s.shadow_size = 1
	s.set_content_margin_all(12)
	return s


static func label(text: String, size: int = 20, color: Color = CREAM, outline: int = 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", outline)
	return l


static func panel(bg: Color = Color(0.11, 0.09, 0.2, 0.92), border: Color = CREAM) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border))
	return p


## A menu button: grows and blips when focused, clicks when pressed.
## pad: space above and below the text (smaller pad = shorter button).
static func button(text: String, action: Callable, size: int = 24, min_size: Vector2 = Vector2(300, 56), pad: int = 12) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.6))
	var styles := {
		"normal": box(Color(0.16, 0.14, 0.3, 0.95), CREAM),
		"hover": box(GOLD, Color.WHITE),
		"focus": box(GOLD, Color.WHITE),
		"pressed": box(Color(1, 0.6, 0.2), Color.WHITE, 4, 2),
		"disabled": box(Color(0.12, 0.11, 0.2, 0.9), Color(0.4, 0.4, 0.5)),
	}
	for k in styles:
		styles[k].content_margin_top = pad
		styles[k].content_margin_bottom = pad
		b.add_theme_stylebox_override(k, styles[k])
	b.pressed.connect(func() -> void:
		Game.sfx("menu_select")
		action.call())
	b.focus_entered.connect(func() -> void:
		if Time.get_ticks_msec() > Game.quiet_until:
			Game.sfx("menu_move")
		grow(b, 1.08))
	b.focus_exited.connect(grow.bind(b, 1.0))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled and b.is_visible_in_tree():
			b.grab_focus())
	return b


static func grow(c: Control, to: float) -> void:
	if not c.is_inside_tree():
		return
	c.pivot_offset = c.size / 2
	var tw := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE * to, 0.16)


## Scale-pop a control in (stamps, counters).
static func pop(c: Control, from: float = 2.2, time: float = 0.3) -> void:
	c.pivot_offset = c.size / 2
	c.scale = Vector2.ONE * from
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, time * 0.5)

extends Node
## Scenery behind everything: sky gradient, two layers of hills, drifting clouds and weather.
## Used by levels, cutscenes and the menu. Call set_theme() once and scroll() every frame.

const Levels := preload("res://levels.gd")
const BACKS := preload("res://kenney_pixel-platformer/Tilemap/tilemap-backgrounds_packed.png")

var theme_name := ""
var back_layer := CanvasLayer.new()
var sky := TextureRect.new()
var skyline := Sprite2D.new()
var skyline_far := Sprite2D.new()
var ground_fill := ColorRect.new()
var cloud_layer := CanvasLayer.new()
var clouds: Array = []     # [sprite, x, y, depth, drift speed]
var weather_layer := CanvasLayer.new()
var weather: CPUParticles2D
var horizon := 0.48        # how far down the screen the hills sit (0..1)


func _ready() -> void:
	back_layer.layer = -10
	add_child(back_layer)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_layer.add_child(sky)
	for s: Sprite2D in [skyline_far, skyline]:
		s.centered = false
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.region_enabled = true
		back_layer.add_child(s)
	ground_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_layer.add_child(ground_fill)
	cloud_layer.layer = -5
	add_child(cloud_layer)
	weather_layer.layer = 6
	add_child(weather_layer)
	for i in 9:
		var spr := Sprite2D.new()
		spr.texture = _cloud_texture()
		var depth := randf_range(0.15, 0.45)        # far clouds are smaller and move less
		spr.scale = Vector2.ONE * roundf(lerpf(2.0, 4.0, depth / 0.45))
		cloud_layer.add_child(spr)
		clouds.append([spr, i * 160.0 + randf_range(0, 100), randf_range(30, 300), depth, randf_range(6, 16)])


## Sky, hills, clouds and weather for a theme from levels.gd ("grass", "sand", ...).
func set_theme(th: String) -> void:
	if th == theme_name:
		return
	theme_name = th
	var info: Dictionary = Levels.THEMES[th]
	var grad := Gradient.new()
	grad.set_color(0, info["sky"][0])
	grad.set_color(1, info["sky"][1])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	sky.texture = gt
	RenderingServer.set_default_clear_color(info["sky"][1])

	# hills: the skyline tiles of the Kenney background sheet with their flat sky cut out
	var cols: Array = info["bg"]
	var src: Image = BACKS.get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var strip := Image.create(cols.size() * 24, 24, false, Image.FORMAT_RGBA8)
	for i in cols.size():
		strip.blit_rect(src, Rect2i(cols[i] * 24, 24, 24, 24), Vector2i(i * 24, 0))
	var sky_color := src.get_pixel(cols[0] * 24 + 1, 1)
	for y in 24:
		for x in strip.get_width():
			if strip.get_pixel(x, y).is_equal_approx(sky_color):
				strip.set_pixel(x, y, Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(strip)
	var tint: Color = info["bg_tint"]
	skyline.texture = tex
	skyline.modulate = tint
	skyline_far.texture = tex
	skyline_far.modulate = Color(tint.lerp(info["sky"][1], 0.55), 0.8)
	ground_fill.color = src.get_pixel(cols[0] * 24 + 1, 60) * tint
	ground_fill.color.a = 1.0
	for c in clouds:
		var spr: Sprite2D = c[0]
		var cl: Color = info["clouds"]
		spr.modulate = Color(cl, cl.a * lerpf(0.6, 1.0, c[3] / 0.45))
	_set_weather(info["weather"])


## Move the scenery for a camera centred at (cx, cy) in world pixels.
func scroll(cx: float, cy: float, delta: float) -> void:
	var view := get_viewport().get_visible_rect().size
	var lift := clampf((252.0 - cy) * 0.12, 0.0, 120.0)
	skyline.scale = Vector2(6, 6)
	skyline.position = Vector2(0, view.y * horizon + lift)
	skyline.region_rect = Rect2(cx * 0.3 / 6.0, 0, view.x / 6.0 + 2.0, 24)
	skyline_far.scale = Vector2(4, 4)
	skyline_far.position = Vector2(0, view.y * horizon - 40.0 + lift * 0.6)
	skyline_far.region_rect = Rect2(cx * 0.12 / 4.0 + 40.0, 0, view.x / 4.0 + 2.0, 24)
	ground_fill.position = Vector2(0, skyline.position.y + 143.0)
	ground_fill.size = Vector2(view.x, view.y)
	var span := view.x + 300.0
	for c in clouds:
		c[1] += c[4] * delta
		var spr: Sprite2D = c[0]
		spr.position = Vector2(fposmod(c[1] - cx * c[3], span) - 150.0, c[2] - cy * c[3] * 0.3 + 60.0)


func _set_weather(kind: String) -> void:
	if weather != null:
		weather.queue_free()
		weather = null
	var v := get_viewport().get_visible_rect().size
	var p := CPUParticles2D.new()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.position = Vector2(v.x / 2.0, -20)
	p.emission_rect_extents = Vector2(v.x * 0.75, 10)
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	match kind:
		"snow":
			p.amount = 150
			p.lifetime = 9.0
			p.direction = Vector2(-0.25, 1)
			p.initial_velocity_min = 50.0
			p.initial_velocity_max = 110.0
			p.scale_amount_min = 3.0
			p.scale_amount_max = 6.0
			p.color = Color(1, 1, 1, 0.9)
		"rain":
			p.amount = 240
			p.lifetime = 1.1
			p.position.x += 160.0
			p.direction = Vector2(-0.25, 1)
			p.spread = 2.0
			p.initial_velocity_min = 800.0
			p.initial_velocity_max = 1000.0
			var streak := Image.create(2, 12, false, Image.FORMAT_RGBA8)
			streak.fill(Color.WHITE)
			p.texture = ImageTexture.create_from_image(streak)
			p.color = Color(0.7, 0.8, 1.0, 0.5)
		"petals":
			p.amount = 26
			p.lifetime = 11.0
			p.direction = Vector2(-0.5, 1)
			p.spread = 30.0
			p.initial_velocity_min = 35.0
			p.initial_velocity_max = 80.0
			p.scale_amount_min = 4.0
			p.scale_amount_max = 6.0
			p.color = Color(1.0, 0.75, 0.88, 0.9)
		"dust":
			p.amount = 46
			p.lifetime = 6.0
			p.position = Vector2(v.x + 20.0, v.y / 2.0)
			p.emission_rect_extents = Vector2(10, v.y / 2.0)
			p.direction = Vector2(-1, 0.05)
			p.initial_velocity_min = 140.0
			p.initial_velocity_max = 280.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			p.color = Color(1.0, 0.92, 0.75, 0.55)
		"embers":
			p.amount = 55
			p.lifetime = 6.0
			p.position = Vector2(v.x / 2.0, v.y + 20.0)
			p.direction = Vector2(0.1, -1)
			p.spread = 20.0
			p.initial_velocity_min = 50.0
			p.initial_velocity_max = 130.0
			p.scale_amount_min = 3.0
			p.scale_amount_max = 5.0
			var ramp := Gradient.new()
			ramp.set_color(0, Color(1.0, 0.7, 0.2, 0.9))
			ramp.set_color(1, Color(1.0, 0.2, 0.1, 0.0))
			p.color_ramp = ramp
	p.preprocess = p.lifetime
	weather_layer.add_child(p)
	weather = p


func _cloud_texture() -> ImageTexture:
	var n := randi_range(3, 5)
	var w := n * 9 + 14
	var h := 22
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var puffs := []
	for k in n:
		var r := randf_range(5, 7) if k in [0, n - 1] else randf_range(7, 9.5)
		puffs.append([lerpf(7, w - 8, k / float(n - 1)), h - 3 - r * 0.8, r])
	var shade := Color(0.82, 0.88, 0.97)
	var edge := Color(0.62, 0.72, 0.88)
	for y in h:
		for x in w:
			var inside := false
			for p in puffs:
				if Vector2(x - p[0], (y - p[1]) * 1.15).length() <= p[2]:
					inside = true
			if y >= h - 8 and x >= 4 and x < w - 4:   # flat base so the puffs always join up
				inside = true
			if inside and y < h - 2:
				img.set_pixel(x, y, Color.WHITE if y < h - 7 else shade)
	# dark outline around the shape, matching the tile art
	var out := img.duplicate()
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0:
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and img.get_pixelv(q).a > 0:
					out.set_pixel(x, y, edge)
					break
	return ImageTexture.create_from_image(out)

extends Node
## Autoload "Fx": plays the pixel art effects in res://fx (sprite sheets rendered from the
## pixelfx library by tools/build_fx.mjs) and little square-pixel particle bursts.

const FxData := preload("res://fx_data.gd")
const FxSprite := preload("res://fx_sprite.gd")

var cache := {}
var add_material := CanvasItemMaterial.new()


func _ready() -> void:
	add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func names() -> Array:
	return FxData.DATA.keys()


func tex(fx: String) -> Texture2D:
	if not cache.has(fx):
		cache[fx] = load("res://fx/%s.png" % fx)
	return cache[fx]


## Length of an effect in seconds at normal speed.
func length(fx: String) -> float:
	var d: Array = FxData.DATA[fx]
	return d[2] / float(d[0])


## Play an effect with its origin (feet / hit point) at pos, as a child of parent.
## opts: scale (1), flip, rot, z (5), speed (1), alpha (1), tint, add (additive glow),
## follow (Node2D), follow_offset, real_time, hold_last, loop (override).
func play(parent: Node, fx: String, pos: Vector2, opts: Dictionary = {}) -> Sprite2D:
	if parent == null or not is_instance_valid(parent) or not FxData.DATA.has(fx):
		return null
	var d: Array = FxData.DATA[fx]
	var s: Sprite2D = FxSprite.new()
	s.texture = tex(fx)
	s.hframes = d[7]
	s.vframes = ceili(d[2] / float(d[7]))
	s.centered = false
	s.offset = -Vector2(d[5], d[6])
	s.fps = d[0]
	s.loop = opts.get("loop", d[1])
	s.count = d[2]
	s.fade_tail = d[8] == 1
	s.speed = opts.get("speed", 1.0)
	s.alpha = opts.get("alpha", 1.0)
	s.real_time = opts.get("real_time", false)
	s.hold_last = opts.get("hold_last", false)
	var k: float = opts.get("scale", 1.0)
	s.scale = Vector2(-k if opts.get("flip", false) else k, k)
	s.rotation = opts.get("rot", 0.0)
	s.z_index = opts.get("z", 5)
	s.modulate = opts.get("tint", Color.WHITE)
	s.modulate.a *= s.alpha
	if opts.get("add", false):
		s.material = add_material
	s.position = pos
	if opts.has("follow"):
		s.follow = opts["follow"]
		s.follow_offset = opts.get("follow_offset", Vector2.ZERO)
	parent.add_child(s)
	return s


## One-shot puff of square pixel particles (dust, sparkles, debris). Frees itself.
func burst(parent: Node, pos: Vector2, amount: int, color: Color, speed: float = 90.0,
		dir: Vector2 = Vector2.UP, spread: float = 70.0, gravity: float = 300.0,
		size: float = 4.0, lifetime: float = 0.45) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
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
	p.z_index = 4
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	p.color_ramp = fade
	parent.add_child(p)
	p.emitting = true
	get_tree().create_timer(lifetime + 0.3, false).timeout.connect(p.queue_free)


const CONFETTI := [Color(1, 0.35, 0.55), Color(1, 0.82, 0.22), Color(0.4, 0.85, 1), Color(0.5, 1, 0.5), Color(0.85, 0.55, 1), Color(1, 1, 1)]


## Confetti fired from one side of the screen (side = -1 from the left edge, 1 from the right),
## arcing up and falling back on that side, so the middle of the screen stays clear.
func side_confetti(parent: Node, pos: Vector2, side: int, scale: float = 1.0) -> void:
	for c: Color in CONFETTI:
		burst(parent, pos, 14, c, 900.0 * scale, Vector2(-side * 0.35, -1.0).normalized(), 18.0,
			500.0 * scale, 9.0, 1.6)

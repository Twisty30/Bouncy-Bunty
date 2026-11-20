extends Node2D
## Every baddie and moving hazard in a level. `kind` picks the behaviour:
##   bot      walks back and forth. Stomp it, claw it, dash through it.
##   bat      flies a lazy wave. Same weaknesses as the bot.
##   drill    walks; spike on top, so stomping hurts YOU. Claw or dash it.
##   bigbot   4 HP, charges when it sees you.
##   shooter  stands still and fires plasma at you.
##   ghost    drifts after you through walls. Only claws work.
##   thwomp   waits above and slams down. Can't be hurt.
##   spark    spiked ball swinging round a post. Can't be hurt.
##   saw_h / saw_v   energy saw sliding back and forth. Can't be hurt.
##   jet      fire jet that turns on and off.
##   arc      electric arc that turns on and off.
##   icicle   drops when you walk under it.
## The node's origin is the bottom-centre of its hit box.

const Cast := preload("res://cast.gd")
const T := 36.0

const INFO := {
	"bot": {"frames": [18, 19, 20], "px": 2.0, "size": Vector2(30, 26), "hp": 1, "speed": 55.0},
	"bat": {"frames": [24, 25, 26, 25], "px": 2.0, "size": Vector2(34, 24), "hp": 1, "speed": 70.0, "fps": 10.0},
	"drill": {"frames": [15, 16, 17], "px": 2.0, "size": Vector2(30, 30), "hp": 1, "speed": 45.0, "no_stomp": true, "fps": 12.0},
	"bigbot": {"frames": [21, 22, 23], "px": 3.0, "size": Vector2(52, 50), "hp": 4, "speed": 40.0},
	"shooter": {"frames": [4, 5], "px": 2.0, "size": Vector2(30, 36), "hp": 2, "speed": 0.0, "fps": 2.0},
	"ghost": {"fx": "ghost", "px": 1.3, "size": Vector2(32, 40), "hp": 2, "speed": 52.0, "no_stomp": true, "no_dash": true},
	"thwomp": {"frames": [11], "px": 3.0, "size": Vector2(62, 64), "solid": true},
	"spark": {"frames": [8], "px": 2.0, "size": Vector2(28, 28), "solid": true},
	"saw_h": {"fx": "saw", "px": 1.5, "size": Vector2(32, 32), "solid": true},
	"saw_v": {"fx": "saw", "px": 1.5, "size": Vector2(32, 32), "solid": true},
	"jet": {"size": Vector2(26, 104), "solid": true},
	"arc": {"size": Vector2(34, 92), "solid": true},
	"icicle": {"size": Vector2(14, 30), "solid": true},
}

var level: Node
var kind := "bot"
var hp := 1
var size := Vector2(30, 26)
var solid := false          # can't be hurt
var dir := -1
var t := 0.0
var state := "idle"
var state_t := 0.0
var home := Vector2.ZERO
var dead := false
var flash := 0.0
var squash := Vector2.ONE
var active := true          # hazards that switch on and off
var minion := false         # summoned by a boss: no coins
var vel := Vector2.ZERO

var body := Node2D.new()    # everything drawn, so it can squash and flip together
var spr: Sprite2D
var frames: Array = []
var fx_node: Sprite2D
var fps := 7.0
var chain: Array = []


func _ready() -> void:
	var info: Dictionary = INFO[kind]
	size = info["size"]
	hp = info.get("hp", 1)
	solid = info.get("solid", false)
	fps = info.get("fps", 7.0)
	home = position
	t = fmod(position.x * 0.013, 4.0)   # things in a row don't move in step
	add_child(body)
	z_index = 2
	if info.has("frames"):
		for f in info["frames"]:
			frames.append(Cast.char_tex(f))
		spr = Sprite2D.new()
		spr.texture = frames[0]
		spr.centered = false
		spr.offset = Vector2(-12, -24)
		spr.scale = Vector2(info["px"], info["px"])
		body.add_child(spr)
	elif info.has("fx"):
		fx_node = Fx.play(body, info["fx"], Vector2.ZERO, {"scale": info["px"], "z": 0})
	match kind:
		"bat":
			position.y -= 10.0
			home = position
		"thwomp":
			spr.modulate = Color(0.75, 0.85, 1.2) if level.theme == "snow" else Color(1.0, 0.75, 0.75)
			frames.append(Cast.char_tex(12))
		"spark":
			spr.offset = Vector2(-12, -12)
			spr.modulate = Color(1.3, 1.25, 0.7) if level.theme == "storm" else Color.WHITE
			for i in 4:
				var link := Polygon2D.new()
				link.polygon = PackedVector2Array([Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)])
				link.color = Color(0.25, 0.22, 0.35)
				add_child(link)
				move_child(link, 0)
				chain.append(link)
			home = position + Vector2(0, -size.y / 2.0)
		"saw_h", "saw_v":
			home = position + Vector2(0, -16.0)
			fx_node.position = Vector2(0, -16.0)
		"ghost":
			fx_node.modulate.a = 0.9
			home = position
		"jet":
			var base := Polygon2D.new()
			base.polygon = PackedVector2Array([Vector2(-12, 0), Vector2(-12, -8), Vector2(-7, -12), Vector2(7, -12), Vector2(12, -8), Vector2(12, 0)])
			base.color = Color(0.22, 0.2, 0.28)
			add_child(base)
			fx_node = Fx.play(body, "flame_jet", Vector2(0, -10), {"scale": 0.9, "rot": -PI / 2.0, "z": 0})
			fx_node.visible = false
			active = false
		"arc":
			fx_node = Fx.play(body, "arc", Vector2.ZERO, {"scale": 1.0, "z": 0})
		"icicle":
			var ice := Polygon2D.new()
			ice.polygon = PackedVector2Array([Vector2(-8, -30), Vector2(8, -30), Vector2(4, -14), Vector2(2, -14), Vector2(0, 0), Vector2(-2, -14), Vector2(-4, -14)])
			ice.color = Color(0.8, 0.95, 1.0)
			body.add_child(ice)
			var shine := Polygon2D.new()
			shine.polygon = PackedVector2Array([Vector2(-5, -29), Vector2(-2, -29), Vector2(-2, -16), Vector2(-4, -16)])
			shine.color = Color(1, 1, 1)
			body.add_child(shine)


func rect() -> Rect2:
	return Rect2(position.x - size.x / 2.0, position.y - size.y, size.x, size.y)


func center() -> Vector2:
	return position + Vector2(0, -size.y / 2.0)


func _physics_process(delta: float) -> void:
	if dead or level.done_building == false:
		return
	# sleep when far off screen
	if absf(position.x - level.cam.position.x) > 1100.0 and kind != "ghost":
		return
	t += delta
	state_t += delta
	flash -= delta
	match kind:
		"bot", "drill":
			_walk(delta, INFO[kind]["speed"])
		"bat":
			position.x = home.x + sin(t * 0.9) * 2.6 * T
			position.y = home.y + sin(t * 3.1) * 16.0
			dir = 1 if cos(t * 0.9) > 0 else -1
		"bigbot":
			_bigbot(delta)
		"shooter":
			_shooter()
		"ghost":
			_ghost(delta)
		"thwomp":
			_thwomp(delta)
		"spark":
			var a := t * 2.1
			var off := Vector2(cos(a), sin(a)) * 1.6 * T
			position = home + off + Vector2(0, size.y / 2.0)
			for i in chain.size():
				chain[i].global_position = home + off * (i / float(chain.size()))
			spr.rotation = t * 5.0
		"saw_h":
			var x := sin(t * 1.9) * 3.0 * T
			position = home + Vector2(x, 16.0)
			fx_node.scale.x = absf(fx_node.scale.x) * (1.0 if cos(t * 1.9) > 0 else -1.0)
		"saw_v":
			position = home + Vector2(0, sin(t * 1.7) * 2.5 * T + 16.0)
			fx_node.rotation = PI / 2.0 if cos(t * 1.7) > 0 else -PI / 2.0
		"jet":
			_jet()
		"arc":
			var phase := fmod(t, 2.8)
			active = phase < 1.5
			fx_node.modulate = Color.WHITE if active else Color(0.35, 0.35, 0.5, 0.6)
			fx_node.speed = 1.0 if active else 0.0
			if not active and phase > 2.4:   # flicker a warning before it comes back on
				fx_node.modulate = Color(1, 1, 1, 0.9) if fmod(t, 0.1) < 0.05 else Color(0.35, 0.35, 0.5, 0.6)
		"icicle":
			_icicle(delta)
	_animate(delta)
	if active:
		_touch_players()


func _animate(delta: float) -> void:
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-12.0 * delta))
	body.scale = squash
	if spr != null:
		if frames.size() > 1 and kind != "thwomp":
			spr.texture = frames[int(t * fps) % frames.size()]
		if kind not in ["thwomp", "spark"]:
			spr.flip_h = dir > 0
		spr.self_modulate = Color(5, 5, 5) if flash > 0.0 else Color.WHITE
	elif fx_node != null and kind == "ghost":
		fx_node.self_modulate = Color(5, 5, 5) if flash > 0.0 else Color.WHITE
		fx_node.scale.x = absf(fx_node.scale.x) * (-1.0 if dir > 0 else 1.0)


func _walk(delta: float, speed: float) -> void:
	var ahead := position.x + dir * (size.x / 2.0 + 3.0)
	if level.solid_at(Vector2(ahead, position.y - 12.0)) or not level.floor_at(Vector2(ahead, position.y + 10.0)):
		dir = -dir
	else:
		position.x += dir * speed * delta


func _nearest() -> Node2D:
	var best: Node2D = null
	for p in level.players:
		if p.dead:
			continue
		if best == null or absf(p.position.x - position.x) < absf(best.position.x - position.x):
			best = p
	return best


func _bigbot(delta: float) -> void:
	var p := _nearest()
	match state:
		"idle":
			_walk(delta, 40.0)
			if p != null and absf(p.position.x - position.x) < 6.0 * T and absf(p.position.y - position.y) < 60.0 \
					and signf(p.position.x - position.x) == dir and state_t > 1.0:
				_go("warn")
				Fx.play(level, "alert", position + Vector2(0, -size.y), {"z": 8})
				Game.sfx("tick", 0.7)
		"warn":
			squash = Vector2(1.0 + sin(state_t * 60.0) * 0.06, 1.0)
			if state_t > 0.45:
				_go("charge")
				Game.sfx("dash", 0.7)
		"charge":
			var before := dir
			_walk(delta, 215.0)
			if fmod(state_t, 0.08) < delta:
				Fx.burst(level, position, 2, Color(0.9, 0.9, 0.9, 0.8), 60.0, Vector2(-dir, -0.5), 30.0, 100.0, 5.0, 0.35)
			if dir != before or state_t > 1.4:
				if dir != before:
					level.shake(4.0)
					Game.sfx("land")
				_go("rest")
		"rest":
			if state_t > 0.9:
				_go("idle")
		"hurt":
			if state_t > 0.35:
				_go("idle")


func _shooter() -> void:
	var p := _nearest()
	if p != null:
		dir = 1 if p.position.x > position.x else -1
	match state:
		"idle":
			if state_t > 1.7 and p != null and absf(p.position.x - position.x) < 15.0 * T and absf(p.position.y - position.y) < 4.0 * T:
				_go("warn")
		"warn":
			flash = 0.05 if fmod(state_t, 0.12) < 0.06 else 0.0
			if state_t > 0.45:
				_go("idle")
				squash = Vector2(1.35, 0.75)
				level.shoot(position + Vector2(dir * 18.0, -18.0), Vector2(dir * 250.0, 0), "plasma", {"life": 4.0})
				Game.sfx("zap", 1.2, 0.7)


func _ghost(delta: float) -> void:
	var p := _nearest()
	if state == "hurt":
		position += vel * delta
		vel = vel.lerp(Vector2.ZERO, 1.0 - exp(-5.0 * delta))
		if state_t > 0.5:
			_go("idle")
		return
	if p != null and p.center().distance_to(center()) < 9.0 * T:
		var to: Vector2 = (p.center() - center()).normalized()
		position += to * INFO["ghost"]["speed"] * delta
		dir = 1 if to.x > 0 else -1
	position.y += sin(t * 3.0) * 12.0 * delta


func _thwomp(delta: float) -> void:
	match state:
		"idle":
			spr.texture = frames[0]
			var p := _nearest()
			if p != null and absf(p.position.x - position.x) < 54.0 and p.position.y > position.y - 20.0 and p.position.y < position.y + 8.0 * T:
				_go("warn")
				spr.texture = frames[1]
				Game.sfx("tick", 0.6)
		"warn":
			body.position.x = sin(state_t * 70.0) * 3.0
			if state_t > 0.32:
				body.position.x = 0.0
				_go("fall")
		"fall":
			vel.y = minf(vel.y + 3200.0 * delta, 980.0)
			position.y += vel.y * delta
			if level.solid_at(position + Vector2(0, 2.0)) or position.y > home.y + 9.0 * T:
				position.y = floorf(position.y / T) * T
				vel.y = 0.0
				squash = Vector2(1.3, 0.75)
				level.shake(7.0)
				Game.sfx("slam")
				Fx.play(level, "landing", position, {"z": 6})
				for side in [-1, 1]:
					Fx.burst(level, position, 7, Color(0.9, 0.88, 0.8), 200.0, Vector2(side, -0.3), 25.0, 300.0, 5.0, 0.4)
				_go("rest")
		"rest":
			if state_t > 0.7:
				spr.texture = frames[0]
				_go("rise")
		"rise":
			position.y = maxf(position.y - 130.0 * delta, home.y)
			if position.y <= home.y:
				_go("idle")


func _jet() -> void:
	var phase := fmod(t, 3.0)
	if phase < 1.3:
		if active:
			active = false
			fx_node.visible = false
	elif phase < 1.8:
		if fmod(t, 0.12) < 0.02:
			Fx.burst(level, position + Vector2(0, -12), 2, Color(1.0, 0.7, 0.2), 90.0, Vector2.UP, 25.0, 100.0, 4.0, 0.3)
	elif not active:
		active = true
		fx_node.visible = true
		fx_node.t = 0.0
		if absf(position.x - level.cam.position.x) < 700.0:
			Game.sfx("whoosh", 0.7, 0.35)
	if active:
		fx_node.scale.x = 0.9 * clampf((phase - 1.8) / 0.15, 0.2, 1.0)


func _icicle(delta: float) -> void:
	match state:
		"idle":
			var p := _nearest()
			if p != null and absf(p.position.x - position.x) < 30.0 and p.position.y > position.y and p.position.y < position.y + 9.0 * T:
				_go("warn")
		"warn":
			body.position.x = sin(state_t * 60.0) * 2.0
			if state_t > 0.38:
				body.position.x = 0.0
				vel = Vector2.ZERO
				_go("fall")
		"fall":
			vel.y = minf(vel.y + 1800.0 * delta, 900.0)
			position.y += vel.y * delta
			if level.solid_at(position) or level.floor_at(position) or position.y > home.y + 14.0 * T:
				Fx.burst(level, position, 10, Color(0.85, 0.95, 1.0), 170.0, Vector2.UP, 80.0, 500.0, 5.0, 0.45)
				Game.sfx("break", 1.5, 0.5)
				visible = false
				active = false
				_go("gone")
		"gone":
			if state_t > 3.5:
				position = home
				visible = true
				active = true
				modulate.a = 0.0
				create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
				_go("idle")


func _go(s: String) -> void:
	state = s
	state_t = 0.0


func _touch_players() -> void:
	var r := rect()
	for p in level.players:
		if p.dead or not r.intersects(p.rect()):
			continue
		if solid:
			p.hurt(position.x)
			continue
		if p.star > 0.0:
			hit(99, p.facing, "star")
			return
		var above: bool = p.velocity.y > 0.0 and p.position.y < position.y - size.y * 0.4
		if above and not INFO[kind].get("no_stomp", false):
			var pound: bool = p.pounding
			p.bounce(p.STOMP_VELOCITY, "stomp")
			Fx.play(level, "pow", center(), {"z": 8, "scale": 0.6, "speed": 1.4})
			hit(2 if pound else 1, 0, "stomp")
			return
		if p.dash_time > 0.0 and not INFO[kind].get("no_dash", false):
			p.invuln = maxf(p.invuln, 0.2)
			hit(1, p.facing, "dash")
			return
		p.hurt(position.x)


## Take a hit. Returns true if it landed (false = it bounced off).
func hit(dmg: int, from_dir: int, how: String) -> bool:
	if dead:
		return false
	if solid:
		if how != "pound" and kind != "jet" and kind != "arc":
			Fx.play(level, "hit", center(), {"z": 8, "scale": 0.6, "tint": Color(0.7, 0.8, 1.0)})
			Game.sfx("tick", 1.6, 0.6)
		return false
	hp -= dmg
	flash = 0.1
	squash = Vector2(1.4, 0.65)
	Fx.play(level, "crit" if how == "final" else "hit", center(), {"z": 8, "flip": from_dir < 0, "scale": 0.8 if how == "final" else 1.0})
	Game.sfx("hit", randf_range(0.9, 1.1))
	if hp <= 0:
		die(from_dir)
		return true
	if kind == "ghost":
		vel = Vector2(from_dir * 260.0, -60.0)
		_go("hurt")
	elif kind == "bigbot":
		_go("hurt")
	return true


func die(from_dir: int = 0) -> void:
	dead = true
	Fx.play(level, "poof", position, {"z": 7})
	Fx.burst(level, center(), 10, Color(1, 0.95, 0.7), 200.0, Vector2(from_dir * 0.6, -1.0), 70.0, 500.0, 5.0, 0.5)
	Game.sfx("stomp", randf_range(0.95, 1.1))
	level.enemy_died(self)
	# fly off spinning
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position", position + Vector2(from_dir * 70.0, -50.0), 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", from_dir * 3.0 + 0.5, 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)

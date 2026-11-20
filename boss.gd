extends Node2D
## The five bosses. One script, `kind` picks the fight:
##   clank  Captain Clank      charges (stun him on the wall) and jump-slams
##   drill  The Drill Sergeant burrows and erupts under you, spins across the floor
##   block  Blockhead the Cold hovers, slams down in a burst of ice, rains ice lances
##   flap   Baron von Flap     swoops, throws plasma, calls lightning, then tires
##   king   King Bear          two phases: brawler, then crystal-powered
## Every attack is telegraphed. Stomps, claws, dashes and ground pounds all hurt a boss
## unless the fight says otherwise. The node's origin is the bottom-centre of the boss.

const Cast := preload("res://cast.gd")
const EnemyScript := preload("res://enemy.gd")
const T := 36.0

const INFO := {
	"clank": {"who": "CAPTAIN CLANK", "name": "CAPTAIN CLANK", "title": "KEEPER OF THE HILL SHARD",
		"hp": 26, "px": 5.0, "size": Vector2(88, 84), "frames": [21, 22, 23],
		"intro": [["CAPTAIN CLANK", "BZZT! HALT, SMALL BEAR. THESE HILLS BELONG TO KING BEAR NOW."],
			["BUNTY", "Give back the crystal shard, you big tin can!"],
			["CAPTAIN CLANK", "NEGATIVE. PREPARE TO BE FLATTENED."]],
		"outro": [["CAPTAIN CLANK", "SYSTEM... FAILURE... BEAR... TOO... BOUNCY..."],
			["BUNTY", "One shard down. Four to go!"]]},
	"drill": {"who": "DRILL SERGEANT", "name": "THE DRILL SERGEANT", "title": "KEEPER OF THE DUNE SHARD",
		"hp": 28, "px": 5.0, "size": Vector2(80, 86), "frames": [15, 16, 17], "no_stomp": true,
		"intro": [["DRILL SERGEANT", "ATTEN-SHUN! Nobody crosses MY desert without digging a hundred holes!"],
			["BUNTY", "I'm not here to dig. I'm here for the shard."],
			["DRILL SERGEANT", "Then I'll drill some manners into you, cadet!"]],
		"outro": [["DRILL SERGEANT", "Urgh... dis... missed..."],
			["BUNTY", "Two shards! The mushrooms are perking up already."]]},
	"block": {"who": "BLOCKHEAD", "name": "BLOCKHEAD THE COLD", "title": "KEEPER OF THE FROST SHARD",
		"hp": 30, "px": 5.0, "size": Vector2(104, 104), "frames": [11, 12], "hover": true,
		"intro": [["BLOCKHEAD", "..."],
			["BUNTY", "Um. Hello? Are you the boss here?"],
			["BLOCKHEAD", "BLOCKHEAD. SQUISH. BEAR."]],
		"outro": [["BLOCKHEAD", "BLOCKHEAD... MELT..."],
			["BUNTY", "Three shards. Brr! Let's get out of the cold."]]},
	"flap": {"who": "BARON VON FLAP", "name": "BARON VON FLAP", "title": "KEEPER OF THE STORM SHARD",
		"hp": 30, "px": 5.0, "size": Vector2(92, 62), "frames": [24, 25, 26, 25], "hover": true,
		"intro": [["BARON VON FLAP", "Ah, ze little bear arrives! You are trespassing in MY sky, ja?"],
			["BUNTY", "Hand over the shard and I'll bounce right out of here."],
			["BARON VON FLAP", "Nein! You shall be struck by lightning, zen struck again!"]],
		"outro": [["BARON VON FLAP", "Mein wings... I am... grounded..."],
			["BUNTY", "Four shards! Only King Bear's castle is left."]]},
	"king": {"who": "KING BEAR", "name": "KING BEAR", "title": "THIEF OF THE REBOUND CRYSTAL",
		"hp": 24, "hp2": 30, "px": 4.0, "size": Vector2(60, 80), "bear": true,
		"intro": [["KING BEAR", "HO HO HO! So the little bouncer made it to my throne room."],
			["BUNTY", "It's over, King Bear. Give back the last shard!"],
			["KING BEAR", "You beat me once, Bunty. This time the crystal's power is MINE!"]],
		"mid": [["KING BEAR", "ENOUGH! CRYSTAL... GIVE ME EVERYTHING!"]],
		"outro": [["KING BEAR", "Impossible... beaten by a bounce... again..."],
			["BUNTY", "The crystal belongs to everyone. Time to put it back!"]]},
}

var level: Node
var kind := "clank"
var info: Dictionary
var hp := 1
var max_hp := 1
var phase := 1
var active := false       # the fight is on
var dead := false
var size := Vector2(80, 80)

var state := "wait"
var state_t := 0.0
var t := 0.0
var dir := -1
var vel := Vector2.ZERO
var on_floor := true
var invuln := 0.0
var flash := 0.0
var squash := Vector2.ONE
var stunned := false
var shielded := false     # attacks clink off
var harmless := false     # touching the boss doesn't hurt right now
var attack_n := 0
var bounces := 0
var floor_y := 12.0 * T
var left_x := T + 60.0
var right_x := 33.0 * T - 60.0
var hover_y := 0.0
var swoop_from := Vector2.ZERO
var mark_x := 0.0

var actor: Node2D
var spr: Sprite2D
var frames: Array = []
var stars: Sprite2D
var aura: Sprite2D
var hidden_t := 0.0


func _ready() -> void:
	info = INFO[kind]
	size = info["size"]
	max_hp = info["hp"]
	hp = max_hp
	hover_y = floor_y - 6.6 * T
	left_x = T + size.x / 2.0 + 6.0
	right_x = 33.0 * T - size.x / 2.0 - 6.0
	actor = Cast.actor(info["who"], info["px"])
	spr = actor.get_node("spr")
	add_child(actor)
	for f in info.get("frames", []):
		frames.append(Cast.char_tex(f))
	z_index = 2


func rect() -> Rect2:
	return Rect2(position.x - size.x / 2.0, position.y - size.y, size.x, size.y)


func center() -> Vector2:
	return position + Vector2(0, -size.y / 2.0)


func start_fight() -> void:
	active = true
	_go("idle")


func _go(s: String) -> void:
	state = s
	state_t = 0.0


func _target() -> Node2D:
	var best: Node2D = null
	for p in level.players:
		if p.dead:
			continue
		if best == null or absf(p.position.x - position.x) < absf(best.position.x - position.x):
			best = p
	return best


func _face(p: Node2D) -> void:
	if p != null and absf(p.position.x - position.x) > 6.0:
		dir = 1 if p.position.x > position.x else -1


func _physics_process(delta: float) -> void:
	t += delta
	state_t += delta
	invuln -= delta
	flash -= delta
	_animate(delta)
	if dead or not active:
		return
	match kind:
		"clank":
			_clank(delta)
		"drill":
			_drill(delta)
		"block":
			_block(delta)
		"flap":
			_flap(delta)
		"king":
			_king(delta)
	position.x = clampf(position.x, left_x, right_x)
	_touch_players()


func _animate(delta: float) -> void:
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-9.0 * delta))
	actor.scale = squash
	spr.flip_h = dir > 0 if not info.get("bear", false) else dir < 0
	if flash > 0.0:
		spr.self_modulate = Color(5, 5, 5)
	else:
		spr.self_modulate = Color.WHITE
	if frames.size() > 1 and kind != "block":
		var speed := 14.0 if state in ["charge", "spin", "swoop"] else 7.0
		spr.texture = frames[int(t * speed) % frames.size()]
	# walk waddle for grounded bosses
	if on_floor and state in ["idle", "walk"] and not info.get("hover", false):
		actor.rotation = sin(t * 9.0) * 0.06
	elif state != "spin" and state != "dying":
		actor.rotation = lerpf(actor.rotation, 0.0, 0.2)


func _gravity(delta: float, g: float = 1900.0) -> bool:
	## Returns true on the frame the boss lands.
	vel.y += g * delta
	position += vel * delta
	if position.y >= floor_y:
		position.y = floor_y
		var landed := not on_floor and vel.y > 0.0
		vel.y = 0.0
		on_floor = true
		return landed
	on_floor = false
	return false


func _land_fx(big: float = 1.0) -> void:
	squash = Vector2(1.35, 0.7)
	level.shake(10.0 * big)
	Game.sfx("slam")
	Fx.play(level, "slam", position, {"scale": 1.5 * big, "z": 6})
	for side in [-1, 1]:
		Fx.burst(level, position, 12, Color(0.85, 0.8, 0.72), 260.0, Vector2(side, -0.4), 25.0, 300.0, 6.0, 0.5)
	level.zone(Rect2(position.x - 100.0 * big, position.y - 46.0, 200.0 * big, 50.0), 0.0, 0.2, position.x)


func _stun(time: float) -> void:
	stunned = true
	harmless = true
	shielded = false
	_go("stunned")
	hidden_t = time
	if stars == null or not is_instance_valid(stars):
		stars = Fx.play(self, "stunned", Vector2(0, -size.y + 10.0), {"scale": 2.0, "z": 3})


func _unstun() -> void:
	stunned = false
	harmless = false
	if stars != null and is_instance_valid(stars):
		stars.queue_free()
	stars = null
	_go("idle")


func _summon(what: String, count: int) -> void:
	Game.sfx("roar", 1.2, 0.8)
	for i in count:
		var x := clampf(position.x + (i * 2 - (count - 1)) * 150.0 + dir * 120.0, 3.0 * T, 31.0 * T)
		var at := Vector2(x, floor_y if what != "bat" else floor_y - 4.0 * T)
		Fx.play(level, "summon", Vector2(x, floor_y), {"z": 6, "speed": 1.6})
		_later(0.9, func() -> void:
			if dead or not is_inside_tree():
				return
			var e: Node2D = EnemyScript.new()
			e.kind = what
			e.level = level
			e.minion = true
			e.position = at
			level.add_child(e)
			level.enemies.append(e))


# ------------------------------------------------------------------ Captain Clank

func _clank(delta: float) -> void:
	var p := _target()
	var fast := 1.0 if phase == 1 else 1.35
	match state:
		"idle":
			_gravity(delta)
			_face(p)
			position.x += dir * 62.0 * fast * delta
			if state_t > (1.5 if phase == 1 else 1.0):
				attack_n += 1
				if phase == 2 and attack_n % 4 == 0 and level.minion_count() < 2:
					_summon("bot", 2)
					_go("rest")
				elif attack_n % 2 == 1:
					_go("charge_warn")
					Fx.play(level, "alert", position + Vector2(0, -size.y), {"scale": 2.0, "z": 8})
					Game.sfx("tick", 0.6)
				else:
					_go("jump_warn")
		"charge_warn":
			_face(p)
			position.x -= dir * 40.0 * delta
			squash = Vector2(1.0 + sin(state_t * 55.0) * 0.05, 1.0)
			if state_t > 0.7 / fast:
				_go("charge")
				Game.sfx("dash", 0.6)
		"charge":
			position.x += dir * 520.0 * fast * delta
			if fmod(state_t, 0.06) < delta:
				Fx.burst(level, position, 3, Color(0.9, 0.9, 0.9, 0.8), 80.0, Vector2(-dir, -0.5), 30.0, 100.0, 6.0, 0.4)
			if position.x <= left_x or position.x >= right_x:
				level.shake(12.0)
				Game.sfx("slam", 0.8)
				Fx.play(level, "dirt_boom", position + Vector2(dir * 40.0, 0), {"z": 6, "speed": 1.5})
				vel = Vector2(-dir * 120.0, -320.0)
				on_floor = false
				_stun(2.4 if phase == 1 else 1.9)
		"jump_warn":
			squash = Vector2(1.25, 0.75)
			if state_t > 0.4:
				var dx := (p.position.x - position.x) if p != null else 0.0
				vel = Vector2(clampf(dx / 0.95, -460.0, 460.0), -900.0)
				on_floor = false
				_go("jump")
				Game.sfx("jump", 0.5)
		"jump":
			if _gravity(delta):
				vel.x = 0.0
				_land_fx()
				for side in [-1, 1]:
					level.shoot(position + Vector2(side * 50.0, -20.0), Vector2(side * 300.0, 0), "saw", {"life": 3.0, "scale": 1.5})
				if phase == 2:
					_later(0.4, func() -> void:
						if dead:
							return
						for side in [-1, 1]:
							level.shoot(position + Vector2(side * 50.0, -64.0), Vector2(side * 240.0, 0), "saw", {"life": 3.0, "scale": 1.5}))
				_go("rest")
		"rest":
			_gravity(delta)
			if state_t > 0.9 / fast:
				_go("idle")
		"stunned":
			_gravity(delta)
			vel.x = lerpf(vel.x, 0.0, 0.08)
			if state_t > hidden_t:
				_unstun()


# ------------------------------------------------------------------ The Drill Sergeant

func _drill(delta: float) -> void:
	var p := _target()
	var fast := 1.0 if phase == 1 else 1.3
	match state:
		"idle":
			_gravity(delta)
			_face(p)
			position.x += dir * 50.0 * fast * delta
			shielded = false
			if state_t > 1.3 / fast:
				attack_n += 1
				if attack_n % 2 == 1:
					_go("dig")
					Fx.play(level, "dirt_boom", position, {"z": 6, "speed": 1.5})
					Game.sfx("break", 0.6)
				else:
					_go("spin_warn")
					Fx.play(level, "alert", position + Vector2(0, -size.y), {"scale": 2.0, "z": 8})
		"dig":
			actor.position.y = minf(state_t / 0.45, 1.0) * size.y * 1.1
			harmless = true
			shielded = true
			if state_t > 0.5:
				actor.visible = false
				_go("under")
		"under":
			if p != null:
				position.x = move_toward(position.x, p.position.x, 260.0 * fast * delta)
			if fmod(state_t, 0.07) < delta:
				Fx.burst(level, Vector2(position.x, floor_y), 4, Color(0.85, 0.7, 0.45), 150.0, Vector2.UP, 40.0, 500.0, 6.0, 0.35)
			if fmod(state_t, 0.25) < delta:
				level.shake(2.0)
			if state_t > 1.7 / fast:
				mark_x = position.x
				_go("erupt_warn")
				Fx.play(level, "quake", Vector2(mark_x, floor_y), {"z": 6, "speed": 1.6})
				Game.sfx("tick", 0.5)
		"erupt_warn":
			if state_t > 0.5:
				actor.visible = true
				actor.position.y = 0.0
				harmless = false
				shielded = false
				position = Vector2(mark_x, floor_y)
				vel = Vector2(0, -1050.0)
				on_floor = false
				Fx.play(level, "earth_spike", Vector2(mark_x, floor_y), {"scale": 1.6, "z": 1, "speed": 1.8})
				Fx.play(level, "dirt_boom", Vector2(mark_x, floor_y), {"scale": 1.3, "z": 6, "speed": 1.4})
				level.zone(Rect2(mark_x - 50.0, floor_y - 170.0, 100.0, 170.0), 0.0, 0.3, mark_x)
				level.shake(11.0)
				Game.sfx("slam", 1.2)
				if phase == 2:
					for i in 3:
						var x := clampf(mark_x + [-190.0, 190.0, 0.0][i] + randf_range(-40, 40), 2.5 * T, 31.5 * T)
						_spike(x, 0.5 + i * 0.35)
				_go("erupt")
		"erupt":
			if _gravity(delta):
				_land_fx(0.8)
				_stun(2.2 if phase == 1 else 1.7)
		"spin_warn":
			actor.rotation += delta * (6.0 + state_t * 40.0)
			if state_t > 0.6 / fast:
				_go("spin")
				_face(p)
				bounces = 0
				shielded = true
				Game.sfx("dash", 0.7)
		"spin":
			actor.rotation += delta * 30.0
			position.x += dir * 400.0 * fast * delta
			if fmod(state_t, 0.05) < delta:
				Fx.burst(level, position, 3, Color(0.85, 0.7, 0.45), 120.0, Vector2(-dir, -0.6), 30.0, 300.0, 6.0, 0.35)
			if position.x <= left_x or position.x >= right_x:
				dir = -dir
				bounces += 1
				level.shake(6.0)
				Game.sfx("land")
				if bounces >= (2 if phase == 1 else 3):
					shielded = false
					actor.rotation = 0.0
					_stun(1.5)
		"stunned":
			_gravity(delta)
			if state_t > hidden_t:
				_unstun()


## A stone spike bursts out of the floor at x after a warning glow.
func _spike(x: float, delay: float) -> void:
	_later(delay, func() -> void:
		if dead or not is_inside_tree():
			return
		Fx.play(level, "earth_spike", Vector2(x, floor_y), {"scale": 1.3, "z": 4, "speed": 1.2})
		level.zone(Rect2(x - 30.0, floor_y - 90.0, 60.0, 90.0), 0.48, 0.9, x))


# ------------------------------------------------------------------ Blockhead the Cold

func _block(delta: float) -> void:
	var p := _target()
	var fast := 1.0 if phase == 1 else 1.35
	match state:
		"idle":
			spr.texture = frames[0]
			harmless = false
			position.y = move_toward(position.y, hover_y + sin(t * 3.0) * 8.0, 400.0 * delta)
			if p != null:
				position.x = move_toward(position.x, p.position.x, 175.0 * fast * delta)
			if state_t > 1.5 / fast and absf(position.y - hover_y) < 20.0:
				attack_n += 1
				if attack_n % 3 == 0:
					_go("rain_move")
				else:
					bounces = 0
					_go("slam_warn")
					Game.sfx("tick", 0.5)
		"slam_warn":
			spr.texture = frames[1]
			actor.position.x = sin(state_t * 70.0) * 4.0
			if state_t > 0.45 / fast:
				actor.position.x = 0.0
				vel = Vector2(0, 300.0)
				_go("slam")
		"slam":
			vel.y = minf(vel.y + 4200.0 * delta, 1500.0)
			position.y += vel.y * delta
			if position.y >= floor_y:
				position.y = floor_y
				_land_fx(1.15)
				for side in [-1, 1]:
					Fx.play(level, "ice_spikes", position + Vector2(side * 40.0, 0), {"flip": side < 0, "scale": 1.3, "z": 4, "speed": 1.3})
					var x0: float = position.x + side * 40.0
					level.zone(Rect2(minf(x0, x0 + side * 310.0), floor_y - 56.0, 310.0, 56.0), 0.22, 0.85, position.x)
				bounces += 1
				_go("grounded")
		"grounded":
			spr.texture = frames[0]
			harmless = state_t > 0.25
			if phase == 2 and bounces < 2 and state_t > 0.55:
				_go("hop_up")
			elif state_t > (2.3 if phase == 1 else 1.8):
				_go("idle")
		"hop_up":
			harmless = false
			position.y = move_toward(position.y, hover_y, 520.0 * delta)
			if p != null:
				position.x = move_toward(position.x, p.position.x, 260.0 * delta)
			if absf(position.y - hover_y) < 4.0:
				_go("slam_warn")
		"rain_move":
			position.y = move_toward(position.y, hover_y - 40.0, 300.0 * delta)
			position.x = move_toward(position.x, 17.0 * T, 420.0 * delta)
			if absf(position.x - 17.0 * T) < 6.0:
				_go("rain")
				spr.texture = frames[1]
				bounces = 0
				Game.sfx("roar", 1.4, 0.7)
		"rain":
			actor.position.x = sin(state_t * 50.0) * 3.0
			var every := 0.3 / fast
			if state_t > bounces * every:
				# lances sweep across the arena, leaving a gap to stand in
				var n := 9
				var gap := (attack_n / 3) % 3
				var i := bounces % n
				if i % 3 != gap:
					var x := 3.0 * T + i * 3.4 * T
					level.shoot(Vector2(x, floor_y - 11.5 * T), Vector2(0, 470.0), "ice_lance", {"life": 3.0, "rot": PI / 2.0, "radius": 13.0})
				bounces += 1
			if bounces >= 18:
				actor.position.x = 0.0
				_go("idle")


# ------------------------------------------------------------------ Baron von Flap

func _flap(delta: float) -> void:
	var p := _target()
	var fast := 1.0 if phase == 1 else 1.3
	var top := floor_y - 7.6 * T
	match state:
		"idle":
			harmless = false
			var want := Vector2(17.0 * T + sin(t * 0.9) * 9.0 * T, top + sin(t * 2.2) * 30.0)
			position = position.lerp(want, 1.0 - exp(-2.5 * delta))
			_face(p)
			if state_t > 1.7 / fast:
				attack_n += 1
				match attack_n % 3:
					1:
						_go("swoop_warn")
						swoop_from = Vector2(left_x + 30.0 if position.x < 17.0 * T else right_x - 30.0, top)
						Fx.play(level, "alert", position + Vector2(0, -size.y), {"scale": 2.0, "z": 8, "follow": self, "follow_offset": Vector2(0, -size.y)})
						Game.sfx("tick", 0.8)
					2:
						_go("orbs")
						bounces = 0
					0:
						_go("lightning")
						bounces = 0
						Fx.play(level, "charge", center(), {"z": 6, "speed": 1.6, "follow": self, "follow_offset": Vector2(0, -size.y / 2.0)})
						Game.sfx("zap", 0.6)
		"swoop_warn":
			position = position.lerp(swoop_from, 1.0 - exp(-6.0 * delta))
			dir = 1 if swoop_from.x < 17.0 * T else -1
			if state_t > 0.75 / fast:
				_go("swoop")
				Game.sfx("whoosh", 0.8)
		"swoop":
			var k := state_t / (1.5 / fast)
			var x0: float = swoop_from.x
			var x1: float = right_x - 30.0 if x0 < 17.0 * T else left_x + 30.0
			position.x = lerpf(x0, x1, k)
			position.y = lerpf(top, floor_y - 6.0, sin(k * PI))
			if fmod(state_t, 0.05) < delta:
				Fx.burst(level, center(), 2, Color(0.8, 0.7, 1.0, 0.8), 60.0, Vector2(-dir, 0), 30.0, 0.0, 6.0, 0.35)
			if k >= 1.0:
				_go("idle")
		"orbs":
			position.y = move_toward(position.y, top + 20.0, 200.0 * delta)
			_face(p)
			var shots := 3 if phase == 1 else 5
			if state_t > 0.4 + bounces * (0.42 / fast) and bounces < shots:
				bounces += 1
				squash = Vector2(1.3, 0.75)
				if p != null:
					var from: Vector2 = center() + Vector2(dir * 30.0, 10.0)
					var aim: Vector2 = (p.center() - from).normalized().rotated(randf_range(-0.12, 0.12))
					level.shoot(from, aim * 300.0, "plasma", {"life": 4.0, "rot": aim.angle()})
					Game.sfx("zap", 1.3, 0.7)
			if bounces >= shots and state_t > 0.4 + shots * 0.42 / fast + 0.5:
				_go("idle")
		"lightning":
			position = position.lerp(Vector2(17.0 * T, top - 20.0), 1.0 - exp(-3.0 * delta))
			var bolts := 3 if phase == 1 else 6
			if state_t > 0.7 + bounces * 0.5 / fast and bounces < bolts:
				var x := (p.position.x if p != null else 17.0 * T) + (0.0 if bounces % 2 == 0 else randf_range(-170, 170))
				x = clampf(x, 2.0 * T, 32.0 * T)
				Fx.play(level, "bolt", Vector2(x, floor_y), {"scale": 1.3, "z": 6})
				level.zone(Rect2(x - 26.0, floor_y - 330.0, 52.0, 330.0), 0.76, 1.25, x)
				_later(0.78, func() -> void:
					level.shake(6.0)
					level.flash_screen(Color(1, 1, 1, 0.35))
					Game.sfx("zap", 0.8))
				bounces += 1
			if bounces >= bolts and state_t > 0.7 + bolts * 0.5 / fast + 1.2:
				_go("tired")
				harmless = true
				stunned = true
				stars = Fx.play(self, "stunned", Vector2(0, -size.y + 10.0), {"scale": 2.0, "z": 3})
		"tired":
			position = position.lerp(Vector2(position.x, floor_y - 4.0), 1.0 - exp(-3.0 * delta))
			if state_t > (3.0 if phase == 1 else 2.4):
				stunned = false
				harmless = false
				if stars != null and is_instance_valid(stars):
					stars.queue_free()
				_go("idle")


# ------------------------------------------------------------------ King Bear

func _king(delta: float) -> void:
	var p := _target()
	var fast := 1.0 if phase == 1 else 1.3
	match state:
		"idle":
			_gravity(delta)
			_face(p)
			position.x += dir * 85.0 * fast * delta
			if state_t > 0.5 and p != null and absf(p.position.x - position.x) < 120.0 and absf(p.position.y - position.y) < 90.0:
				_go("claw_warn")
				Game.sfx("tick", 0.7)
			elif state_t > (1.6 if phase == 1 else 1.1):
				attack_n += 1
				var pick := attack_n % (3 if phase == 1 else 4)
				if pick == 0 and level.minion_count() < 2:
					_summon("bot" if phase == 1 else "bat", 2)
					_go("rest")
				elif pick == 1 or phase == 1:
					_go("jump_warn")
				elif pick == 2:
					_go("dash_warn")
					Fx.play(level, "alert", position + Vector2(0, -size.y), {"scale": 2.0, "z": 8})
					Game.sfx("tick", 0.6)
				else:
					_go("meteors")
					bounces = 0
					Fx.play(level, "charge", center(), {"z": 6, "speed": 1.6, "tint": Color(1.2, 0.6, 1.4)})
					Game.sfx("roar", 0.8)
		"claw_warn":
			squash = Vector2(0.85, 1.2)
			if state_t > 0.42 / fast:
				_go("claw")
				squash = Vector2(1.4, 0.8)
				Fx.play(level, "boss_claw", position, {"flip": dir < 0, "scale": 1.5, "z": 7, "speed": 1.7})
				var x0 := position.x if dir > 0 else position.x - 170.0
				level.zone(Rect2(x0, position.y - 130.0, 170.0, 136.0), 0.12, 0.34, position.x)
				Game.sfx("slash", 0.6)
		"claw":
			_gravity(delta)
			if state_t > 0.2 and state_t < 0.3:
				position.x += dir * 220.0 * delta
			if state_t > 0.8 / fast:
				_go("idle")
		"jump_warn":
			squash = Vector2(1.25, 0.75)
			if state_t > 0.38:
				var dx := (p.position.x - position.x) if p != null else 0.0
				vel = Vector2(clampf(dx / 0.95, -500.0, 500.0), -900.0)
				on_floor = false
				_go("jump")
				Game.sfx("jump", 0.5)
		"jump":
			if _gravity(delta):
				vel.x = 0.0
				_land_fx()
				if phase == 1:
					for side in [-1, 1]:
						level.shoot(position + Vector2(side * 40.0, -18.0), Vector2(side * 290.0, 0), "fireball", {"life": 3.0})
				else:
					for i in 4:
						var x := clampf(position.x + [-1, 1, -2, 2][i] * 190.0, 2.5 * T, 31.5 * T)
						_pillar(x, 0.15 + (i / 2) * 0.35)
				_go("rest")
		"dash_warn":
			_face(p)
			position.x -= dir * 50.0 * delta
			squash = Vector2(1.0 + sin(state_t * 55.0) * 0.05, 1.0)
			if state_t > 0.6:
				_go("dash")
				Game.sfx("dash", 0.6)
		"dash":
			position.x += dir * 640.0 * delta
			if fmod(state_t, 0.04) < delta:
				_afterimage()
			if position.x <= left_x or position.x >= right_x or state_t > 1.4:
				level.shake(8.0)
				Game.sfx("land")
				_go("rest")
		"meteors":
			_gravity(delta)
			squash = Vector2(1.0 + sin(state_t * 40.0) * 0.04, 1.0)
			if state_t > 0.6 + bounces * 0.45 and bounces < 5:
				var x := (p.position.x if p != null else 17.0 * T) + randf_range(-120, 120) * (bounces % 2)
				x = clampf(x, 2.5 * T, 31.5 * T)
				Fx.play(level, "meteor", Vector2(x, floor_y), {"scale": 1.3, "z": 6, "speed": 1.0})
				Fx.play(level, "rune", Vector2(x, floor_y), {"z": 1, "loop": false, "speed": 4.4, "tint": Color(1.5, 0.6, 0.4)})
				level.zone(Rect2(x - 62.0, floor_y - 110.0, 124.0, 110.0), 0.86, 1.25, x)
				_later(0.9, func() -> void:
					level.shake(7.0)
					Game.sfx("explosion", 1.1, 0.8))
				bounces += 1
			if bounces >= 5 and state_t > 0.6 + 5 * 0.45 + 0.6:
				_go("idle")
		"rest":
			_gravity(delta)
			if state_t > 0.8 / fast:
				_go("idle")


func _pillar(x: float, delay: float) -> void:
	_later(delay, func() -> void:
		if dead or not is_inside_tree():
			return
		Fx.play(level, "flame_pillar", Vector2(x, floor_y), {"scale": 1.2, "z": 6, "speed": 1.3})
		level.zone(Rect2(x - 26.0, floor_y - 250.0, 52.0, 250.0), 0.62, 1.7, x))


## Run something a bit later. Tied to this node, so it is dropped if the boss is gone.
func _later(delay: float, action: Callable) -> void:
	create_tween().tween_callback(action).set_delay(delay)


func _afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = spr.texture
	ghost.centered = false
	ghost.offset = spr.offset
	ghost.flip_h = spr.flip_h
	ghost.scale = spr.scale
	ghost.position = position
	ghost.modulate = Color(1.2, 0.5, 1.6, 0.6)
	ghost.z_index = 1
	level.add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ghost.queue_free)


# ------------------------------------------------------------------ getting hit

func _touch_players() -> void:
	if not actor.visible:
		return
	var r := rect()
	for p in level.players:
		if p.dead or not r.intersects(p.rect()):
			continue
		var above: bool = p.velocity.y > 0.0 and p.position.y < position.y - size.y * 0.55
		var spiky: bool = info.get("no_stomp", false) and not stunned
		if above and not spiky and not shielded:
			var pound: bool = p.pounding
			p.bounce(p.STOMP_VELOCITY * 1.15, "stomp")
			Fx.play(level, "pow", position + Vector2(0, -size.y), {"z": 8, "scale": 0.8, "speed": 1.4})
			take(3 if pound else 1, 0, "stomp")
		elif p.dash_time > 0.0 and not shielded:
			if invuln <= 0.0:
				p.invuln = maxf(p.invuln, 0.3)
				take(1, p.facing, "dash")
		elif not harmless:
			p.hurt(position.x)


## Called by the level for claw swings and ground pounds.
func hit(dmg: int, from_dir: int, how: String) -> bool:
	if not actor.visible:
		return false
	return take(dmg, from_dir, how)


func take(dmg: int, from_dir: int, how: String) -> bool:
	if dead or not active or state == "transform":
		return false
	if shielded:
		Fx.play(level, "hit", center(), {"z": 8, "scale": 0.8, "tint": Color(0.7, 0.8, 1.0)})
		Game.sfx("tick", 1.6, 0.6)
		return false
	if invuln > 0.0:
		return false
	if stunned:
		dmg += 1      # hits on a dizzy boss count extra
	hp -= dmg
	invuln = 0.16
	flash = 0.1
	squash = Vector2(1.3, 0.75)
	var big := how == "final" or how == "pound" or dmg >= 3
	Fx.play(level, "crit" if big else "hit", center() + Vector2(randf_range(-14, 14), randf_range(-14, 14)), {"z": 8, "flip": from_dir < 0})
	Fx.burst(level, center(), 8, Color(1, 0.9, 0.4), 240.0, Vector2.UP, 160.0, 500.0, 5.0, 0.5)
	Game.sfx("boss_hit", randf_range(0.92, 1.08))
	level.shake(6.0 if big else 3.5)
	level.boss_hurt(self, dmg)
	if hp <= 0:
		if kind == "king" and phase == 1:
			hp = 1
			_transform()
		else:
			hp = 0
			dead = true
			if stars != null and is_instance_valid(stars):
				stars.queue_free()
			level.boss_defeated(self)
	elif phase == 1 and kind != "king" and hp <= max_hp / 2:
		phase = 2
		Game.sfx("roar", 1.1)
		Fx.play(level, "mana_burst", center(), {"scale": 1.6, "z": 6, "tint": Color(1.6, 0.6, 0.5)})
		level.shake(10.0)
		level.show_message("%s IS FURIOUS!" % info["name"], 1.6)
		spr.modulate = spr.modulate * Color(1.25, 0.8, 0.8)
	return true


## King Bear's second phase: he drinks in the crystal's power.
func _transform() -> void:
	_go("transform")
	harmless = true
	stunned = false
	vel = Vector2.ZERO
	level.king_transform(self)


func powered_up() -> void:
	phase = 2
	max_hp = info["hp2"]
	hp = max_hp
	spr.modulate = Cast.CAST["REBOUND KING"]["tint"]
	aura = Fx.play(self, "shadow_flames", Vector2(0, 6), {"scale": 1.6, "z": -1, "alpha": 0.85})
	harmless = false
	_go("rest")

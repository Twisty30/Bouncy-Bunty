extends CharacterBody2D
## Bunty: run, jump, dash, wall kick, claw combos and ground pounds.

signal died

const WALK := preload("res://little-bear-walk.png")
const IDLE := preload("res://little-bear-idle.png")
const Skins := preload("res://skins.gd")
const Powers := preload("res://powers.gd")

const SPEED := 260.0
const CROUCH_SPEED := 110.0
const GROUND_ACCEL := 1800.0    # speeding up on the ground
const GROUND_FRICTION := 2300.0 # slowing down with no input
const TURN_ACCEL := 3400.0      # pushing the other way (skid)
const AIR_ACCEL := 1500.0
const AIR_DRAG := 500.0         # keep most of your momentum in the air
const OVERSPEED_DRAG := 2000.0  # bleeding off dash speed
const GRAVITY := 1400.0
const FALL_GRAVITY := 1.15      # falling is a bit heavier than rising
const APEX_GRAVITY := 0.6       # tiny hang at the top while jump is held
const MAX_FALL := 820.0
const JUMP_VELOCITY := -560.0
const JUMP_BUFFER := 0.12       # jump pressed just before landing still counts
const MUSHROOM_VELOCITY := -820.0
const SPRING_VELOCITY := -1030.0
const STOMP_VELOCITY := -500.0
const DASH_SPEED := 640.0
const DASH_TIME := 0.15
const STAR_TIME := 10.0
const WALL_SLIDE := 110.0       # fastest you slip down a wall you are pushing into
const WALL_KICK := Vector2(310, -545)
const POUND_SPEED := 1150.0
const MAX_HP := 3
const STAND := Vector2(22, 38)
const CROUCH := Vector2(22, 24)
const DUST := Color(0.96, 0.93, 0.86, 0.9)
const BOOST_SPEED := 1.45       # speed boost: top speed and acceleration
const SUPER_JUMP := 1.3         # super bounce: jumps, mushrooms and springs

var level: Node
var schemes: Array = [1]
var spawn_point := Vector2.ZERO
var frozen := false
var dead := false
var star := 0.0        # time left on the Power Star
var coins := 0
var hp := MAX_HP
var hits_taken := 0

# power-ups (lost when you fall)
var speed_t := 0.0     # speed boost time left
var super_t := 0.0     # super bounce time left
var magnet_t := 0.0    # coin magnet time left
var shield := false    # bubble that takes one hit
var air_jumps := 0     # extra jumps in the air: 1 = double jump, 2 = triple jump
var air_left := 0
var trail_speed_t := 0.0

var facing := 1
var dash_time := 0.0
var can_dash := true
var crouching := false
var bouncing := false
var coyote := 0.0
var jump_buffer := 0.0
var invuln := 0.0      # blinking, can't be hurt
var stun := 0.0        # knocked back, no control

# claws
var attack_cd := 0.0
var combo := 0
var combo_t := 0.0
var swing_t := 0.0     # the claws are out and can hit
var swing_hits: Array = []
var swing_final := false

# ground pound
var pounding := false
var pound_hang := 0.0

# walls
var sliding := false
var wall_x := 0.0      # which way the last wall pushes us (its normal)
var wall_coyote := 0.0
var lock_t := 0.0      # after a wall kick you fly away from the wall for a moment
var lock_dir := 0.0

# animation state
var squash := Vector2.ONE   # springs back to ONE every frame
var crouch_amt := 0.0
var lean := 0.0
var anim_t := 0.0
var was_on_floor := true
var trail_t := 0.0
var dust_t := 0.0
var sparkle_t := 0.0
var punch := 0.0
var flash := 0.0

var shape := RectangleShape2D.new()
var col := CollisionShape2D.new()
var sprite := AnimatedSprite2D.new()
var tag := Label.new()


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("players")
	shape.size = STAND
	col.shape = shape
	col.position.y = -STAND.y / 2
	add_child(col)

	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_frame("idle", IDLE)
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 9)
	frames.add_animation("air")   # two held poses picked by rising / falling
	frames.set_animation_speed("air", 0)
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = WALK
		a.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame("walk", a)
		if i == 1 or i == 3:
			frames.add_frame("air", a)
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = Vector2(-16.5, -32)   # feet sit on the body origin, so squash keeps them planted
	sprite.scale = Vector2(2, 2)
	add_child(sprite)
	Skins.dress(sprite)

	tag.position = Vector2(-10, -66)
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.2))
	tag.add_theme_constant_override("outline_size", 4)
	add_child(tag)
	z_index = 3


func rect() -> Rect2:
	return Rect2(position.x - 11.0, position.y - shape.size.y, 22.0, shape.size.y)


func center() -> Vector2:
	return position + Vector2(0, -shape.size.y / 2.0)


## Take damage from something at from_x. Knocks Bunty back and blinks for a moment.
func hurt(from_x: float, dmg: int = 1) -> void:
	if dead or invuln > 0.0 or star > 0.0 or frozen:
		return
	if shield:
		_pop_shield()
		return
	hp -= dmg
	hits_taken += 1
	level.player_hurt(self)
	if hp <= 0:
		die()
		return
	invuln = 1.4
	stun = 0.28
	flash = 0.14
	pounding = false
	dash_time = 0.0
	swing_t = 0.0
	var away := signf(position.x - from_x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 250.0, -330.0)
	squash = Vector2(0.7, 1.3)
	Fx.play(level, "hit", center(), {"z": 8})
	Fx.burst(level, center(), 8, Color(1, 0.4, 0.4), 160.0, Vector2.UP, 180.0, 400.0, 5.0, 0.4)
	Game.sfx("hurt")


## force = die even while blinking (used when a teammate dies, or in a pit)
func die(force: bool = false) -> void:
	if dead or (invuln > 0.0 and star <= 0.0 and hp > 0 and not force):
		return
	dead = true
	pounding = false
	dash_time = 0.0
	swing_t = 0.0
	clear_powers()
	Fx.play(level, "poof", position, {"z": 8})
	Fx.burst(level, center(), 20, Color(0.82, 0.56, 0.36), 220.0, Vector2.UP, 180.0, 700.0, 6.0, 0.7)
	_shake(7.0)
	visible = false
	Game.sfx("death")
	died.emit()
	await get_tree().create_timer(0.8, false).timeout
	if not is_inside_tree():
		return
	position = spawn_point
	velocity = Vector2.ZERO
	star = 0.0
	hp = MAX_HP
	level.player_respawned(self)
	Fx.play(level, "respawn", position, {"z": 8, "speed": 1.6})
	Game.sfx("checkpoint", 1.3, 0.7)
	await get_tree().create_timer(0.45, false).timeout
	if not is_inside_tree():
		return
	dead = false
	visible = true
	invuln = 1.5
	squash = Vector2(0.3, 1.8)   # pop back in
	_dust(8, 80.0, Vector2.UP, 90.0)


func bounce(v: float, sound: String = "bounce") -> void:
	velocity.y = v * (1.2 if star > 0.0 else 1.0) * (1.15 if super_t > 0.0 else 1.0)
	bouncing = true
	can_dash = true
	air_left = air_jumps
	pounding = false
	squash = Vector2(0.62, 1.45)
	Game.sfx(sound)


func heal(amount: int = MAX_HP) -> void:
	hp = mini(hp + amount, MAX_HP)


## A power-up bubble was popped (see powers.gd).
func power_up(kind: String) -> void:
	var t: float = Powers.POWERS[kind]["time"]
	match kind:
		"speed":
			speed_t = t
		"super":
			super_t = t
		"magnet":
			magnet_t = t
		"shield":
			shield = true
			queue_redraw()
		"jump":
			air_jumps = mini(air_jumps + 1, Powers.MAX_AIR_JUMPS)
			air_left = air_jumps


func clear_powers() -> void:
	speed_t = 0.0
	super_t = 0.0
	magnet_t = 0.0
	shield = false
	air_jumps = 0
	air_left = 0
	queue_redraw()


## Active power-ups for the HUD: [kind, text].
func powers() -> Array:
	var out: Array = []
	if speed_t > 0.0:
		out.append(["speed", str(ceili(speed_t))])
	if air_jumps > 0:
		out.append(["jump", "DOUBLE" if air_jumps == 1 else "TRIPLE"])
	if super_t > 0.0:
		out.append(["super", str(ceili(super_t))])
	if magnet_t > 0.0:
		out.append(["magnet", str(ceili(magnet_t))])
	if shield:
		out.append(["shield", ""])
	return out


func _jump_power() -> float:
	return (1.12 if star > 0.0 else 1.0) * (SUPER_JUMP if super_t > 0.0 else 1.0)


func _pop_shield() -> void:
	shield = false
	invuln = 1.0
	flash = 0.1
	queue_redraw()
	Fx.play(level, "hit", center(), {"z": 8, "tint": Color(0.6, 0.9, 1.4)})
	Fx.burst(level, center(), 16, Color(0.6, 0.85, 1.0), 220.0, Vector2.UP, 180.0, 300.0, 5.0, 0.5)
	Game.sfx("break", 1.5, 0.8)
	_shake(4.0)


func _draw() -> void:
	if shield and not dead:
		var c := Vector2(0, -shape.size.y / 2.0 - 2.0)
		var r := 30.0 + sin(anim_t * 6.0) * 1.5
		draw_circle(c, r, Color(0.5, 0.8, 1.0, 0.16))
		draw_arc(c, r, 0.0, TAU, 28, Color(0.75, 0.92, 1.0, 0.85), 3.0)
		draw_rect(Rect2(c + Vector2(-16, -20), Vector2(6, 6)), Color(1, 1, 1, 0.7))


func _physics_process(delta: float) -> void:
	invuln -= delta
	stun -= delta
	star -= delta
	attack_cd -= delta
	combo_t -= delta
	lock_t -= delta
	flash -= delta
	speed_t -= delta
	super_t -= delta
	magnet_t -= delta
	if shield:
		queue_redraw()
	sprite.visible = invuln <= 0.0 or fmod(invuln, 0.16) < 0.1
	if flash > 0.0:
		sprite.self_modulate = Color(4, 4, 4)
	elif star > 0.0:
		var hue := fmod(anim_t * 2.0, 1.0)
		sprite.self_modulate = Color.from_hsv(hue, 0.45, 1.6)
	else:
		sprite.self_modulate = Color.WHITE
	if dead:
		return

	var dir := 0.0 if (frozen or stun > 0.0) else _axis()
	if lock_t > 0.0:
		dir = lock_dir
	if dir != 0.0 and swing_t <= 0.0:
		facing = 1 if dir > 0 else -1
	var on_floor := is_on_floor()
	if on_floor:
		coyote = 0.1
		can_dash = true
		air_left = air_jumps
	else:
		coyote -= delta
	jump_buffer = JUMP_BUFFER if _just("jump") else jump_buffer - delta

	# crouch
	var want_crouch := _pressed("crouch") and on_floor and not pounding
	if crouching and not want_crouch and test_move(global_transform, Vector2(0, -15)):
		want_crouch = true
	if want_crouch != crouching:
		crouching = want_crouch
		shape.size = CROUCH if crouching else STAND
		col.position.y = -shape.size.y / 2

	# walls: slide down slowly while pushing into one, kick off it with jump
	sliding = false
	if not on_floor and is_on_wall() and not pounding:
		wall_x = get_wall_normal().x
		wall_coyote = 0.12
		if velocity.y > 0.0 and dir != 0.0 and signf(dir) == -signf(wall_x):
			sliding = true
	else:
		wall_coyote -= delta

	if stun > 0.0:
		pass
	elif pounding:
		pass
	elif jump_buffer > 0.0 and coyote > 0.0 and not crouching:
		velocity.y = JUMP_VELOCITY * _jump_power()
		coyote = 0.0
		jump_buffer = 0.0
		squash = Vector2(0.7, 1.35)
		_dust(6, 70.0, Vector2.UP, 75.0)
		Game.sfx("jump")
	elif jump_buffer > 0.0 and wall_coyote > 0.0 and not on_floor:
		velocity = Vector2(wall_x * WALL_KICK.x, WALL_KICK.y * (1.1 if super_t > 0.0 else 1.0))
		air_left = air_jumps
		lock_t = 0.15
		lock_dir = wall_x
		facing = 1 if wall_x > 0 else -1
		wall_coyote = 0.0
		jump_buffer = 0.0
		can_dash = true
		bouncing = false
		squash = Vector2(0.7, 1.35)
		Fx.burst(level, position + Vector2(-wall_x * 10.0, -18), 6, DUST, 90.0, Vector2(wall_x, -0.3), 50.0, 150.0, 4.0, 0.35)
		Game.sfx("jump", 1.25)
	elif jump_buffer > 0.0 and air_left > 0 and not on_floor and not crouching and dash_time <= 0.0:
		# double / triple jump from the EXTRA JUMP power-up
		velocity.y = JUMP_VELOCITY * 0.95 * _jump_power()
		air_left -= 1
		jump_buffer = 0.0
		bouncing = false
		squash = Vector2(0.65, 1.4)
		Fx.play(level, "poof", position + Vector2(0, 6), {"z": 2, "scale": 0.6, "alpha": 0.8, "speed": 1.6})
		Fx.burst(level, position, 10, Color(0.85, 0.95, 1.0, 0.95), 140.0, Vector2.DOWN, 70.0, 150.0, 4.0, 0.35)
		Game.sfx("jump", 1.3 + 0.15 * (air_jumps - air_left))
	elif _just("dash") and can_dash and not crouching:
		dash_time = DASH_TIME
		trail_t = 0.0
		can_dash = false
		bouncing = false
		lock_t = 0.0
		squash = Vector2(1.4, 0.72)
		_dust(7, 120.0, Vector2(-facing, -0.3), 30.0)
		_shake(2.0)
		Game.sfx("dash")

	if stun <= 0.0 and not frozen:
		if _just("attack") and attack_cd <= 0.0 and not crouching and not pounding:
			_attack(on_floor)
		if _just("crouch") and not on_floor and not pounding and dash_time <= 0.0 and coyote <= 0.0:
			pounding = true
			pound_hang = 0.13
			swing_t = 0.0
			velocity = Vector2.ZERO
			squash = Vector2(1.3, 0.7)
			Game.sfx("whoosh", 1.4, 0.7)

	if pounding:
		pound_hang -= delta
		velocity = Vector2.ZERO if pound_hang > 0.0 else Vector2(0, POUND_SPEED)
		trail_t -= delta
		if pound_hang <= 0.0 and trail_t <= 0.0:
			trail_t = 0.03
			_afterimage(Color(1.6, 1.2, 0.6))
	elif dash_time > 0.0:
		dash_time -= delta
		velocity = Vector2(facing * DASH_SPEED, 0)
		trail_t -= delta
		if trail_t <= 0.0:
			trail_t = 0.025
			_afterimage(Color(0.7, 0.9, 1.6))
	else:
		var g := GRAVITY
		if velocity.y < 0 and not bouncing and not _pressed("jump") and stun <= 0.0:
			g *= 2.3  # let go of jump = shorter hop
		elif absf(velocity.y) < 70.0 and _pressed("jump"):
			g *= APEX_GRAVITY
		elif velocity.y > 0:
			g *= FALL_GRAVITY
		if velocity.y >= 0:
			bouncing = false
		velocity.y = minf(velocity.y + g * delta, MAX_FALL)
		if sliding:
			velocity.y = minf(velocity.y, WALL_SLIDE)
			dust_t -= delta
			if dust_t <= 0.0:
				dust_t = 0.08
				Fx.burst(level, position + Vector2(-wall_x * 11.0, -30), 1, DUST, 30.0, Vector2.UP, 40.0, 60.0, 4.0, 0.35)

		var icy: bool = level.slippery and on_floor
		var boost := BOOST_SPEED if speed_t > 0.0 else 1.0
		var run := SPEED * boost
		var top := CROUCH_SPEED if crouching else run
		var target := dir * top
		var rate: float
		if stun > 0.0:
			rate = 200.0
			target = velocity.x
		elif absf(velocity.x) > run:
			rate = OVERSPEED_DRAG * (0.4 if icy else 1.0)
		elif on_floor:
			if dir == 0.0:
				rate = GROUND_FRICTION * (0.1 if icy else 1.0)
			elif velocity.x != 0.0 and signf(velocity.x) != signf(dir):
				rate = TURN_ACCEL * (0.25 if icy else 1.0)
				_skid_dust(delta)
			else:
				rate = GROUND_ACCEL * (0.5 if icy else 1.0) * boost
		else:
			rate = (AIR_ACCEL * boost) if dir != 0.0 else AIR_DRAG
		velocity.x = move_toward(velocity.x, target, rate * delta)

	if _just("interact"):
		level.interact(self)

	var fall_speed := velocity.y
	var was_pounding := pounding
	move_and_slide()
	on_floor = is_on_floor()

	if swing_t > 0.0:
		swing_t -= delta
		_swing()

	if on_floor and not was_on_floor and fall_speed > 0.0 and not was_pounding:
		_land(fall_speed)

	# what did we land on? mushrooms bounce, crumbling blocks start to fall
	if on_floor:
		var bounced := false
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var body := c.get_collider()
			if body == null or c.get_normal().y > -0.7:
				continue
			if body.has_meta("bouncy") and fall_speed > 0.0 and not bounced:
				bounce(MUSHROOM_VELOCITY * (1.15 if was_pounding else 1.0))
				level.mushroom_bounced(body, position)
				bounced = true
			elif body.has_meta("crumble"):
				body.get_meta("crumble").call()
		if was_pounding and not bounced:
			_pound_land()
	was_on_floor = on_floor

	_animate(delta, dir, on_floor)


func _attack(on_floor: bool) -> void:
	combo = combo + 1 if (combo_t > 0.0 and combo < 3) else 1
	combo_t = 0.6
	swing_final = combo == 3
	attack_cd = 0.38 if swing_final else 0.2
	swing_t = 0.15
	swing_hits = []
	punch = 16.0 if swing_final else 11.0
	squash = Vector2(1.3, 0.8)
	if on_floor and not level.slippery:
		velocity.x += facing * (170.0 if swing_final else 80.0)
	var fx: String = ["claw", "uppercut", "xslash"][combo - 1]
	Fx.play(level, fx, position, {"flip": facing < 0, "z": 7, "speed": 1.25, "follow": self})
	Game.sfx("slash", [1.0, 1.15, 0.85][combo - 1])
	_swing()


## Claws are out: hit everything in front that hasn't been hit by this swing yet.
func _swing() -> void:
	var reach := 66.0
	var box := Rect2(position.x - 8.0 if facing > 0 else position.x - reach + 8.0, position.y - 60.0, reach, 68.0)
	var dmg := 2 if swing_final else 1
	if star > 0.0:
		dmg += 1
	var n: int = level.strike(box, dmg, facing, self, swing_hits, "final" if swing_final else "claw")
	if n > 0:
		Game.hitstop(0.09 if swing_final else 0.045)
		_shake(5.0 if swing_final else 2.5)
		if not is_on_floor():
			velocity.y = minf(velocity.y, -230.0)   # a hit in the air holds you up
			can_dash = true


func _pound_land() -> void:
	pounding = false
	squash = Vector2(1.6, 0.55)
	velocity.y = -250.0
	_shake(7.0)
	Game.sfx("slam", 1.1)
	Fx.play(level, "landing", position, {"z": 6})
	Fx.play(level, "thud", position + Vector2(0, -6), {"z": 7})
	for side in [-1, 1]:
		Fx.burst(level, position, 8, DUST, 220.0, Vector2(side, -0.35), 25.0, 300.0, 5.0, 0.45)
	var box := Rect2(position.x - 62.0, position.y - 44.0, 124.0, 60.0)
	var n: int = level.strike(box, 3 if star > 0.0 else 2, 0, self, [], "pound")
	if n > 0:
		Game.hitstop(0.08)


func _land(speed: float) -> void:
	var k := clampf(speed / MAX_FALL, 0.0, 1.0)
	squash = Vector2(1.0 + 0.5 * k, 1.0 - 0.38 * k)
	if k > 0.3:
		_dust(4 + int(k * 8), 50.0 + 90.0 * k, Vector2.UP, 85.0)
	if k > 0.6:
		Game.sfx("land")
		_shake(k * 3.5)
		Fx.play(level, "landing", position, {"z": 2, "alpha": 0.8})


func _animate(delta: float, dir: float, on_floor: bool) -> void:
	anim_t += delta
	sprite.flip_h = facing < 0
	var breathe := 0.0
	if pounding:
		sprite.play("air")
		sprite.frame = 1
	elif dash_time > 0.0:
		sprite.play("walk")
		sprite.speed_scale = 2.5
	elif not on_floor:
		sprite.play("air")
		sprite.frame = 0 if velocity.y < 0 else 1
	elif dir != 0.0 and absf(velocity.x) > 10.0:
		sprite.play("walk")
		sprite.speed_scale = clampf(absf(velocity.x) / SPEED, 0.5, 1.6)
		dust_t -= delta
		if dust_t <= 0.0 and absf(velocity.x) > SPEED * 0.8:
			dust_t = 0.22
			_dust(2, 40.0, Vector2(-signf(velocity.x), -0.6), 40.0)
	else:
		sprite.play("idle")
		sprite.speed_scale = 1.0
		breathe = sin(anim_t * 3.0) * 0.025

	# springy squash & stretch, smooth crouch, lean into the run, lunge with the claws
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
	punch = lerpf(punch, 0.0, 1.0 - exp(-16.0 * delta))
	crouch_amt = move_toward(crouch_amt, 1.0 if crouching else 0.0, delta * 10.0)
	var base := Vector2(2.0, lerpf(2.0, 1.3, crouch_amt))
	sprite.scale = base * squash * Vector2(1.0 - breathe * 0.5, 1.0 + breathe)
	sprite.position.x = facing * punch
	var lean_to := clampf(velocity.x / SPEED, -1.2, 1.2) * (0.07 if on_floor else 0.04)
	if dash_time > 0.0:
		lean_to = facing * 0.22
	elif sliding:
		lean_to = wall_x * 0.18
	elif punch > 2.0:
		lean_to = facing * 0.25
	elif stun > 0.0:
		lean_to = -signf(velocity.x) * 0.5
	lean = lerpf(lean, lean_to, 1.0 - exp(-12.0 * delta))
	sprite.rotation = lean
	if pounding and pound_hang > 0.0:
		sprite.rotation = (0.13 - pound_hang) / 0.13 * TAU * facing

	if speed_t > 0.0 and absf(velocity.x) > SPEED and dash_time <= 0.0 and not pounding:
		trail_speed_t -= delta
		if trail_speed_t <= 0.0:
			trail_speed_t = 0.06
			_afterimage(Color(1.7, 1.1, 0.5))
	if star > 0.0:
		sparkle_t -= delta
		if sparkle_t <= 0.0:
			sparkle_t = 0.07
			var at := position + Vector2(randf_range(-14, 14), randf_range(-40, -4))
			Fx.burst(level, at, 2, Color.from_hsv(randf(), 0.5, 1.0), 30.0, Vector2.UP, 180.0, -40.0, 4.0, 0.5)


func _dust(amount: int, speed: float, dir: Vector2, spread: float) -> void:
	Fx.burst(level, position + Vector2(0, -2), amount, DUST, speed, dir, spread, 120.0, 4.0, 0.4)


func _skid_dust(delta: float) -> void:
	if absf(velocity.x) < 120.0:
		return
	dust_t -= delta
	if dust_t <= 0.0:
		dust_t = 0.05
		_dust(2, 60.0, Vector2(signf(velocity.x), -0.5), 30.0)


## A fading copy of the current frame, left behind while dashing or pounding.
func _afterimage(tint: Color) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.centered = false
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.scale = sprite.scale
	ghost.rotation = sprite.rotation
	ghost.position = position
	ghost.modulate = Color(sprite.modulate * tint, 0.55)
	ghost.z_index = 2
	level.add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ghost.queue_free)


func _shake(amount: float) -> void:
	if level != null:
		level.shake(amount)


func _pressed(action: String) -> bool:
	if frozen:
		return false
	for s in schemes:
		if Input.is_action_pressed("p%d_%s" % [s, action]):
			return true
	return false


func _just(action: String) -> bool:
	if frozen:
		return false
	for s in schemes:
		if Input.is_action_just_pressed("p%d_%s" % [s, action]):
			return true
	return false


func _axis() -> float:
	var total := 0.0
	for s in schemes:
		total += Input.get_axis("p%d_left" % s, "p%d_right" % s)
	return clampf(total, -1.0, 1.0)

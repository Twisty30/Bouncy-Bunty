extends CharacterBody2D
## bunty

signal died

const WALK := preload("res://little-bear-walk.png")
const IDLE := preload("res://little-bear-idle.png")

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
const STOMP_VELOCITY := -500.0
const DASH_SPEED := 640.0
const DASH_TIME := 0.15
const STAR_TIME := 12.0
const STAND := Vector2(22, 38)
const CROUCH := Vector2(22, 24)
const DUST := Color(0.96, 0.93, 0.86, 0.9)

var schemes: Array = [1]
var spawn_point := Vector2.ZERO
var frozen := false
var dead := false
var star := 0.0        # time left on the Bounce Star
var coins := 0

var facing := 1
var dash_time := 0.0
var can_dash := true
var crouching := false
var bouncing := false
var coyote := 0.0
var jump_buffer := 0.0
var hurt_time := 0.0

# animation state
var squash := Vector2.ONE   # springs back to ONE every frame
var crouch_amt := 0.0
var lean := 0.0
var anim_t := 0.0
var was_on_floor := true
var trail_t := 0.0
var dust_t := 0.0
var sparkle_t := 0.0

var shape := RectangleShape2D.new()
var col := CollisionShape2D.new()
var sprite := AnimatedSprite2D.new()
var area := Area2D.new()
var tag := Label.new()


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4
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

	# finds levers next to the bear
	area.collision_layer = 0
	area.collision_mask = 2
	var circle := CollisionShape2D.new()
	circle.shape = CircleShape2D.new()
	circle.shape.radius = 34
	circle.position.y = -18
	area.add_child(circle)
	add_child(area)

	tag.position = Vector2(-10, -64)
	tag.add_theme_font_size_override("font_size", 10)
	add_child(tag)


func die() -> void:
	if dead or hurt_time > 0.0:
		return
	dead = true
	Game.burst(get_parent(), position + Vector2(0, -22), 20, Color(0.82, 0.56, 0.36), 220.0, Vector2.UP, 180.0, 700.0, 6.0, 0.7)
	Game.burst(get_parent(), position + Vector2(0, -22), 10, Color.WHITE, 120.0, Vector2.UP, 180.0, 0.0, 7.0, 0.4)
	_shake(7.0)
	visible = false
	Game.sfx("death")
	died.emit()
	await get_tree().create_timer(0.7, false).timeout
	dead = false
	visible = true
	position = spawn_point
	velocity = Vector2.ZERO
	dash_time = 0.0
	star = 0.0
	hurt_time = 1.2
	squash = Vector2(0.3, 1.8)   # pop back in
	_dust(8, 80.0, Vector2.UP, 90.0)


func bounce(v: float, sound: String = "bounce") -> void:
	velocity.y = v * (1.25 if star > 0.0 else 1.0)
	bouncing = true
	can_dash = true
	squash = Vector2(0.62, 1.45)
	Game.sfx(sound)


func _physics_process(delta: float) -> void:
	hurt_time -= delta
	sprite.visible = hurt_time <= 0.0 or fmod(hurt_time, 0.16) < 0.1
	star -= delta
	# self_modulate so the per-player tint (modulate, set by the level) isn't wiped
	sprite.self_modulate = Color(1.5, 0.9, 1.6) if star > 0.0 else Color.WHITE
	if dead:
		return

	var dir := 0.0 if frozen else _axis()
	if dir != 0.0:
		facing = 1 if dir > 0 else -1
	var on_floor := is_on_floor()
	if on_floor:
		coyote = 0.1
		can_dash = true
	else:
		coyote -= delta
	jump_buffer = JUMP_BUFFER if _just("jump") else jump_buffer - delta

	# crouch
	var want_crouch := _pressed("crouch") and on_floor
	if crouching and not want_crouch and test_move(global_transform, Vector2(0, -15)):
		want_crouch = true
	if want_crouch != crouching:
		crouching = want_crouch
		shape.size = CROUCH if crouching else STAND
		col.position.y = -shape.size.y / 2

	if jump_buffer > 0.0 and coyote > 0.0 and not crouching:
		velocity.y = JUMP_VELOCITY * (1.12 if star > 0.0 else 1.0)
		coyote = 0.0
		jump_buffer = 0.0
		squash = Vector2(0.7, 1.35)
		_dust(6, 70.0, Vector2.UP, 75.0)
		Game.sfx("jump")
	elif _just("dash") and can_dash and not crouching:
		dash_time = DASH_TIME
		trail_t = 0.0
		can_dash = false
		bouncing = false
		squash = Vector2(1.4, 0.72)
		_dust(7, 120.0, Vector2(-facing, -0.3), 30.0)
		_shake(2.0)
		Game.sfx("dash")

	if dash_time > 0.0:
		dash_time -= delta
		velocity = Vector2(facing * DASH_SPEED, 0)
		trail_t -= delta
		if trail_t <= 0.0:
			trail_t = 0.025
			_afterimage()
	else:
		var g := GRAVITY
		if velocity.y < 0 and not bouncing and not _pressed("jump"):
			g *= 2.3  # let go of jump = shorter hop
		elif absf(velocity.y) < 70.0 and _pressed("jump"):
			g *= APEX_GRAVITY
		elif velocity.y > 0:
			g *= FALL_GRAVITY
		if velocity.y >= 0:
			bouncing = false
		velocity.y = minf(velocity.y + g * delta, MAX_FALL)

		var top := CROUCH_SPEED if crouching else SPEED
		var target := dir * top
		var rate: float
		if absf(velocity.x) > SPEED:
			rate = OVERSPEED_DRAG
		elif on_floor:
			if dir == 0.0:
				rate = GROUND_FRICTION
			elif velocity.x != 0.0 and signf(velocity.x) != signf(dir):
				rate = TURN_ACCEL
				_skid_dust(delta)
			else:
				rate = GROUND_ACCEL
		else:
			rate = AIR_ACCEL if dir != 0.0 else AIR_DRAG
		velocity.x = move_toward(velocity.x, target, rate * delta)

	if _just("interact"):
		for a in area.get_overlapping_areas():
			if a.has_meta("lever"):
				a.get_meta("lever").call()

	var fall_speed := velocity.y
	move_and_slide()
	on_floor = is_on_floor()

	if on_floor and not was_on_floor and fall_speed > 0.0:
		_land(fall_speed)

	# land on a mushroom = bounce
	if fall_speed > 0 and on_floor:
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if c.get_normal().y < -0.7 and c.get_collider().has_meta("bouncy"):
				bounce(MUSHROOM_VELOCITY)
				Game.burst(get_parent(), position, 10, Color(1, 0.85, 0.85), 140.0, Vector2.UP, 60.0, 400.0, 4.0, 0.45)
				break
	was_on_floor = on_floor

	_animate(delta, dir, on_floor)


func _land(speed: float) -> void:
	var k := clampf(speed / MAX_FALL, 0.0, 1.0)
	squash = Vector2(1.0 + 0.5 * k, 1.0 - 0.38 * k)
	if k > 0.3:
		_dust(4 + int(k * 8), 50.0 + 90.0 * k, Vector2.UP, 85.0)
	if k > 0.6:
		Game.sfx("land")
		_shake(k * 3.5)


func _animate(delta: float, dir: float, on_floor: bool) -> void:
	anim_t += delta
	sprite.flip_h = facing < 0
	var breathe := 0.0
	if dash_time > 0.0:
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

	# springy squash & stretch, smooth crouch, lean into the run
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
	crouch_amt = move_toward(crouch_amt, 1.0 if crouching else 0.0, delta * 10.0)
	var base := Vector2(2.0, lerpf(2.0, 1.3, crouch_amt))
	sprite.scale = base * squash * Vector2(1.0 - breathe * 0.5, 1.0 + breathe)
	var lean_to := clampf(velocity.x / SPEED, -1.2, 1.2) * (0.07 if on_floor else 0.04)
	if dash_time > 0.0:
		lean_to = facing * 0.22
	lean = lerpf(lean, lean_to, 1.0 - exp(-12.0 * delta))
	sprite.rotation = lean

	if star > 0.0:
		sparkle_t -= delta
		if sparkle_t <= 0.0:
			sparkle_t = 0.09
			var at := position + Vector2(randf_range(-14, 14), randf_range(-40, -4))
			Game.burst(get_parent(), at, 2, Color(1.0, 0.6, 1.0), 30.0, Vector2.UP, 180.0, -40.0, 3.0, 0.5)


func _dust(amount: int, speed: float, dir: Vector2, spread: float) -> void:
	Game.burst(get_parent(), position + Vector2(0, -2), amount, DUST, speed, dir, spread, 120.0, 4.0, 0.4)


func _skid_dust(delta: float) -> void:
	if absf(velocity.x) < 120.0:
		return
	dust_t -= delta
	if dust_t <= 0.0:
		dust_t = 0.05
		_dust(2, 60.0, Vector2(signf(velocity.x), -0.5), 30.0)


## A fading copy of the current frame, left behind while dashing.
func _afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.centered = false
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.scale = sprite.scale
	ghost.rotation = sprite.rotation
	ghost.position = position
	ghost.modulate = Color(sprite.modulate * Color(0.7, 0.9, 1.6), 0.55)
	ghost.z_index = -1
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ghost.queue_free)


func _shake(amount: float) -> void:
	var level := get_parent()
	if level != null and level.has_method("shake"):
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

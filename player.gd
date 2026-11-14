extends CharacterBody2D
## bunty

signal died

const WALK := preload("res://little-bear-walk.png")
const IDLE := preload("res://little-bear-idle.png")

const SPEED := 260.0
const CROUCH_SPEED := 110.0
const ACCEL := 2000.0
const GRAVITY := 1400.0
const JUMP_VELOCITY := -560.0
const MUSHROOM_VELOCITY := -820.0
const STOMP_VELOCITY := -500.0
const DASH_SPEED := 640.0
const DASH_TIME := 0.15
const STAR_TIME := 12.0
const STAND := Vector2(22, 38)
const CROUCH := Vector2(22, 24)

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
var hurt_time := 0.0

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
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = WALK
		a.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame("walk", a)
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = Vector2(-16.5, -32)
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
	visible = false
	Game.sfx("death")
	died.emit()
	await get_tree().create_timer(0.7, false).timeout
	dead = false
	visible = true
	position = spawn_point
	velocity = Vector2.ZERO
	star = 0.0
	hurt_time = 1.2


func bounce(v: float, sound: String = "bounce") -> void:
	velocity.y = v * (1.25 if star > 0.0 else 1.0)
	bouncing = true
	can_dash = true
	Game.sfx(sound)


func _physics_process(delta: float) -> void:
	hurt_time -= delta
	sprite.visible = hurt_time <= 0.0 or fmod(hurt_time, 0.16) < 0.1
	star -= delta
	sprite.modulate = Color(1.5, 0.9, 1.6) if star > 0.0 else Color.WHITE
	if dead:
		return

	var dir := 0.0 if frozen else _axis()
	if dir != 0.0:
		facing = 1 if dir > 0 else -1
	if is_on_floor():
		coyote = 0.1
		can_dash = true
	else:
		coyote -= delta

	# crouch
	var want_crouch := _pressed("crouch") and is_on_floor()
	if crouching and not want_crouch and test_move(global_transform, Vector2(0, -15)):
		want_crouch = true
	if want_crouch != crouching:
		crouching = want_crouch
		shape.size = CROUCH if crouching else STAND
		col.position.y = -shape.size.y / 2

	if _just("jump") and coyote > 0.0 and not crouching:
		velocity.y = JUMP_VELOCITY * (1.12 if star > 0.0 else 1.0)
		coyote = 0.0
		Game.sfx("jump")
	elif _just("dash") and can_dash and not crouching:
		dash_time = DASH_TIME
		can_dash = false
		bouncing = false
		Game.sfx("dash")

	if dash_time > 0.0:
		dash_time -= delta
		velocity = Vector2(facing * DASH_SPEED, 0)
	else:
		var g := GRAVITY
		if velocity.y < 0 and not bouncing and not _pressed("jump"):
			g *= 2.3  # let go of jump = shorter hop
		if velocity.y >= 0:
			bouncing = false
		velocity.y = minf(velocity.y + g * delta, 820.0)
		var target := dir * (CROUCH_SPEED if crouching else SPEED)
		velocity.x = move_toward(velocity.x, target, ACCEL * delta)

	if _just("interact"):
		for a in area.get_overlapping_areas():
			if a.has_meta("lever"):
				a.get_meta("lever").call()

	var falling := velocity.y > 0
	move_and_slide()

	# land on a mushroom = bounce
	if falling and is_on_floor():
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if c.get_normal().y < -0.7 and c.get_collider().has_meta("bouncy"):
				bounce(MUSHROOM_VELOCITY)

	sprite.flip_h = facing < 0
	sprite.play("walk" if dir != 0.0 and is_on_floor() else "idle")
	sprite.scale = Vector2(2, 1.3 if crouching else 2)


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

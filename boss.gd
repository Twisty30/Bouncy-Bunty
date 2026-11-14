extends CharacterBody2D

const BEAR := preload("res://little-bear-idle.png")

## King Bear's hitbox has to fit under the arena's floating platforms (3 tiles = 108 px
## above the ground), or he spawns wedged into them and can't move.
const SIZE := Vector2(54, 74)
const MAX_HP := 25

var level: Node
var hp := MAX_HP
var hurt := 0.0
var jump_timer := 2.0
var sprite := Sprite2D.new()
var rig := Node2D.new()      # holds sprite + crown so they squash together (origin = feet)
var squash := Vector2.ONE
var was_on_floor := true
var walk_t := 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	var col := CollisionShape2D.new()
	col.shape = RectangleShape2D.new()
	col.shape.size = SIZE
	col.position.y = -SIZE.y / 2
	add_child(col)
	sprite.texture = BEAR
	sprite.centered = false
	sprite.offset = Vector2(-16.5, -32)
	sprite.scale = Vector2(4, 4)
	sprite.modulate = Color(0.72, 0.5, 0.62)
	add_child(rig)
	rig.add_child(sprite)
	var crown := Polygon2D.new()
	crown.polygon = PackedVector2Array([Vector2(-24, -79), Vector2(24, -79), Vector2(24, -100), Vector2(12, -87), Vector2(0, -104), Vector2(-12, -87), Vector2(-24, -100)])
	crown.color = Color(1, 0.8, 0.2)
	rig.add_child(crown)
	Game.sfx("roar")


func _physics_process(delta: float) -> void:
	if hp <= 0:
		return
	hurt -= delta
	sprite.visible = hurt <= 0.0 or fmod(hurt, 0.2) < 0.1
	var target: Node2D = level.players[0]
	var dir := signf(target.position.x - position.x)
	velocity.x = dir * (70.0 + (MAX_HP - hp) * 100.0 / MAX_HP)  # angrier (faster) as he gets hurt
	sprite.flip_h = dir < 0
	jump_timer -= delta
	if jump_timer <= 0.0 and is_on_floor():
		velocity.y = -700.0
		jump_timer = randf_range(2.0, 3.5)
		squash = Vector2(0.75, 1.3)
	velocity.y += 1400.0 * delta
	var fall := velocity.y
	move_and_slide()
	if is_on_floor() and not was_on_floor and fall > 300.0:
		squash = Vector2(1.35, 0.7)
		level.shake(9.0)
		Game.sfx("slam")
		for side in [-1, 1]:
			Game.burst(level, position, 12, Color(0.75, 0.7, 0.65), 220.0, Vector2(side, -0.4), 25.0, 300.0, 6.0, 0.5)
	was_on_floor = is_on_floor()

	# heavy waddle while walking, springy squash
	walk_t += delta
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-8.0 * delta))
	var step := sin(walk_t * 9.0)
	rig.rotation = step * 0.07 if is_on_floor() else 0.0
	rig.scale = squash * Vector2(1.0, 1.0 + absf(step) * 0.04)

	for p in level.players:
		if p.dead or abs(p.position.x - position.x) > 34 or p.position.y < position.y - 84 or p.position.y - 36 > position.y:
			continue
		if p.velocity.y > 0 and p.position.y < position.y - 54:
			p.bounce(-700.0, "stomp")
			if hurt <= 0.0:
				hp -= 1
				hurt = 1.0
				squash = Vector2(1.4, 0.6)
				level.shake(6.0)
				Game.burst(level, position + Vector2(0, -SIZE.y), 16, Color(1, 0.9, 0.4), 220.0, Vector2.UP, 160.0, 400.0, 5.0, 0.5)
				Game.sfx("boss_hit")
				level.show_message("KING BEAR HP %d / %d" % [hp, MAX_HP], 1.5)
				if hp <= 0:
					sprite.visible = true
					var tw := create_tween()
					tw.tween_property(rig, "rotation", -1.4 if sprite.flip_h else 1.4, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
					level.shake(12.0)
					level.finish("KING BEAR IS BEATEN!")
		elif hurt <= 0.0:
			p.die()

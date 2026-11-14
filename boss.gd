extends CharacterBody2D

const BEAR := preload("res://little-bear-idle.png")

## King Bear's hitbox has to fit under the arena's floating platforms (3 tiles = 108 px
## above the ground), or he spawns wedged into them and can't move.
const SIZE := Vector2(54, 74)

var level: Node
var hp := 5
var hurt := 0.0
var jump_timer := 2.0
var sprite := Sprite2D.new()


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
	add_child(sprite)
	var crown := Polygon2D.new()
	crown.polygon = PackedVector2Array([Vector2(-24, -79), Vector2(24, -79), Vector2(24, -100), Vector2(12, -87), Vector2(0, -104), Vector2(-12, -87), Vector2(-24, -100)])
	crown.color = Color(1, 0.8, 0.2)
	add_child(crown)
	Game.sfx("roar")


func _physics_process(delta: float) -> void:
	if hp <= 0:
		return
	hurt -= delta
	sprite.visible = hurt <= 0.0 or fmod(hurt, 0.2) < 0.1
	var target: Node2D = level.players[0]
	var dir := signf(target.position.x - position.x)
	velocity.x = dir * (70.0 + (5 - hp) * 25.0)
	sprite.flip_h = dir < 0
	jump_timer -= delta
	if jump_timer <= 0.0 and is_on_floor():
		velocity.y = -700.0
		jump_timer = randf_range(2.0, 3.5)
	velocity.y += 1400.0 * delta
	move_and_slide()

	for p in level.players:
		if p.dead or abs(p.position.x - position.x) > 34 or p.position.y < position.y - 84 or p.position.y - 36 > position.y:
			continue
		if p.velocity.y > 0 and p.position.y < position.y - 54:
			p.bounce(-700.0, "stomp")
			if hurt <= 0.0:
				hp -= 1
				hurt = 1.0
				Game.sfx("boss_hit")
				level.show_message("KING BEAR HP %d / 5" % hp, 1.5)
				if hp <= 0:
					sprite.rotation = -1.2
					level.finish("KING BEAR IS BEATEN!")
		elif hurt <= 0.0:
			p.die()

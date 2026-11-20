extends Sprite2D
## One playing pixelfx effect: a sprite sheet stepped by time. One-shots free themselves.

signal finished

var fps := 15.0
var loop := false
var count := 1
var t := 0.0
var speed := 1.0
var fade_tail := false     # the sheet was cut short, so fade its last frames out
var alpha := 1.0
var follow: Node2D = null  # stick to a moving thing
var follow_offset := Vector2.ZERO
var real_time := false     # keep animating during hit-stop / pause (UI effects)
var hold_last := false     # stay on the last frame instead of freeing
var _last_us := 0


func _ready() -> void:
	_last_us = Time.get_ticks_usec()
	if real_time:
		process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if real_time:
		var now := Time.get_ticks_usec()
		delta = minf((now - _last_us) / 1000000.0, 0.1)
		_last_us = now
	t += delta * speed
	var f := int(t * fps)
	if f >= count:
		if loop:
			t = fmod(t, count / fps)
			f = int(t * fps) % count
		elif hold_last:
			f = count - 1
			set_process(false)
			finished.emit()
		else:
			finished.emit()
			queue_free()
			return
	frame = f
	if fade_tail and not loop:
		modulate.a = alpha * clampf((count - t * fps) / 5.0, 0.0, 1.0)
	if follow != null:
		if is_instance_valid(follow):
			global_position = follow.global_position + follow_offset
		else:
			follow = null


## Fade a looping effect out and free it.
func stop(time: float = 0.25) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, time)
	tw.tween_callback(queue_free)

extends Node2D

const SPEED = 60

var direction = 1

@onready var ray_cast_left = $RayCastLeft
@onready var ray_cast_right = $RayCastRight
@onready var animated_sprite = $AnimatedSprite2D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 벽 감지 및 방향 전환
	if direction > 0 and ray_cast_right.is_colliding():
		direction = -1
		animated_sprite.flip_h = true
	elif direction < 0 and ray_cast_left.is_colliding():
		direction = 1
		animated_sprite.flip_h = false
			
	position.x += direction * SPEED * delta

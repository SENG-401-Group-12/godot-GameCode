extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const SPEED = Globals.player_speed
var previous_direction := Vector2.DOWN

func get_input():
	var input_direction := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	velocity = input_direction * SPEED

func play_animations():
	if velocity.length() > 0:
		if velocity.x < 0:
			animated_sprite.play("walk_left")
			previous_direction = Vector2.LEFT
		elif velocity.x > 0:
			animated_sprite.play("walk_right")
			previous_direction = Vector2.RIGHT
		elif velocity.y < 0:
			animated_sprite.play("walk_up")
			previous_direction = Vector2.UP
		else:
			animated_sprite.play("walk_down")
			previous_direction = Vector2.DOWN

	else:
		if previous_direction == Vector2.LEFT:
			animated_sprite.play("idle_left")
		elif previous_direction == Vector2.RIGHT:
			animated_sprite.play("idle_right")
		elif previous_direction == Vector2.UP:
			animated_sprite.play("idle_up")
		else:
			animated_sprite.play("idle_down")

func _physics_process(_delta: float) -> void:
	get_input()
	play_animations()
	
	move_and_slide()

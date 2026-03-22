extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var speed := Globals.player_speed


func _ready() -> void:
	animated_sprite.modulate = PlayerData.get_character_modulate()
var previous_direction := Vector2.DOWN

func play_animation(animation_name: StringName, flipped := false) -> void:
	animated_sprite.flip_h = flipped
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)

func get_input():
	var input_direction := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	velocity = input_direction * speed

func play_animations():
	if velocity.length() > 0:
		if velocity.x < 0:
			play_animation("walk_left", true)
			previous_direction = Vector2.LEFT
		elif velocity.x > 0:
			play_animation("walk_right")
			previous_direction = Vector2.RIGHT
		elif velocity.y < 0:
			play_animation("walk_up")
			previous_direction = Vector2.UP
		else:
			play_animation("walk_down")
			previous_direction = Vector2.DOWN

	else:
		if previous_direction == Vector2.LEFT:
			play_animation("idle_left", true)
		elif previous_direction == Vector2.RIGHT:
			play_animation("idle_right")
		elif previous_direction == Vector2.UP:
			play_animation("idle_up")
		else:
			play_animation("idle_down")

func _physics_process(_delta: float) -> void:
	get_input()
	play_animations()
	
	move_and_slide()

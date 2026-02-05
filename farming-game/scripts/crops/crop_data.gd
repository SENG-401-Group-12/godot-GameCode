class_name CropData
extends Resource

# Crop Properties
@export var crop_name: String
@export var growth_stages: int = 5
@export var growth_time_per_stage: float = 5.0

# Sprite Properties
@export var spritesheet: Texture2D = preload("res://assets/game/objects/crop_spritesheet.png")
@export var row_on_spritesheet: int = 0
@export var sprite_size: Vector2i = Vector2i(16, 16)

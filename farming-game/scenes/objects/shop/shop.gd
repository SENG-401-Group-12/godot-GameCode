extends Node2D

@onready var interaction_area: InteractionArea = $InteractionArea
@onready var sprite: Sprite2D = $Sprite2D

signal shop_opened

const CLOSED_REGION := Rect2(0, 0, 48, 48)
const OPEN_REGION := Rect2(192, 0, 48, 48)

var is_open := false

func _ready() -> void:
	interaction_area.interact = Callable(self, "_on_interact") # link the "_on_interact" function
	set_opened(false)

func _on_interact() -> void:
	if is_open:
		set_opened(false)
		return

	set_opened(true)
	shop_opened.emit()

func set_opened(opened: bool) -> void:
	is_open = opened
	sprite.region_rect = OPEN_REGION if opened else CLOSED_REGION
	interaction_area.action_name = "CLOSE SHOP" if opened else "OPEN SHOP"

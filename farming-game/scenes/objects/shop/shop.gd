extends Node2D

@onready var interaction_area: InteractionArea = $InteractionArea
@onready var sprite: Sprite2D = $Sprite2D
@onready var timer_label: Label = $TimerLabel

signal shop_opened

const CLOSED_REGION := Rect2(0, 0, 48, 48)
const OPEN_REGION := Rect2(192, 0, 48, 48)

var is_open := false
@export var shop_timer := 22.0
@onready var timer_count := shop_timer

func _ready() -> void:
	interaction_area.interact = Callable(self, "_on_interact") # link the "_on_interact" function
	set_opened(false)
	timer_label.show()
	$NotAvailableLabel.hide()

func _process(delta: float) -> void:
	if timer_count > 0:
		timer_label.show()
		timer_count -= delta
	else:
		timer_count = 0
		timer_label.hide()
	timer_label.text = str(int(max(0.0, timer_count)))

func _on_interact() -> void:
	if is_open:
		set_opened(false)
		return

	if timer_count > 0:
		flash_sprite(Color.RED)
		show_not_available_label()
		return 
		
	set_opened(true)
	timer_count = shop_timer
	shop_opened.emit()

func set_opened(opened: bool) -> void:
	is_open = opened
	#sprite.region_rect = OPEN_REGION if opened else CLOSED_REGION
	interaction_area.action_name = "CLOSE SHOP" if opened else "OPEN SHOP"
	
func flash_sprite(color: Color) -> Tween:
	var tween = create_tween()
	for _i in range(3):
		tween.tween_property(sprite, "modulate", color, 0.08)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)
	return tween
	
func show_not_available_label() -> void:
	var label = $NotAvailableLabel
	label.show()
	label.modulate = Color(1, 1, 1, 1)

	var tween = create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.hide)

extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_button_pressed() -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	Input.parse_input_event(event)

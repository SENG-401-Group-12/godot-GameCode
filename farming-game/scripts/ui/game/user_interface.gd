extends Control

const MAIN_MENU := "res://scenes/ui/main_menu/main_menu.tscn"

@onready var _shop_ui: Control = $ShopUI


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if _shop_ui.visible:
		_shop_ui.close_shop()
		get_viewport().set_input_as_handled()
		return

	get_viewport().set_input_as_handled()
	get_tree().paused = true
	get_tree().change_scene_to_file(MAIN_MENU)

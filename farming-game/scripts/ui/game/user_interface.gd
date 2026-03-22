extends Control

@onready var _in_game_ui: Control = $InGameUI
@onready var _shop_ui: Control = $ShopUI
@onready var _pause: GamePauseLayer = $PauseOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return

	if _shop_ui.visible:
		_shop_ui.close_shop()
		get_viewport().set_input_as_handled()
		return

	if _in_game_ui.game_over_layer.visible:
		get_viewport().set_input_as_handled()
		return

	if _pause.is_open():
		_pause.close_pause()
		get_viewport().set_input_as_handled()
		return

	get_viewport().set_input_as_handled()
	_pause.open_pause()

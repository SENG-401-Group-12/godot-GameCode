extends Node

## F11 toggles exclusive fullscreen. Uses InputMap + _process (PROCESS_MODE_ALWAYS) so it works on the main menu,
## during pause, and even when keys would otherwise be treated as unhandled GUI noise.

const player_speed := 140 # movement speed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_toggle_fullscreen_action()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_fullscreen"):
		_toggle_exclusive_fullscreen()


func _ensure_toggle_fullscreen_action() -> void:
	if InputMap.has_action("toggle_fullscreen"):
		return
	InputMap.add_action(&"toggle_fullscreen", 0.0)
	var ev := InputEventKey.new()
	ev.keycode = KEY_F11
	ev.physical_keycode = KEY_F11
	InputMap.action_add_event("toggle_fullscreen", ev)


func _toggle_exclusive_fullscreen() -> void:
	var w := get_window()
	if w == null:
		return
	if w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		w.mode = Window.MODE_WINDOWED
		w.size = Vector2i(1280, 720)
	else:
		w.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	GameSettings.fullscreen = w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	GameSettings.save_to_disk()

const game_crops := [ # crops used in the game
	preload("res://scripts/crops/turnip.tres"),
	preload("res://scripts/crops/tomato.tres"), 
	preload("res://scripts/crops/strawberry.tres"),
	preload("res://scripts/crops/eggplant.tres"),
	preload("res://scripts/crops/potato.tres")
	] 
const default_farm_size := Vector2i(3, 5)

# Crop upgrade base values
const base_yield_upgrade := 0.1
## Per tier: fraction of that crop's growth_time_per_stage shaved (fast crops get smaller flat cuts).
const base_growth_stage_fraction := 0.125
const base_farm_size_upgrade := Vector2i(1, 1)

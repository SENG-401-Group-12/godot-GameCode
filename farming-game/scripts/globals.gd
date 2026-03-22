extends Node

## F11 toggles exclusive fullscreen so the game can use the full 2560×1440 panel.
## Maximized/windowed mode often leaves ~72px for the taskbar, which caps scale at 3.8 (2432×1368) instead of 4× (2560×1440).

const player_speed := 100 # movement speed


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode != KEY_F11:
		return
	var w := get_window()
	if w == null:
		return
	if w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		w.mode = Window.MODE_WINDOWED
		w.size = Vector2i(1280, 720)
	else:
		w.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	get_viewport().set_input_as_handled()

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
const base_growth_upgrade := 0.25
const base_farm_size_upgrade := Vector2i(1, 1)

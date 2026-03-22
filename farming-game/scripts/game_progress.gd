extends Node

## Persists one-time tutorial completion under user:// (separate from audio/settings).

const _CFG_PATH := "user://game_progress.cfg"
const _SEC := "progress"

var tutorial_completed: bool = false
## When true, next RunSetup scene only shows tutorial and returns to the main menu.
var open_tutorial_replay_from_menu: bool = false


func _ready() -> void:
	_load()


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(_CFG_PATH) != OK:
		return
	tutorial_completed = bool(cf.get_value(_SEC, "tutorial_completed", false))


func save_progress() -> void:
	var cf := ConfigFile.new()
	cf.load(_CFG_PATH)
	cf.set_value(_SEC, "tutorial_completed", tutorial_completed)
	cf.save(_CFG_PATH)


func mark_tutorial_completed() -> void:
	tutorial_completed = true
	save_progress()

extends Node

## Persisted user preferences (user://settings.cfg). Loaded on startup; changing values calls save() and emits settings_changed.

signal settings_changed

const _CFG_PATH := "user://settings.cfg"
const _SEC := "settings"

var master_linear: float = 1.0
var music_linear: float = 0.75
var sfx_linear: float = 0.75
var fullscreen: bool = false
var vsync_enabled: bool = true


func _ready() -> void:
	load_from_disk()
	apply_display_settings()


func load_from_disk() -> void:
	var cf := ConfigFile.new()
	if cf.load(_CFG_PATH) != OK:
		_reset_defaults()
		return
	master_linear = clampf(float(cf.get_value(_SEC, "master_linear", 1.0)), 0.0, 1.0)
	music_linear = clampf(float(cf.get_value(_SEC, "music_linear", 0.75)), 0.0, 1.0)
	sfx_linear = clampf(float(cf.get_value(_SEC, "sfx_linear", 0.75)), 0.0, 1.0)
	fullscreen = bool(cf.get_value(_SEC, "fullscreen", false))
	vsync_enabled = bool(cf.get_value(_SEC, "vsync", true))


func save_to_disk() -> void:
	var cf := ConfigFile.new()
	cf.load(_CFG_PATH)
	cf.set_value(_SEC, "master_linear", master_linear)
	cf.set_value(_SEC, "music_linear", music_linear)
	cf.set_value(_SEC, "sfx_linear", sfx_linear)
	cf.set_value(_SEC, "fullscreen", fullscreen)
	cf.set_value(_SEC, "vsync", vsync_enabled)
	cf.save(_CFG_PATH)
	settings_changed.emit()


func _reset_defaults() -> void:
	master_linear = 1.0
	music_linear = 0.75
	sfx_linear = 0.75
	fullscreen = false
	vsync_enabled = true


func reset_to_defaults() -> void:
	_reset_defaults()
	save_to_disk()
	apply_display_settings()


## Combined linear gain for music BGM + stingers (master × music).
func get_music_linear() -> float:
	return clampf(master_linear * music_linear, 0.0001, 1.0)


func get_music_volume_db() -> float:
	return linear_to_db(get_music_linear())


func get_sfx_linear() -> float:
	return clampf(master_linear * sfx_linear, 0.0001, 1.0)


func apply_display_settings() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	var w := get_window()
	if w == null:
		return
	if fullscreen:
		w.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		w.mode = Window.MODE_WINDOWED
		w.size = Vector2i(1280, 720)

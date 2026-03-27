extends Window

const UI_FONT = preload("res://assets/game/ui/fonts/PixelOperator8.ttf")

@onready var _master_slider: HSlider = $Margin/RootVBox/Scroll/ScrollVBox/MasterRow/MasterSlider
@onready var _music_slider: HSlider = $Margin/RootVBox/Scroll/ScrollVBox/MusicRow/MusicSlider
@onready var _gameplay_music_slider: HSlider = $Margin/RootVBox/Scroll/ScrollVBox/GameplayMusicRow/GameplayMusicSlider
@onready var _sfx_slider: HSlider = $Margin/RootVBox/Scroll/ScrollVBox/SfxRow/SfxSlider
@onready var _master_value: Label = $Margin/RootVBox/Scroll/ScrollVBox/MasterRow/MasterValue
@onready var _music_value: Label = $Margin/RootVBox/Scroll/ScrollVBox/MusicRow/MusicValue
@onready var _gameplay_music_value: Label = $Margin/RootVBox/Scroll/ScrollVBox/GameplayMusicRow/GameplayMusicValue
@onready var _sfx_value: Label = $Margin/RootVBox/Scroll/ScrollVBox/SfxRow/SfxValue
@onready var _fullscreen: CheckButton = $Margin/RootVBox/Scroll/ScrollVBox/FullscreenCheck
@onready var _vsync: CheckButton = $Margin/RootVBox/Scroll/ScrollVBox/VsyncCheck


func _ready() -> void:
	# Was process_mode DISABLED in .tscn — that blocks all input on sliders/buttons.
	# ALWAYS keeps this window usable when the game tree is paused (pause menu).
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_requested.connect(hide)
	_apply_fonts(self)
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_gameplay_music_slider.value_changed.connect(_on_gameplay_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_vsync.toggled.connect(_on_vsync_toggled)
	GameSettings.settings_changed.connect(_sync_from_settings)
	_sync_from_settings()


func open_settings() -> void:
	_sync_from_settings()
	var vp := get_tree().root.get_viewport().get_visible_rect().size
	var max_w := maxi(300, int(vp.x) - 72)
	var max_h := maxi(260, int(vp.y) - 72)
	var win_w := clampi(380, 300, max_w)
	var win_h := clampi(300, 220, max_h)
	size = Vector2i(win_w, win_h)
	popup_centered()


func _sync_from_settings() -> void:
	_master_slider.set_block_signals(true)
	_music_slider.set_block_signals(true)
	_gameplay_music_slider.set_block_signals(true)
	_sfx_slider.set_block_signals(true)
	_fullscreen.set_block_signals(true)
	_vsync.set_block_signals(true)
	_master_slider.value = int(round(GameSettings.master_linear * 100.0))
	_music_slider.value = int(round(GameSettings.music_linear * 100.0))
	_gameplay_music_slider.value = int(round(GameSettings.gameplay_music_linear * 100.0))
	_sfx_slider.value = int(round(GameSettings.sfx_linear * 100.0))
	_fullscreen.button_pressed = GameSettings.fullscreen
	_vsync.button_pressed = GameSettings.vsync_enabled
	_master_slider.set_block_signals(false)
	_music_slider.set_block_signals(false)
	_gameplay_music_slider.set_block_signals(false)
	_sfx_slider.set_block_signals(false)
	_fullscreen.set_block_signals(false)
	_vsync.set_block_signals(false)
	_refresh_labels()


func _refresh_labels() -> void:
	_master_value.text = "%d%%" % int(_master_slider.value)
	_music_value.text = "%d%%" % int(_music_slider.value)
	_gameplay_music_value.text = "%d%%" % int(_gameplay_music_slider.value)
	_sfx_value.text = "%d%%" % int(_sfx_slider.value)


func _on_master_changed(v: float) -> void:
	GameSettings.master_linear = clampf(v / 100.0, 0.0, 1.0)
	GameSettings.save_to_disk()
	_refresh_labels()


func _on_music_changed(v: float) -> void:
	GameSettings.music_linear = clampf(v / 100.0, 0.0, 1.0)
	GameSettings.save_to_disk()
	_refresh_labels()


func _on_gameplay_music_changed(v: float) -> void:
	GameSettings.gameplay_music_linear = clampf(v / 100.0, 0.0, 1.0)
	GameSettings.save_to_disk()
	_refresh_labels()


func _on_sfx_changed(v: float) -> void:
	GameSettings.sfx_linear = clampf(v / 100.0, 0.0, 1.0)
	GameSettings.save_to_disk()
	_refresh_labels()


func _on_fullscreen_toggled(pressed: bool) -> void:
	GameSettings.fullscreen = pressed
	GameSettings.save_to_disk()
	GameSettings.apply_display_settings()


func _on_vsync_toggled(pressed: bool) -> void:
	GameSettings.vsync_enabled = pressed
	GameSettings.save_to_disk()
	GameSettings.apply_display_settings()


func _on_reset_pressed() -> void:
	GameSettings.reset_to_defaults()
	_sync_from_settings()


func _on_close_pressed() -> void:
	hide()


func _apply_fonts(node: Node) -> void:
	if node is Control:
		var c := node as Control
		if c is Button or c is Label:
			c.add_theme_font_override("font", UI_FONT)
			if c.name == "Title":
				c.add_theme_font_size_override("font_size", 14)
			else:
				c.add_theme_font_size_override("font_size", 9)
		elif c is LineEdit:
			c.add_theme_font_override("font", UI_FONT)
			c.add_theme_font_size_override("font_size", 12)
	for ch in node.get_children():
		_apply_fonts(ch)

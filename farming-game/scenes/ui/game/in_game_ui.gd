extends Control
signal tutorial_box_hidden

const UI_FONT = preload("res://assets/game/ui/fonts/PixelOperator8.ttf")
const TYPE_BLIP_PATH := "res://assets/audio/sfx/ui_type_blip.wav"

const TUTORIAL_CHARS_PER_SECOND := 38.0
const TUTORIAL_PROMPT_TYPING := "Click here or press Space to show the full message."
const TUTORIAL_PROMPT_WAIT := "Click this box to hide. Use the Tutorial button to bring it back."
const ENDLESS_MAX_MISSES := 10

@onready var wave_label: Label = $MarginContainer/HBoxContainer/StatusPanel/MarginContainer/VBoxContainer/WaveLabel
@onready var progress_label: Label = $MarginContainer/HBoxContainer/StatusPanel/MarginContainer/VBoxContainer/ProgressLabel
@onready var missed_label: Label = $MarginContainer/HBoxContainer/StatusPanel/MarginContainer/VBoxContainer/MissedLabel
@onready var active_label: Label = $MarginContainer/HBoxContainer/StatusPanel/MarginContainer/VBoxContainer/ActiveLabel
@onready var status_panel: Control = $MarginContainer/HBoxContainer/StatusPanel
@onready var upgrade_dock: Control = $UpgradeDock
@onready var upgrade_circles_host: HBoxContainer = $UpgradeDock/UpgradeCircles
@onready var selected_crop_icon: TextureRect = $MarginContainer/HBoxContainer/CropPanelFrame/MarginContainer/CropPanelInner/InnerMargin/VBoxContainer/SelectedCropIconWrap/SelectedCropIcon
@onready var selected_crop_label: Label = $MarginContainer/HBoxContainer/CropPanelFrame/MarginContainer/CropPanelInner/InnerMargin/VBoxContainer/SelectedCropLabel
@onready var summary_label: Label = $MarginContainer/HBoxContainer/CropPanelFrame/MarginContainer/CropPanelInner/InnerMargin/VBoxContainer/SummaryLabel
@onready var seeds_label: Label = $MarginContainer/HBoxContainer/CropPanelFrame/MarginContainer/CropPanelInner/InnerMargin/VBoxContainer/SeedsRow/SeedsLabel
@onready var crop_buttons: VBoxContainer = $MarginContainer/HBoxContainer/CropPanelFrame/MarginContainer/CropPanelInner/InnerMargin/VBoxContainer/ScrollContainer/CropButtonsMargin/CropButtons
@onready var message_label: Label = $MarginContainer/HBoxContainer/CenterMessage
@onready var game_over_layer: ColorRect = $GameOverLayer
@onready var game_over_body: Label = $GameOverLayer/CenterContainer/Panel/Margin/VBox/BodyLabel
@onready var game_over_personal_best: Label = $GameOverLayer/CenterContainer/Panel/Margin/VBox/PersonalBestLabel
@onready var game_over_submit: Label = $GameOverLayer/CenterContainer/Panel/Margin/VBox/SubmitStatusLabel
@onready var game_over_menu_button: Button = $GameOverLayer/CenterContainer/Panel/Margin/VBox/MenuButton

var _message_tween: Tween = null
var _tutorial_layer: CanvasLayer
var _tutorial_root: Control
var _tutorial_panel: PanelContainer
var _tutorial_main: Label
var _tutorial_prompt: Label
var _tutorial_toggle_button: Button
var _tutorial_type_timer: Timer
var _type_player: AudioStreamPlayer
var _type_blip_stream: AudioStream

var _tutorial_target_text: String = ""
var _tutorial_title_text: String = ""
var _tutorial_body_text: String = ""
var _tutorial_visible_chars: int = 0
var _tutorial_is_typing: bool = false

var crop_button_nodes: Array[Button] = []
var _upgrade_tooltip_panel: PanelContainer = null
var _upgrade_tooltip_label: Label = null

func _is_touch_device() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("('ontouchstart' in window) || (navigator.maxTouchPoints > 0)", true)
	return false

func _ready() -> void:
	if _is_touch_device():
		pass
	else:
		$Joystick.queue_free()
		$InteractButton.queue_free()
		$MobilePauseButton.queue_free()
	game_over_layer.visible = false
	upgrade_dock.process_mode = Node.PROCESS_MODE_ALWAYS
	upgrade_dock.mouse_filter = Control.MOUSE_FILTER_PASS
	upgrade_dock.top_level = true
	upgrade_dock.z_index = 350
	_ensure_upgrade_tooltip_ui()
	game_over_menu_button.pressed.connect(_on_game_over_menu_pressed)
	get_parent().show()
	_build_crop_buttons()
	PlayerData.inventory_changed.connect(_refresh_crop_ui)
	PlayerData.currency_changed.connect(func(_amt): _refresh_crop_ui())
	PlayerData.farm_size_changed.connect(func(_crop: String): _refresh_upgrade_hud())
	PlayerData.selected_crop_changed.connect(_on_selected_crop_changed)
	_refresh_crop_ui()
	_on_selected_crop_changed(PlayerData.get_selected_crop_name())
	_update_status(0, 0, 0, 0, 0, 0, 0)
	if ResourceLoader.exists(TYPE_BLIP_PATH):
		_type_blip_stream = load(TYPE_BLIP_PATH) as AudioStream
	if GameProgress.tutorial_mode:
		begin_tutorial_hud()
	else:
		_show_message("Tip: pick a crop → plant → harvest → feed customers with E. Feed quickly (more time left on their timer) to earn more seeds.")
	set_process(false)


func _stop_tutorial_typing_timer() -> void:
	if is_instance_valid(_tutorial_type_timer):
		_tutorial_type_timer.stop()


func _on_tutorial_type_timer_timeout() -> void:
	if not _tutorial_is_typing or not is_instance_valid(_tutorial_main):
		return
	if _tutorial_visible_chars >= _tutorial_target_text.length():
		_stop_tutorial_typing_timer()
		_finish_tutorial_typing()
		return
	var ch: String = _tutorial_target_text[_tutorial_visible_chars]
	_tutorial_visible_chars += 1
	_tutorial_main.text = _tutorial_target_text.substr(0, _tutorial_visible_chars)
	if _should_play_blip_for_char(ch) and (_tutorial_visible_chars % 2 == 0):
		_play_type_blip()
	if _tutorial_visible_chars >= _tutorial_target_text.length():
		_stop_tutorial_typing_timer()
		_finish_tutorial_typing()


func _should_play_blip_for_char(ch: String) -> bool:
	if ch == " " or ch == "\n" or ch == "\t":
		return false
	return true


func _play_type_blip() -> void:
	if _type_player == null or _type_blip_stream == null:
		return
	_type_player.stream = _type_blip_stream
	_type_player.volume_db = linear_to_db(GameSettings.get_sfx_linear())
	_type_player.pitch_scale = randf_range(0.94, 1.06)
	_type_player.play()


func _finish_tutorial_typing() -> void:
	_tutorial_is_typing = false
	_stop_tutorial_typing_timer()
	if is_instance_valid(_tutorial_main):
		_tutorial_main.text = _tutorial_target_text
	if is_instance_valid(_tutorial_prompt):
		_tutorial_prompt.text = TUTORIAL_PROMPT_WAIT
		_tutorial_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not GameProgress.tutorial_mode or not is_instance_valid(_tutorial_layer) or not _tutorial_layer.visible:
		return
	if not _tutorial_is_typing:
		return
	if event.is_echo():
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		_tutorial_advance()
		get_viewport().set_input_as_handled()


func _build_crop_buttons() -> void:
	for child in crop_buttons.get_children():
		child.queue_free()

	crop_button_nodes.clear()
	for index in range(Globals.game_crops.size()):
		var crop: CropData = Globals.game_crops[index]
		var button := Button.new()
		button.icon = crop.get_item_icon()
		button.custom_minimum_size = Vector2(126, 32)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_override("font", UI_FONT)
		button.add_theme_font_size_override("font_size", 8)
		button.add_theme_constant_override("h_separation", 6)
		var new_stylebox_normal = button.get_theme_stylebox("normal").duplicate()
		new_stylebox_normal.bg_color = Color(0.0, 0.0, 0.0, 0.157)
		button.add_theme_stylebox_override("normal", new_stylebox_normal)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_crop_button_pressed.bind(index))
		crop_buttons.add_child(button)
		crop_button_nodes.append(button)


func _on_crop_button_pressed(index: int) -> void:
	PlayerData.set_selected_crop_index(index)
	_on_selected_crop_changed(Globals.game_crops[index].crop_name)


func _refresh_crop_ui() -> void:
	var total_inventory := 0
	for index in range(Globals.game_crops.size()):
		var crop: CropData = Globals.game_crops[index]
		var amount = PlayerData.get_crop_amount(crop.crop_name)
		total_inventory += amount
		var button = crop_button_nodes[index]
		var is_selected = index == PlayerData.selected_crop_index
		button.text = "%s\n%d" % [crop.crop_name, amount]
		button.modulate = Color(1.0, 0.95, 0.75) if is_selected else Color(0.85, 0.85, 0.85)

	summary_label.text = "Stored crops: %d" % total_inventory
	seeds_label.text = "Seeds: %d" % PlayerData.run_currency
	_refresh_upgrade_hud()


func _has_nondefault_crop_upgrades(st: Dictionary) -> bool:
	if st.get("yield_multiplier", 1.0) > 1.001:
		return true
	if st.get("growth_speed_bonus", 0.0) > 0.001:
		return true
	if st.get("size_bonus", Vector2i.ZERO) != Vector2i.ZERO:
		return true
	return false


func _crop_upgrade_tooltip(crop_name: String) -> String:
	var st: Dictionary = PlayerData.crop_upgrades.get(crop_name)
	if st == null:
		return crop_name
	var lines: PackedStringArray = []
	lines.append(crop_name)
	if st.get("yield_multiplier", 1.0) > 1.001:
		lines.append("Yield: ×%.2f" % float(st.yield_multiplier))
	if st.get("growth_speed_bonus", 0.0) > 0.001:
		lines.append("Growth: −%.2fs" % float(st.growth_speed_bonus))
	var sb: Vector2i = st.get("size_bonus", Vector2i.ZERO)
	if sb != Vector2i.ZERO:
		lines.append("Farm size: +%d × %d" % [sb.x, sb.y])
	return "\n".join(lines)


func _refresh_upgrade_hud() -> void:
	if not is_instance_valid(upgrade_circles_host):
		return
	_hide_upgrade_tooltip()
	for child in upgrade_circles_host.get_children():
		child.queue_free()
	if GameProgress.tutorial_mode:
		upgrade_dock.visible = false
		return
	var placed := false
	for crop in Globals.game_crops:
		if crop == null:
			continue
		var st: Dictionary = PlayerData.crop_upgrades.get(crop.crop_name)
		if st == null or not _has_nondefault_crop_upgrades(st):
			continue
		placed = true
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(18, 18)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var tooltip_text := _crop_upgrade_tooltip(crop.crop_name)
		slot.mouse_entered.connect(func():
			_show_upgrade_tooltip(tooltip_text)
		)
		slot.mouse_exited.connect(_hide_upgrade_tooltip)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.08, 0.08, 0.1, 0.62)
		bg.border_width_left = 1
		bg.border_width_top = 1
		bg.border_width_right = 1
		bg.border_width_bottom = 1
		bg.border_color = Color(1, 1, 1, 0.24)
		bg.set_corner_radius_all(9)
		slot.add_theme_stylebox_override(&"panel", bg)
		var icon := TextureRect.new()
		icon.texture = crop.get_item_icon()
		icon.custom_minimum_size = Vector2(14, 14)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.position = Vector2(2, 2)
		slot.add_child(icon)
		upgrade_circles_host.add_child(slot)
	upgrade_dock.visible = placed


func _on_selected_crop_changed(crop_name: String) -> void:
	selected_crop_label.text = "Selected seed:\n%s" % crop_name
	if selected_crop_icon:
		var tex: Texture2D = null
		for c in Globals.game_crops:
			if c != null and c.crop_name == crop_name:
				tex = c.get_item_icon()
				break
		selected_crop_icon.texture = tex
	_refresh_crop_ui()


func _show_message(text: String, display_time: float = 2.2) -> void:
	if GameProgress.tutorial_mode:
		return
	if _message_tween:
		_message_tween.kill()
	message_label.text = text
	message_label.modulate = Color(1, 1, 1, 1)
	_message_tween = create_tween()
	_message_tween.tween_interval(display_time)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)


func begin_tutorial_hud() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	status_panel.visible = false
	wave_label.text = ""
	progress_label.text = ""
	missed_label.text = ""
	active_label.text = ""
	message_label.modulate = Color(1, 1, 1, 0)
	message_label.text = ""
	_ensure_tutorial_overlay()
	if _tutorial_layer:
		_tutorial_layer.visible = true
	_refresh_upgrade_hud()


func _ensure_tutorial_overlay() -> void:
	if is_instance_valid(_tutorial_layer):
		return
	_tutorial_layer = CanvasLayer.new()
	_tutorial_layer.layer = 200
	_tutorial_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tutorial_layer)

	_tutorial_root = Control.new()
	_tutorial_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_layer.add_child(_tutorial_root)

	_type_player = AudioStreamPlayer.new()
	_type_player.bus = "Master"
	_type_player.volume_db = -10.0
	_type_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_tutorial_layer.add_child(_type_player)

	_tutorial_type_timer = Timer.new()
	_tutorial_type_timer.wait_time = 1.0 / maxf(1.0, TUTORIAL_CHARS_PER_SECOND)
	_tutorial_type_timer.one_shot = false
	_tutorial_type_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_tutorial_type_timer.timeout.connect(_on_tutorial_type_timer_timeout)
	_tutorial_layer.add_child(_tutorial_type_timer)

	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.visible = true
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = Color(0.02, 0.02, 0.06, 0.92)
	panel_bg.set_corner_radius_all(6)
	panel_bg.content_margin_left = 4
	panel_bg.content_margin_top = 4
	panel_bg.content_margin_right = 4
	panel_bg.content_margin_bottom = 4
	_tutorial_panel.add_theme_stylebox_override("panel", panel_bg)
	_tutorial_root.add_child(_tutorial_panel)
	_tutorial_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tutorial_panel.offset_left = 6
	_tutorial_panel.offset_top = 6
	_tutorial_panel.offset_right = -6
	_tutorial_panel.offset_bottom = 140

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	_tutorial_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_tutorial_main = Label.new()
	_tutorial_main.add_theme_font_override("font", UI_FONT)
	_tutorial_main.add_theme_font_size_override("font_size", 8)
	_tutorial_main.add_theme_color_override("font_color", Color(0.96, 0.96, 0.99))
	_tutorial_main.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.08))
	_tutorial_main.add_theme_constant_override("outline_size", 3)
	_tutorial_main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tutorial_main.custom_minimum_size = Vector2(0, 70)
	_tutorial_main.text = ""
	vbox.add_child(_tutorial_main)

	_tutorial_prompt = Label.new()
	_tutorial_prompt.add_theme_font_override("font", UI_FONT)
	_tutorial_prompt.add_theme_font_size_override("font_size", 8)
	_tutorial_prompt.add_theme_color_override("font_color", Color(0.72, 0.82, 1.0))
	_tutorial_prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.12))
	_tutorial_prompt.add_theme_constant_override("outline_size", 2)
	_tutorial_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_prompt.text = TUTORIAL_PROMPT_TYPING
	_tutorial_prompt.visible = true
	vbox.add_child(_tutorial_prompt)

	_tutorial_panel.gui_input.connect(_on_tutorial_panel_gui_input)

	_tutorial_toggle_button = Button.new()
	_tutorial_toggle_button.text = "Tutorial"
	_tutorial_toggle_button.focus_mode = Control.FOCUS_NONE
	_tutorial_toggle_button.add_theme_font_override("font", UI_FONT)
	_tutorial_toggle_button.add_theme_font_size_override("font_size", 8)
	_tutorial_toggle_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_tutorial_toggle_button.offset_left = 8
	_tutorial_toggle_button.offset_top = -34
	_tutorial_toggle_button.offset_right = 92
	_tutorial_toggle_button.offset_bottom = -8
	_tutorial_toggle_button.pressed.connect(_on_tutorial_toggle_pressed)
	_tutorial_root.add_child(_tutorial_toggle_button)


func _on_tutorial_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _tutorial_is_typing:
			_tutorial_advance()
		elif _tutorial_panel:
			_tutorial_panel.visible = false
			tutorial_box_hidden.emit()


func _tutorial_advance() -> void:
	if not _tutorial_is_typing:
		return
	_stop_tutorial_typing_timer()
	_tutorial_visible_chars = _tutorial_target_text.length()
	if is_instance_valid(_tutorial_main):
		_tutorial_main.text = _tutorial_target_text
	_play_type_blip()
	_finish_tutorial_typing()


func _on_tutorial_toggle_pressed() -> void:
	if _tutorial_panel == null:
		return
	if _tutorial_panel.visible:
		_tutorial_panel.visible = false
		return
	_tutorial_panel.visible = true
	_tutorial_is_typing = false
	_stop_tutorial_typing_timer()
	if is_instance_valid(_tutorial_main):
		_tutorial_main.text = _tutorial_target_text
	if is_instance_valid(_tutorial_prompt):
		_tutorial_prompt.text = TUTORIAL_PROMPT_WAIT
		_tutorial_prompt.visible = true


func set_tutorial_objective(title: String, body: String) -> void:
	_ensure_tutorial_overlay()
	if not is_instance_valid(_tutorial_panel) or not is_instance_valid(_tutorial_main):
		return
	if _tutorial_layer:
		_tutorial_layer.visible = true
	_tutorial_title_text = title
	_tutorial_body_text = body
	_tutorial_target_text = "%s\n\n%s" % [title, body]
	_tutorial_visible_chars = 0
	_stop_tutorial_typing_timer()
	_tutorial_panel.visible = true
	_tutorial_main.text = ""
	if is_instance_valid(_tutorial_prompt):
		_tutorial_prompt.text = TUTORIAL_PROMPT_TYPING
		_tutorial_prompt.visible = true
	_tutorial_is_typing = true
	if is_instance_valid(_tutorial_type_timer):
		_tutorial_type_timer.start()
	else:
		_tutorial_main.text = _tutorial_target_text
		_finish_tutorial_typing()


func clear_tutorial_objective() -> void:
	_tutorial_is_typing = false
	_stop_tutorial_typing_timer()
	process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(_tutorial_layer):
		_tutorial_layer.queue_free()
		_tutorial_layer = null
	_type_player = null
	_tutorial_type_timer = null
	_tutorial_root = null
	_tutorial_panel = null
	_tutorial_main = null
	_tutorial_prompt = null
	_tutorial_toggle_button = null
	status_panel.visible = true
	_update_status(0, 0, 0, 0, 0, 0, 0)
	_refresh_upgrade_hud()
	message_label.modulate = Color(1, 1, 1, 1)


func _update_status(current_wave, fed_count, fed_target, missed_count, allowed_misses, active_customer_count, total_missed_run: int = 0) -> void:
	if GameProgress.tutorial_mode:
		wave_label.text = ""
		progress_label.text = ""
		missed_label.text = ""
		active_label.text = ""
		return
	wave_label.text = "Wave %d" % current_wave
	progress_label.text = "Fed: %d / %d" % [fed_count, fed_target]
	if GameProgress.endless_mode:
		missed_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		missed_label.text = "Total miss: %d/%d" % [total_missed_run, ENDLESS_MAX_MISSES]
	else:
		missed_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		missed_label.text = "Missed: %d / %d" % [missed_count, allowed_misses]
	active_label.text = "Waiting now: %d" % active_customer_count

func _ensure_upgrade_tooltip_ui() -> void:
	if is_instance_valid(_upgrade_tooltip_panel):
		return
	_upgrade_tooltip_panel = PanelContainer.new()
	_upgrade_tooltip_panel.visible = false
	_upgrade_tooltip_panel.top_level = true
	_upgrade_tooltip_panel.z_index = 500
	_upgrade_tooltip_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_upgrade_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	bg.set_corner_radius_all(6)
	bg.content_margin_left = 6
	bg.content_margin_top = 5
	bg.content_margin_right = 6
	bg.content_margin_bottom = 5
	_upgrade_tooltip_panel.add_theme_stylebox_override("panel", bg)
	add_child(_upgrade_tooltip_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 5)
	_upgrade_tooltip_panel.add_child(margin)

	_upgrade_tooltip_label = Label.new()
	_upgrade_tooltip_label.add_theme_font_override("font", UI_FONT)
	_upgrade_tooltip_label.add_theme_font_size_override("font_size", 7)
	_upgrade_tooltip_label.add_theme_constant_override("outline_size", 3)
	_upgrade_tooltip_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_upgrade_tooltip_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02))
	_upgrade_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	margin.add_child(_upgrade_tooltip_label)


func _show_upgrade_tooltip(text: String) -> void:
	if not is_instance_valid(_upgrade_tooltip_panel) or not is_instance_valid(_upgrade_tooltip_label):
		return
	_upgrade_tooltip_label.text = text
	_upgrade_tooltip_panel.reset_size()
	var min_size := _upgrade_tooltip_panel.get_combined_minimum_size()
	_upgrade_tooltip_panel.size = min_size
	var mouse := get_viewport().get_mouse_position()
	var pos := mouse + Vector2(8, -_upgrade_tooltip_panel.size.y - 6)
	var visible := get_viewport_rect().size
	pos.x = clampf(pos.x, 4.0, maxf(4.0, visible.x - _upgrade_tooltip_panel.size.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, visible.y - _upgrade_tooltip_panel.size.y - 4.0))
	_upgrade_tooltip_panel.position = pos
	_upgrade_tooltip_panel.visible = true


func _hide_upgrade_tooltip() -> void:
	if is_instance_valid(_upgrade_tooltip_panel):
		_upgrade_tooltip_panel.visible = false


func show_game_over(body_text: String, submit_status: String) -> void:
	game_over_body.text = body_text
	game_over_submit.text = submit_status
	if Backend.is_logged_in():
		game_over_personal_best.visible = true
		game_over_personal_best.text = "Account best: fetching…"
	else:
		game_over_personal_best.visible = false
		game_over_personal_best.text = ""
	game_over_layer.visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true


func set_run_submit_status(text: String) -> void:
	game_over_submit.text = text


func set_game_over_personal_best(line: String) -> void:
	if not game_over_layer.visible:
		return
	game_over_personal_best.text = line


func _on_game_over_menu_pressed() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_INHERIT
	game_over_layer.visible = false
	Music.play_menu()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")
